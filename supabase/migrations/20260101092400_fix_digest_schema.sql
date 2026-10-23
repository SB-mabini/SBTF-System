-- ===========================================================================
-- SBTF System — fix: digest() schema in rpc_verify_certificate
--
-- rpc_verify_certificate() (migration 20260101090700) calls pgcrypto's
-- digest() to hash failed verification attempt codes:
--
--   encode(digest(v_code, 'sha256'), 'hex')
--
-- digest() belongs to the pgcrypto extension, which Supabase installs
-- in the `extensions` schema. The function runs with
--
--   set search_path = public, pg_temp
--
-- so `digest()` is not resolvable and every call raised
--
--   42883: function digest(text, unknown) does not exist
--
-- That aborted rpc_verify_certificate() whenever a non-matching code was
-- typed into the certificate verifier — the same class of runtime error
-- as the gen_random_bytes fix in 20260101092200 and the document-verification
-- event fix in 20260101092100.
--
-- 20260101090700 is already applied to the live project, so the fix ships as
-- a new migration that recreates the trigger function, qualifying the call
-- as extensions.digest(...) so it resolves under the hardened search_path.
-- ===========================================================================

create or replace function public.rpc_verify_certificate(p_code text)
returns table (
  verification_status  public.certificate_verification_status,
  franchise_number     text,
  operator_display_name text,
  toda_name            text,
  issued_at            timestamptz,
  expires_at           timestamptz,
  verified_at          timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_code   text;
  v_status public.certificate_verification_status;
  v_number text;
  v_name   text;
  v_toda   text;
  v_issued timestamptz;
  v_expires timestamptz;
begin
  -- Accept codes typed with separators or lowercase.
  v_code := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));

  if length(v_code) = 12 then
    select
      case
        when fr.archived then 'archived'::public.certificate_verification_status
        when fr.expires_at < now() then 'expired'::public.certificate_verification_status
        else 'valid'::public.certificate_verification_status
      end,
      fr.franchise_number,
      upper(left(p.first_name, 1)) || repeat('*', greatest(length(p.first_name) - 1, 2)) || ' ' ||
        upper(left(p.last_name, 1)) || repeat('*', greatest(length(p.last_name) - 1, 2)),
      t.name,
      fr.issued_at,
      fr.expires_at
    into v_status, v_number, v_name, v_toda, v_issued, v_expires
    from public.franchise_records fr
    join public.profiles p on p.id = fr.operator_id
    join public.todas t on t.id = fr.toda_id
    where fr.verification_code = v_code;
  end if;

  if v_number is null then
    -- Record unsuccessful verification attempts as a security-relevant event
    -- without storing the attempted code itself (hash only).
    perform public.fn_log_activity(
      public.current_profile_id(),
      'security_event',
      'franchise_record',
      null,
      jsonb_build_object(
        'event', 'certificate_verification_failed',
        'code_hash', encode(extensions.digest(v_code, 'sha256'), 'hex')
      )
    );

    return query
      select 'not_found'::public.certificate_verification_status,
             null::text, null::text, null::text, null::timestamptz, null::timestamptz, now();
    return;
  end if;

  return query select v_status, v_number, v_name, v_toda, v_issued, v_expires, now();
end;
$$;

comment on function public.rpc_verify_certificate(text) is
  'Resolves a certificate verification code and returns only non-sensitive fields with a masked operator name. Safe for anonymous use by the QR scanner.';
