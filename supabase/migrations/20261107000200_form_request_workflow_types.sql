-- ===========================================================================
-- SBTF System — Request-form-first workflow (part 1 of 3)
-- Type values, settings category and the editable form letterhead.
--
-- IMPORTANT: enum values added by ALTER TYPE ... ADD VALUE may not be used in
-- the same transaction that adds them. Anything that references the new values
-- lives in a later migration (20261106000200_form_request_rpcs.sql).
-- ===========================================================================

-- --- form request status ----------------------------------------------------
-- `rejected` closes a review round with a reason; the driver then edits and
-- resubmits the SAME row (which sets it back to `requested`).
alter type public.form_request_status add value if not exists 'rejected';

comment on type public.form_request_status is
  'Lifecycle of a pre-application form request: requested -> issued -> converted, or requested -> rejected -> (resubmitted) requested, or cancelled.';

-- --- notifications ----------------------------------------------------------
alter type public.notification_type add value if not exists 'form_request_rejected';
alter type public.notification_type add value if not exists 'form_request_resubmitted';
alter type public.notification_type add value if not exists 'form_request_review_reminder';
alter type public.notification_type add value if not exists 'form_request_review_overdue';

-- --- audit actions ----------------------------------------------------------
alter type public.activity_action add value if not exists 'form_request_updated';
alter type public.activity_action add value if not exists 'form_request_rejected';
alter type public.activity_action add value if not exists 'form_request_resubmitted';
alter type public.activity_action add value if not exists 'form_request_converted';
alter type public.activity_action add value if not exists 'form_request_printed';
alter type public.activity_action add value if not exists 'form_request_review_overdue';

-- --- settings category ------------------------------------------------------
alter table public.system_settings drop constraint if exists system_settings_category_check;
alter table public.system_settings add constraint system_settings_category_check
  check (category in ('general', 'franchise', 'notifications', 'ai', 'certificate', 'forms'));

-- --- editable letterhead and review policy ----------------------------------
insert into public.system_settings (key, value, data_type, category, label, description, is_public) values
  ('form_request_addressee', '"Hon. Presiding Officer and Hon. Members of the Sangguniang Bayan"'::jsonb,
   'string', 'forms', 'Addressee',
   'First line of the request letter printed on the vehicle/franchise request form.', true),
  ('form_request_municipality', '"Municipality of Mabini"'::jsonb,
   'string', 'forms', 'Municipality',
   'Municipality printed on the request letter.', true),
  ('form_request_location', '"Mabini, Batangas"'::jsonb,
   'string', 'forms', 'Location',
   'Province/location printed under the municipality on the request letter.', true),
  ('form_request_body', '"I am applying for the approval of my application for franchise of that tricycle, more particularly described as follows:"'::jsonb,
   'string', 'forms', 'Letter body',
   'Opening sentence of the request letter, above the vehicle description table.', true),
  ('form_request_review_days', '3'::jsonb,
   'number', 'forms', 'Staff review deadline (days)',
   'Number of days staff have to review a submitted request before it is flagged overdue. Allowed range: 1 to 3.', true),
  ('form_request_review_reminder_hours', '12'::jsonb,
   'number', 'forms', 'Review reminder lead time (hours)',
   'How long before the staff review deadline a reminder notification is sent.', true),
  ('form_request_signature_required', 'true'::jsonb,
   'boolean', 'forms', 'Signature required',
   'Require a drawn or typed signature on every new request.', true),
  ('form_request_allow_typed_signature', 'true'::jsonb,
   'boolean', 'forms', 'Allow typed signature',
   'Let the driver type their name instead of drawing a signature.', true)
on conflict (key) do nothing;
