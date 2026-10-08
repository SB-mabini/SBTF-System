-- ===========================================================================
-- SBTF System — first administrator bootstrap
-- Municipality of Mabini, Batangas
--
-- Run this ONCE, by hand, in the Supabase SQL Editor, when a fresh project has
-- the schema applied but no account exists that can sign in to the console.
--
-- It is idempotent: running it again refreshes the password, re-confirms the
-- e-mail address and re-asserts the administrator role on the SAME account
-- (matched on lower(email)). It never creates a duplicate.
--
-- Why SQL and not the dashboard: the administrator role is stored in
-- raw_app_meta_data, which the Supabase Auth API only lets the service role
-- write. Creating the user in Dashboard → Authentication and then editing
-- public.profiles leaves app_metadata without a role, and the next sign-in
-- re-provisions the profile as a driver. This file writes both sides together.
--
-- BEFORE RUNNING: set the four values in the configuration block below.
-- AFTER RUNNING: sign in, then change the password on /admin/account and store
-- this file's password nowhere.
-- ===========================================================================

begin;

do $$
declare
  -- ---------------------------------------------------------------------
  -- CONFIGURATION — edit these four lines, nothing else.
  -- ---------------------------------------------------------------------
  c_email    text := 'administrator@mabini.gov.ph';
  c_password text := 'Change-Me-First-2026';
  c_first    text := 'Municipal';
  c_last     text := 'Administrator';
  -- ---------------------------------------------------------------------
  c_contact  text := null;          -- optional, e.g. '09170000000'
  c_barangay text := null;          -- optional PSA code, e.g. '041016017' (Poblacion)
  c_address  text := 'Municipal Hall, Poblacion, Mabini, Batangas';

  v_email    text := lower(btrim(c_email));
  v_user_id  uuid;
  v_profile  public.profiles;
  v_identity_sql text;
begin
  set local search_path = public, auth, extensions, pg_temp;

  if v_email !~ '^[^@\s]+@[^@\s.]+\.[^@\s]+$' then
    raise exception 'Set a valid e-mail address in the configuration block (c_email = "%").',
      coalesce(c_email, '')
      using hint = 'Edit the CONFIGURATION block at the top of supabase/first_admin.sql.';
  end if;

  if length(c_password) < 12 then
    raise exception 'The bootstrap password must be at least 12 characters.'
      using hint = 'Change c_password at the top of supabase/first_admin.sql.';
  end if;

  if c_barangay is not null
     and not exists (select 1 from public.barangays b where b.code = c_barangay) then
    raise exception 'Barangay code % is not in public.barangays.', c_barangay
      using hint = 'Use a code from 20260101090100_phase0_reference_data.sql, or leave it null.';
  end if;

  -- --- 1. Resolve or create the Supabase Auth account -----------------------
  select p.* into v_profile from public.profiles p where lower(p.email) = v_email limit 1;

  if v_profile.auth_user_id is not null then
    v_user_id := v_profile.auth_user_id;
  else
    select u.id into v_user_id from auth.users u where lower(u.email) = v_email limit 1;
  end if;

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    )
    values (
      '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated',
      v_email, crypt(c_password, gen_salt('bf')), now(),
      jsonb_build_object('provider', 'email', 'providers', array['email'], 'role', 'administrator'),
      jsonb_build_object(
        'first_name', c_first, 'last_name', c_last,
        'contact_number', c_contact, 'address_line', c_address,
        'barangay_code', c_barangay,
        'account_origin', 'first_admin_sql'
      ),
      now(), now(), '', '', '', ''
    );
  else
    -- Re-running refreshes the password and re-asserts the role. raw_user_meta_data
    -- is merged so a profile edited in the console is not thrown away.
    update auth.users
       set encrypted_password  = crypt(c_password, gen_salt('bf')),
           email_confirmed_at  = coalesce(email_confirmed_at, now()),
           raw_app_meta_data   = coalesce(raw_app_meta_data, '{}'::jsonb)
                                 || jsonb_build_object(
                                      'provider', 'email',
                                      'providers', array['email'],
                                      'role', 'administrator'),
           raw_user_meta_data  = coalesce(raw_user_meta_data, '{}'::jsonb)
                                 || jsonb_build_object('first_name', c_first, 'last_name', c_last),
           email               = v_email,
           updated_at          = now()
     where id = v_user_id;
  end if;

  -- --- 2. Auth identity ------------------------------------------------------
  -- Without an identity row GoTrue refuses the password grant even though the
  -- user exists. The column list differs between Supabase versions, so it is
  -- detected here rather than assumed.
  if not exists (select 1 from auth.identities i where i.user_id = v_user_id and i.provider = 'email') then
    if exists (
      select 1 from information_schema.columns
       where table_schema = 'auth' and table_name = 'identities' and column_name = 'provider_id'
    ) then
      v_identity_sql := $sql$
        insert into auth.identities
          (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
        values (gen_random_uuid(), $1, $1::text,
                jsonb_build_object('sub', $1::text, 'email', $2, 'email_verified', true),
                'email', now(), now(), now())
        on conflict do nothing
      $sql$;
    else
      v_identity_sql := $sql$
        insert into auth.identities
          (id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
        values (gen_random_uuid(), $1,
                jsonb_build_object('sub', $1::text, 'email', $2, 'email_verified', true),
                'email', now(), now(), now())
        on conflict do nothing
      $sql$;
    end if;

    execute v_identity_sql using v_user_id, v_email;
  end if;

  -- --- 3. Application profile ----------------------------------------------
  if v_profile.id is null then
    insert into public.profiles (
      auth_user_id, role, first_name, last_name, email,
      contact_number, address_line, barangay_code, account_status
    )
    values (
      v_user_id, 'administrator', c_first, c_last, v_email,
      c_contact, c_address, c_barangay, 'active'
    )
    on conflict (auth_user_id) do nothing;
  else
    update public.profiles
       set auth_user_id   = v_user_id,
           role           = 'administrator',
           account_status = 'active',
           status_reason  = null,
           contact_number = coalesce(contact_number, c_contact),
           address_line   = coalesce(address_line, c_address),
           barangay_code  = coalesce(barangay_code, c_barangay),
           updated_at     = now()
     where id = v_profile.id;
  end if;

  -- The link must exist before the trigger can be trusted on later sign-ups.
  if not exists (select 1 from public.profiles p where p.auth_user_id = v_user_id) then
    raise exception 'The administrator profile could not be linked to the auth account.';
  end if;

  raise notice 'SBTF first administrator ready: %', v_email;
end
$$;

-- ---------------------------------------------------------------------------
-- Verification — all three columns must read true before you close the editor.
-- ---------------------------------------------------------------------------
select
  p.email,
  p.role,
  p.account_status,
  (p.auth_user_id is not null)                                   as auth_linked,
  (u.encrypted_password is not null
   and u.encrypted_password <> '')                               as password_set,
  (u.email_confirmed_at is not null)                             as email_confirmed,
  exists (select 1 from auth.identities i
           where i.user_id = p.auth_user_id and i.provider = 'email') as identity_present,
  (u.raw_app_meta_data ->> 'role' = 'administrator')             as role_in_app_metadata
from public.profiles p
left join auth.users u on u.id = p.auth_user_id
where p.role = 'administrator'
order by p.created_at
limit 5;

commit;

-- If auth_linked, password_set or identity_present is false, the account will
-- not authenticate. Re-run this file: every step above is idempotent.
