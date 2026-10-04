-- ===========================================================================
-- SBTF System — Phase 0.2 (reference data)
-- Roles, barangays of Mabini, and default system settings.
--
-- These are SYSTEM reference records, not demo data: they are created by the
-- migration so that a freshly deployed database is immediately functional.
-- Demo/anonymised sample data lives in supabase/seed.sql instead.
-- ===========================================================================

-- --- roles ------------------------------------------------------------------
create table if not exists public.roles (
  code        public.user_role primary key,
  label       text not null,
  description text not null,
  -- Lower rank = higher privilege. Used to forbid privilege escalation
  -- (e.g. staff can never act on an administrator account).
  rank        smallint not null unique,
  is_client_self_registerable boolean not null default false,
  created_at  timestamptz not null default now()
);

insert into public.roles (code, label, description, rank, is_client_self_registerable)
values
  ('administrator', 'Administrator',
   'Highest level of access. Manages users, roles, system settings, analytics, reports and reviews activity logs. Cannot bypass database security.',
   1, false),
  ('staff', 'Staff',
   'Processes applications, verifies documents, approves or rejects applications, manages franchise records and generates certificates.',
   2, false),
  ('driver', 'Tricycle Driver / Operator',
   'Registers, submits new and renewal franchise applications, uploads documents, tracks status and views certificates.',
   3, true)
on conflict (code) do update
  set label = excluded.label,
      description = excluded.description,
      rank = excluded.rank,
      is_client_self_registerable = excluded.is_client_self_registerable;

-- --- barangays (official PSA listing, Municipality of Mabini, Batangas) -----
create table if not exists public.barangays (
  code     text primary key,
  name     text not null unique,
  sort_order smallint not null,
  created_at timestamptz not null default now()
);

insert into public.barangays (code, name, sort_order) values
  ('041016001', 'Anilao Proper', 1),
  ('041016002', 'Anilao East', 2),
  ('041016003', 'Bagalangit', 3),
  ('041016004', 'Bulacan', 4),
  ('041016005', 'Calamias', 5),
  ('041016006', 'Estrella', 6),
  ('041016007', 'Gasang', 7),
  ('041016008', 'Laurel', 8),
  ('041016009', 'Ligaya', 9),
  ('041016010', 'Mainaga', 10),
  ('041016011', 'Mainit', 11),
  ('041016012', 'Majuben', 12),
  ('041016013', 'Malimatoc I', 13),
  ('041016014', 'Malimatoc II', 14),
  ('041016015', 'Nag-iba', 15),
  ('041016016', 'Pilahan', 16),
  ('041016017', 'Poblacion', 17),
  ('041016018', 'Pulang Lupa', 18),
  ('041016019', 'Pulong Anahao', 19),
  ('041016020', 'Pulong Balibaguhan', 20),
  ('041016021', 'Pulong Niogan', 21),
  ('041016022', 'Saguing', 22),
  ('041016023', 'Sampaguita', 23),
  ('041016024', 'San Francisco', 24),
  ('041016025', 'San Jose', 25),
  ('041016026', 'San Juan', 26),
  ('041016027', 'San Teodoro', 27),
  ('041016028', 'Santa Ana', 28),
  ('041016029', 'Santa Mesa', 29),
  ('041016030', 'Santo Niño', 30),
  ('041016031', 'Santo Tomas', 31),
  ('041016032', 'Solo', 32),
  ('041016033', 'Talaga East', 33),
  ('041016034', 'Talaga Proper', 34)
on conflict (code) do nothing;

-- --- system_settings --------------------------------------------------------
-- Non-secret, municipality-configurable values. Secrets (Groq API key,
-- service-role key, SMTP credentials) live only in Edge Function / Vercel
-- environment variables and are never stored here.
create table if not exists public.system_settings (
  key          text primary key,
  value        jsonb not null,
  data_type    text not null default 'string'
               check (data_type in ('string', 'number', 'boolean', 'json', 'string_array')),
  category     text not null default 'general'
               check (category in ('general', 'franchise', 'notifications', 'ai', 'certificate')),
  label        text not null,
  description  text not null,
  is_public    boolean not null default true,
  updated_by   uuid,
  updated_at   timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

insert into public.system_settings (key, value, data_type, category, label, description, is_public) values
  ('municipality_name', '"Municipality of Mabini"'::jsonb, 'string', 'general',
   'Municipality name', 'Displayed on the interface, reports and certificates.', true),
  ('province_name', '"Batangas"'::jsonb, 'string', 'general',
   'Province', 'Displayed on the interface, reports and certificates.', true),
  ('office_name', '"Sangguniang Bayan ng Mabini — Committee on Transportation"'::jsonb, 'string', 'general',
   'Implementing office', 'Office responsible for tricycle franchising and driver registration.', true),
  ('office_email', '"sb.mabini@example.gov.ph"'::jsonb, 'string', 'general',
   'Official e-mail', 'Published contact address for franchising concerns.', true),
  ('office_contact_number', '"(043) 000-0000"'::jsonb, 'string', 'general',
   'Official contact number', 'Published contact number for franchising concerns.', true),
  ('franchise_validity_months', '12'::jsonb, 'number', 'franchise',
   'Franchise validity (months)', 'Validity period applied to newly issued franchise records.', true),
  ('franchise_number_prefix', '"MAB-TR"'::jsonb, 'string', 'franchise',
   'Franchise number prefix', 'Prefix used when generating franchise numbers.', true),
  ('renewal_reminder_days', '[90, 60, 30]'::jsonb, 'json', 'notifications',
   'Renewal reminder windows (days)', 'Days before expiry at which a renewal reminder notification is raised.', true),
  ('notification_retention_days', '365'::jsonb, 'number', 'notifications',
   'Notification retention (days)', 'Retention period applied by the housekeeping routine.', false),
  ('ai_model', '"llama-3.3-70b-versatile"'::jsonb, 'string', 'ai',
   'Groq model', 'Groq model identifier used by the AI decision-support Edge Function.', false),
  ('ai_enabled', 'true'::jsonb, 'boolean', 'ai',
   'AI decision support enabled', 'When disabled the AI advisory endpoints refuse to run.', false),
  ('ai_max_requests_per_user_per_day', '20'::jsonb, 'number', 'ai',
   'AI requests per user per day', 'Soft rate limit protecting the shared Groq quota.', false),
  ('certificate_signatory_name', '"HON. CITY/MUNICIPAL MAYOR"'::jsonb, 'string', 'certificate',
   'Certificate signatory', 'Name printed on the generated franchise certificate.', true),
  ('certificate_signatory_position', '"Municipal Mayor"'::jsonb, 'string', 'certificate',
   'Signatory position', 'Position printed under the signatory name.', true),
  ('certificate_footer_note', '"This certificate is verifiable through the QR code printed on it."'::jsonb, 'string', 'certificate',
   'Certificate footer note', 'Advisory note printed at the bottom of every certificate.', true),
  ('certificate_verification_base_url', '"http://localhost:3000/verify"'::jsonb, 'string', 'certificate',
   'Certificate verification URL', 'Base URL encoded in the certificate QR code.', true)
on conflict (key) do nothing;
