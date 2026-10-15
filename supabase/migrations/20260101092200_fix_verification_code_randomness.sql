-- ===========================================================================
-- SBTF System — fix: verification code generation fails on the live project
--
-- fn_generate_verification_code() (migration 20260101090500) built its code
-- from gen_random_bytes(12):
--
--   v_bytes bytea := gen_random_bytes(12);
--
-- gen_random_bytes belongs to the pgcrypto extension, which Supabase installs
-- in the `extensions` schema. The function runs with
--
--   set search_path = public, pg_temp
--
-- so `gen_random_bytes` is not resolvable and every call raised
--
--   42883: function gen_random_bytes(integer) does not exist
--
-- That aborted rpc_staff_record_application() at the point it issues the
-- franchise record (fn_staff_issue_franchise_record -> fn_generate_verification_code),
-- which rolled back the stage change too. The "Record application" action
-- therefore failed every time and its button never advanced — the same class of
-- runtime error as the document-verification fix in 20260101092100.
--
-- The rewrite draws its bytes from gen_random_uuid(), a core PostgreSQL
-- function (no extension, no schema qualification) so the routine depends only
-- on pg_catalog. uuid_send() yields the 16 raw bytes of the UUID; the first 12
-- are used, preserving the original 32-character alphabet mapping exactly.
-- ===========================================================================

create or replace function public.fn_generate_verification_code()
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  -- Crockford-inspired alphabet: exactly 32 characters, excluding I, O, 0 and
  -- 1 so that manual entry from a printed certificate stays unambiguous (L is
  -- kept because 1 is not used). 256 is an exact multiple of 32, which makes the
  -- byte-to-character mapping uniform: each character carries exactly 5 bits.
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes    bytea := substring(uuid_send(gen_random_uuid()) from 1 for 12);
  v_result   text := '';
  i integer;
begin
  for i in 0..11 loop
    v_result := v_result || substr(v_alphabet, 1 + (get_byte(v_bytes, i) % 32), 1);
  end loop;
  return v_result;
end;
$$;

comment on function public.fn_generate_verification_code() is
  'Opaque 12-character verification identifier embedded in certificate QR codes. Draws randomness from gen_random_uuid() (core) rather than pgcrypto''s gen_random_bytes, so it resolves under the hardened search_path.';
