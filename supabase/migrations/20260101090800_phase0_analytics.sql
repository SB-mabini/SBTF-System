-- ===========================================================================
-- SBTF System — Phase 0.9
-- Descriptive and prescriptive analytics.
--
-- Every figure is computed inside PostgreSQL from the authoritative tables, so
-- the web and mobile clients never need to download raw records to build a
-- dashboard. Aggregates returned to clients contain no personal data.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Descriptive: headline counters
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_overview()
returns table (
  total_applications       bigint,
  pending_applications     bigint,
  approved_applications    bigint,
  rejected_applications    bigint,
  new_applications         bigint,
  renewal_applications     bigint,
  approval_rate            numeric,
  rejection_rate           numeric,
  avg_processing_days      numeric,
  median_processing_days   numeric,
  active_drivers           bigint,
  active_franchises        bigint,
  expiring_30              bigint,
  expiring_60              bigint,
  expiring_90              bigint,
  expired_franchises       bigint,
  total_todas              bigint,
  total_toda_members       bigint,
  verified_documents       bigint,
  pending_documents        bigint,
  rejected_documents       bigint,
  submitted_last_30_days   bigint,
  submitted_previous_30_days bigint,
  decided_last_30_days     bigint,
  unread_notifications     bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  return query
  select
    (select count(*) from public.franchise_applications),
    (select count(*) from public.franchise_applications a where a.status = 'pending'),
    (select count(*) from public.franchise_applications a where a.status = 'approved'),
    (select count(*) from public.franchise_applications a where a.status = 'rejected'),
    (select count(*) from public.franchise_applications a where a.application_type = 'new'),
    (select count(*) from public.franchise_applications a where a.application_type = 'renewal'),
    round((select count(*) from public.franchise_applications a where a.status = 'approved')::numeric * 100
          / nullif((select count(*) from public.franchise_applications a where a.status <> 'pending'), 0), 2),
    round((select count(*) from public.franchise_applications a where a.status = 'rejected')::numeric * 100
          / nullif((select count(*) from public.franchise_applications a where a.status <> 'pending'), 0), 2),
    (select round(avg(extract(epoch from (a.reviewed_at - a.submitted_at)) / 86400.0)::numeric, 2)
       from public.franchise_applications a where a.reviewed_at is not null),
    (select round(percentile_cont(0.5) within group (
              order by extract(epoch from (a.reviewed_at - a.submitted_at)) / 86400.0
            )::numeric, 2)
       from public.franchise_applications a where a.reviewed_at is not null),
    (select count(*) from public.profiles p where p.role = 'driver' and p.account_status = 'active'),
    (select count(*) from public.franchise_records r where r.archived = false and r.expires_at >= now()),
    (select count(*) from public.franchise_records r
      where r.archived = false and r.expires_at >= now() and r.expires_at < now() + interval '30 days'),
    (select count(*) from public.franchise_records r
      where r.archived = false and r.expires_at >= now() and r.expires_at < now() + interval '60 days'),
    (select count(*) from public.franchise_records r
      where r.archived = false and r.expires_at >= now() and r.expires_at < now() + interval '90 days'),
    (select count(*) from public.franchise_records r where r.archived = false and r.expires_at < now()),
    (select count(*) from public.todas t where t.is_active),
    (select coalesce(sum(t.members_count), 0) from public.todas t where t.is_active),
    (select count(*) from public.franchise_documents d where d.verification_status = 'verified'),
    (select count(*) from public.franchise_documents d where d.verification_status = 'pending'),
    (select count(*) from public.franchise_documents d where d.verification_status = 'rejected'),
    (select count(*) from public.franchise_applications a where a.submitted_at >= now() - interval '30 days'),
    (select count(*) from public.franchise_applications a
      where a.submitted_at >= now() - interval '60 days' and a.submitted_at < now() - interval '30 days'),
    (select count(*) from public.franchise_applications a where a.reviewed_at >= now() - interval '30 days'),
    (select count(*) from public.notifications n where n.read = false);
end;
$$;

comment on function public.rpc_analytics_overview() is
  'Dashboard headline counters and rates. Staff/administrator only.';

-- ---------------------------------------------------------------------------
-- Descriptive: monthly application trend
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_application_trends(p_months integer default 12)
returns table (
  month_start     date,
  month_label     text,
  submitted       bigint,
  new_count       bigint,
  renewal_count   bigint,
  approved        bigint,
  rejected        bigint,
  decided         bigint,
  avg_process_days numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  if p_months is null or p_months < 1 or p_months > 36 then
    raise exception 'p_months must be between 1 and 36' using errcode = 'P0001';
  end if;

  return query
  with months as (
    select generate_series(
             date_trunc('month', now()) - make_interval(months => p_months - 1),
             date_trunc('month', now()),
             interval '1 month'
           )::date as month_start
  ),
  apps as (
    select a.*, date_trunc('month', a.submitted_at)::date as submitted_month,
                  date_trunc('month', a.reviewed_at)::date as reviewed_month
      from public.franchise_applications a
  )
  select
    m.month_start,
    to_char(m.month_start, 'Mon YYYY'),
    count(a.id) filter (where a.submitted_month = m.month_start),
    count(a.id) filter (where a.submitted_month = m.month_start and a.application_type = 'new'),
    count(a.id) filter (where a.submitted_month = m.month_start and a.application_type = 'renewal'),
    count(a.id) filter (where a.reviewed_month = m.month_start and a.status = 'approved'),
    count(a.id) filter (where a.reviewed_month = m.month_start and a.status = 'rejected'),
    count(a.id) filter (where a.reviewed_month = m.month_start and a.status <> 'pending'),
    round(avg(extract(epoch from (a.reviewed_at - a.submitted_at)) / 86400.0)
          filter (where a.reviewed_month = m.month_start)::numeric, 2)
  from months m
  left join apps a
    on a.submitted_month = m.month_start or a.reviewed_month = m.month_start
  group by m.month_start
  order by m.month_start;
end;
$$;

-- ---------------------------------------------------------------------------
-- Descriptive: per-TODA breakdown
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_by_toda()
returns table (
  toda_id            uuid,
  toda_name          text,
  members_count      integer,
  applications       bigint,
  new_applications   bigint,
  renewal_applications bigint,
  approved           bigint,
  rejected           bigint,
  pending            bigint,
  active_franchises  bigint,
  approval_rate      numeric,
  last_submission_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  return query
  select
    t.id,
    t.name,
    t.members_count,
    count(a.id),
    count(a.id) filter (where a.application_type = 'new'),
    count(a.id) filter (where a.application_type = 'renewal'),
    count(a.id) filter (where a.status = 'approved'),
    count(a.id) filter (where a.status = 'rejected'),
    count(a.id) filter (where a.status = 'pending'),
    (select count(*) from public.franchise_records r
      where r.toda_id = t.id and r.archived = false and r.expires_at >= now()),
    round(count(a.id) filter (where a.status = 'approved')::numeric * 100
          / nullif(count(a.id) filter (where a.status <> 'pending'), 0), 2),
    max(a.submitted_at)
  from public.todas t
  left join public.franchise_applications a on a.toda_id = t.id
  group by t.id, t.name, t.members_count
  order by count(a.id) desc, t.name;
end;
$$;

-- ---------------------------------------------------------------------------
-- Descriptive: processing time distribution
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_processing_time(p_months integer default 12)
returns table (
  month_start  date,
  month_label  text,
  decided      bigint,
  approved     bigint,
  rejected     bigint,
  avg_days     numeric,
  median_days  numeric,
  p90_days     numeric,
  longest_days numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  return query
  with months as (
    select generate_series(
             date_trunc('month', now()) - make_interval(months => greatest(coalesce(p_months, 12), 1) - 1),
             date_trunc('month', now()),
             interval '1 month'
           )::date as month_start
  ),
  decided as (
    select date_trunc('month', a.reviewed_at)::date as month_start,
           a.status,
           extract(epoch from (a.reviewed_at - a.submitted_at)) / 86400.0 as days
      from public.franchise_applications a
     where a.reviewed_at is not null
  )
  select
    m.month_start,
    to_char(m.month_start, 'Mon YYYY'),
    count(d.days),
    count(d.days) filter (where d.status = 'approved'),
    count(d.days) filter (where d.status = 'rejected'),
    round(avg(d.days)::numeric, 2),
    round(percentile_cont(0.5) within group (order by d.days)::numeric, 2),
    round(percentile_cont(0.9) within group (order by d.days)::numeric, 2),
    round(max(d.days)::numeric, 2)
  from months m
  left join decided d on d.month_start = m.month_start
  group by m.month_start
  order by m.month_start;
end;
$$;

-- ---------------------------------------------------------------------------
-- Descriptive: franchise expirations
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_expiring(p_days integer default 180)
returns table (
  record_id        uuid,
  franchise_number text,
  operator_name    text,
  toda_name        text,
  expires_at       timestamptz,
  days_remaining   integer,
  bucket           text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  return query
  select
    r.id,
    r.franchise_number,
    p.full_name,
    t.name,
    r.expires_at,
    floor(extract(epoch from (r.expires_at - now())) / 86400)::integer,
    case
      when r.expires_at < now() then 'expired'
      when r.expires_at < now() + interval '30 days' then '0-30 days'
      when r.expires_at < now() + interval '60 days' then '31-60 days'
      when r.expires_at < now() + interval '90 days' then '61-90 days'
      else '91+ days'
    end
  from public.franchise_records r
  join public.profiles p on p.id = r.operator_id
  join public.todas t on t.id = r.toda_id
  where r.archived = false
    and r.expires_at < now() + make_interval(days => greatest(coalesce(p_days, 180), 1))
  order by r.expires_at asc;
end;
$$;

-- ---------------------------------------------------------------------------
-- Descriptive: documentary requirement compliance
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_document_compliance()
returns table (
  document_type       public.document_type,
  total               bigint,
  verified            bigint,
  pending             bigint,
  rejected            bigint,
  verified_rate       numeric,
  oldest_pending_days integer
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  return query
  select
    dt.document_type,
    count(d.id),
    count(d.id) filter (where d.verification_status = 'verified'),
    count(d.id) filter (where d.verification_status = 'pending'),
    count(d.id) filter (where d.verification_status = 'rejected'),
    round(count(d.id) filter (where d.verification_status = 'verified')::numeric * 100
          / nullif(count(d.id), 0), 2),
    floor(max(extract(epoch from (now() - d.uploaded_at)) / 86400)
          filter (where d.verification_status = 'pending'))::integer
  from unnest(enum_range(null::public.document_type)) as dt(document_type)
  left join public.franchise_documents d on d.document_type = dt.document_type
  group by dt.document_type
  order by dt.document_type;
end;
$$;

-- ---------------------------------------------------------------------------
-- Prescriptive: rule-based operational recommendations
--
-- Deterministic, explainable, threshold-driven guidance. Each row states the
-- finding, the suggested action, the metric behind it and the threshold used,
-- so a human decision maker can audit the reasoning. Nothing here ever changes
-- a record: this is advisory output only.
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_prescriptive()
returns table (
  indicator_key   text,
  severity        text,
  category        text,
  finding         text,
  recommendation  text,
  data_basis      text,
  metric_value    numeric,
  threshold_value numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_avg_monthly        numeric;
  v_peak_month         text;
  v_peak_count         numeric;
  v_months_observed    integer;
  v_backlog            integer;
  v_oldest_backlog     integer;
  v_pending_docs       integer;
  v_docs_older_than_5  integer;
  v_rate_30            numeric;
  v_rate_baseline      numeric;
  v_expiring_30        integer;
  v_expiring_60        integer;
  v_expired_open       integer;
  v_avg_processing     numeric;
  v_silent_todas       integer;
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  -- Monthly submission profile (last 12 months)
  select coalesce(avg(cnt), 0), count(*)
    into v_avg_monthly, v_months_observed
    from (
      select date_trunc('month', a.submitted_at) as m, count(*)::numeric as cnt
        from public.franchise_applications a
       where a.submitted_at >= now() - interval '12 months'
       group by 1
    ) s;

  select to_char(m, 'Mon YYYY'), cnt
    into v_peak_month, v_peak_count
    from (
      select date_trunc('month', a.submitted_at) as m, count(*)::numeric as cnt
        from public.franchise_applications a
       where a.submitted_at >= now() - interval '12 months'
       group by 1
       order by cnt desc, m desc
       limit 1
    ) p;

  -- Backlog
  select count(*), coalesce(floor(max(extract(epoch from (now() - a.submitted_at)) / 86400))::integer, 0)
    into v_backlog, v_oldest_backlog
    from public.franchise_applications a
   where a.status = 'pending';

  -- Document verification workload
  select count(*),
         count(*) filter (where d.uploaded_at < now() - interval '5 days')
    into v_pending_docs, v_docs_older_than_5
    from public.franchise_documents d
   where d.verification_status = 'pending';

  -- Approval-rate movement
  select round(count(*) filter (where a.status = 'approved')::numeric * 100
               / nullif(count(*) filter (where a.status <> 'pending'), 0), 2)
    into v_rate_30
    from public.franchise_applications a
   where a.reviewed_at >= now() - interval '30 days';

  select round(count(*) filter (where a.status = 'approved')::numeric * 100
               / nullif(count(*) filter (where a.status <> 'pending'), 0), 2)
    into v_rate_baseline
    from public.franchise_applications a
   where a.reviewed_at >= now() - interval '13 months'
     and a.reviewed_at < now() - interval '30 days';

  -- Expirations
  select count(*) filter (where r.expires_at >= now() and r.expires_at < now() + interval '30 days'),
         count(*) filter (where r.expires_at >= now() and r.expires_at < now() + interval '60 days'),
         count(*) filter (where r.expires_at < now())
    into v_expiring_30, v_expiring_60, v_expired_open
    from public.franchise_records r
   where r.archived = false;

  select avg(extract(epoch from (a.reviewed_at - a.submitted_at)) / 86400.0)
    into v_avg_processing
    from public.franchise_applications a
   where a.reviewed_at >= now() - interval '90 days';

  select count(*) into v_silent_todas
    from public.todas t
   where t.is_active
     and t.members_count > 0
     and not exists (
           select 1 from public.franchise_applications a
            where a.toda_id = t.id and a.submitted_at >= now() - interval '12 months'
         );

  -- 1) Staffing during peak application months ------------------------------
  if v_months_observed >= 3 and coalesce(v_avg_monthly, 0) > 0
     and v_peak_count >= v_avg_monthly * 1.3 then
    indicator_key := 'peak_period_staffing';
    severity := case when v_peak_count >= v_avg_monthly * 1.6 then 'critical' else 'attention' end;
    category := 'Staffing';
    finding := format('Application volume peaks in %s with %s submissions against a monthly average of %s.',
                      v_peak_month, v_peak_count::integer, round(v_avg_monthly, 1));
    recommendation := format('Consider assigning additional processing staff or extending review hours during %s, %s and the immediately following month.',
                             to_char(to_date(v_peak_month, 'Mon YYYY') - interval '1 month', 'Mon YYYY'),
                             v_peak_month);
    data_basis := 'franchise_applications.submitted_at grouped by month, last 12 months';
    metric_value := v_peak_count;
    threshold_value := round(v_avg_monthly * 1.3, 2);
    return next;
  end if;

  -- 2) Processing backlog ---------------------------------------------------
  if v_backlog >= 5 then
    indicator_key := 'pending_backlog';
    severity := case when v_backlog >= 15 or v_oldest_backlog >= 14 then 'critical' else 'attention' end;
    category := 'Processing capacity';
    finding := format('%s application(s) are awaiting a decision; the oldest has been pending for %s day(s).',
                      v_backlog, v_oldest_backlog);
    recommendation := 'Prioritise the oldest pending applications first and consider batch document verification to reduce the queue.';
    data_basis := 'franchise_applications where status = ''pending''';
    metric_value := v_backlog;
    threshold_value := 5;
    return next;
  end if;

  -- 3) Document verification bottleneck -------------------------------------
  if v_docs_older_than_5 >= 10 then
    indicator_key := 'document_verification_backlog';
    severity := case when v_docs_older_than_5 >= 25 then 'critical' else 'attention' end;
    category := 'Document verification';
    finding := format('%s uploaded document(s) have been pending verification for more than 5 days (of %s pending).',
                      v_docs_older_than_5, v_pending_docs);
    recommendation := 'Schedule a document verification block and notify affected applicants so missing or unclear copies are re-uploaded early.';
    data_basis := 'franchise_documents where verification_status = ''pending'' grouped by age';
    metric_value := v_docs_older_than_5;
    threshold_value := 10;
    return next;
  end if;

  -- 4) Approval-rate movement ----------------------------------------------
  if v_rate_30 is not null and v_rate_baseline is not null
     and abs(v_rate_30 - v_rate_baseline) >= 15 then
    indicator_key := 'approval_rate_movement';
    severity := 'attention';
    category := 'Decision consistency';
    finding := format('The approval rate over the last 30 days is %s%% against a %s%% rolling baseline — a movement of %s percentage points.',
                      v_rate_30, v_rate_baseline, round(abs(v_rate_30 - v_rate_baseline), 2));
    recommendation := 'Review recent evaluation notes for consistency with the documentary requirements before the next approval cycle.';
    data_basis := 'franchise_applications reviewed in the last 30 days vs. the preceding 13 months (decided applications only)';
    metric_value := v_rate_30;
    threshold_value := v_rate_baseline;
    return next;
  end if;

  -- 5) Renewal pipeline ----------------------------------------------------
  if v_expiring_30 >= 10 then
    indicator_key := 'renewal_pipeline';
    severity := case when v_expiring_30 >= 25 then 'critical' else 'attention' end;
    category := 'Renewal';
    finding := format('%s franchise(s) expire within 30 days and %s within 60 days.', v_expiring_30, v_expiring_60);
    recommendation := 'Prioritise renewal reminders for the nearest expirations and prepare counter capacity for the expected renewal submissions.';
    data_basis := 'franchise_records.expires_at buckets for active, non-archived records';
    metric_value := v_expiring_30;
    threshold_value := 10;
    return next;
  end if;

  -- 6) Expired franchises without renewal ----------------------------------
  if v_expired_open >= 5 then
    indicator_key := 'expired_unrenewed';
    severity := 'critical';
    category := 'Renewal';
    finding := format('%s franchise record(s) have already lapsed and have no renewal application on file.', v_expired_open);
    recommendation := 'Prepare an enforcement and assistance schedule for lapsed franchises, starting with those expired the longest.';
    data_basis := 'franchise_records where archived = false and expires_at < now()';
    metric_value := v_expired_open;
    threshold_value := 5;
    return next;
  end if;

  -- 7) Processing time -----------------------------------------------------
  if v_avg_processing is not null and v_avg_processing > 5 then
    indicator_key := 'processing_time';
    severity := case when v_avg_processing > 10 then 'critical' else 'attention' end;
    category := 'Processing capacity';
    finding := format('Average end-to-end processing time over the last 90 days is %s day(s).', round(v_avg_processing::numeric, 2));
    recommendation := 'Identify the stage where applications idle longest (document verification or final review) and address that stage first.';
    data_basis := 'franchise_applications.reviewed_at - submitted_at, last 90 days';
    metric_value := round(v_avg_processing::numeric, 2);
    threshold_value := 5;
    return next;
  end if;

  -- 8) TODA outreach -------------------------------------------------------
  if v_silent_todas >= 3 then
    indicator_key := 'toda_outreach';
    severity := 'attention';
    category := 'Coverage';
    finding := format('%s accredited TODA(s) with registered members filed no application in the last 12 months.', v_silent_todas);
    recommendation := 'Coordinate with the concerned TODA officers to confirm membership status and encourage compliance with franchise registration.';
    data_basis := 'todas joined against franchise_applications.submitted_at over 12 months';
    metric_value := v_silent_todas;
    threshold_value := 3;
    return next;
  end if;

  return;
end;
$$;

comment on function public.rpc_analytics_prescriptive() is
  'Rule-based prescriptive analytics. Returns only actionable indicators, each with its metric, threshold and data basis. Advisory only — it never modifies data.';

-- ---------------------------------------------------------------------------
-- AI context: aggregated, anonymised payload for the Groq Edge Function
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_ai_context(p_months integer default 12)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if not public.is_staff_or_admin() then
    raise exception 'Staff or administrator access required' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'generated_at', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM'),
    'municipality', (select value #>> '{}' from public.system_settings where key = 'municipality_name'),
    'period_months', greatest(coalesce(p_months, 12), 1),
    'totals', jsonb_build_object(
      'applications_total', (select count(*) from public.franchise_applications),
      'applications_pending', (select count(*) from public.franchise_applications where status = 'pending'),
      'applications_approved', (select count(*) from public.franchise_applications where status = 'approved'),
      'applications_rejected', (select count(*) from public.franchise_applications where status = 'rejected'),
      'applications_new', (select count(*) from public.franchise_applications where application_type = 'new'),
      'applications_renewal', (select count(*) from public.franchise_applications where application_type = 'renewal'),
      'active_franchises', (select count(*) from public.franchise_records where archived = false and expires_at >= now()),
      'active_drivers', (select count(*) from public.profiles where role = 'driver' and account_status = 'active'),
      'accredited_todas', (select count(*) from public.todas where is_active),
      'registered_toda_members', (select coalesce(sum(members_count), 0) from public.todas where is_active)
    ),
    'rates', jsonb_build_object(
      'approval_rate_percent', (select round(count(*) filter (where status = 'approved')::numeric * 100
                                             / nullif(count(*) filter (where status <> 'pending'), 0), 2)
                                  from public.franchise_applications),
      'rejection_rate_percent', (select round(count(*) filter (where status = 'rejected')::numeric * 100
                                              / nullif(count(*) filter (where status <> 'pending'), 0), 2)
                                   from public.franchise_applications)
    ),
    'processing_time_days', jsonb_build_object(
      'average', (select round(avg(extract(epoch from (reviewed_at - submitted_at)) / 86400.0)::numeric, 2)
                    from public.franchise_applications where reviewed_at is not null),
      'median', (select round(percentile_cont(0.5) within group (
                          order by extract(epoch from (reviewed_at - submitted_at)) / 86400.0)::numeric, 2)
                   from public.franchise_applications where reviewed_at is not null),
      'last_90_days_average', (select round(avg(extract(epoch from (reviewed_at - submitted_at)) / 86400.0)::numeric, 2)
                                 from public.franchise_applications
                                where reviewed_at >= now() - interval '90 days')
    ),
    'monthly_trend', (
      select coalesce(jsonb_agg(row_to_json(m)::jsonb order by m.month), '[]'::jsonb)
      from (
        select to_char(date_trunc('month', a.submitted_at), 'YYYY-MM') as month,
               count(*) as submitted,
               count(*) filter (where a.application_type = 'new') as new_applications,
               count(*) filter (where a.application_type = 'renewal') as renewal_applications,
               count(*) filter (where a.status = 'approved') as approved,
               count(*) filter (where a.status = 'rejected') as rejected,
               count(*) filter (where a.status = 'pending') as pending
          from public.franchise_applications a
         where a.submitted_at >= now() - make_interval(months => greatest(coalesce(p_months, 12), 1))
         group by 1
      ) m
    ),
    'toda_trends', (
      select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.applications desc), '[]'::jsonb)
      from (
        select td.name as toda,
               td.members_count as members,
               count(a.id) as applications,
               count(a.id) filter (where a.status = 'approved') as approved,
               count(a.id) filter (where a.status = 'rejected') as rejected,
               count(a.id) filter (where a.status = 'pending') as pending,
               count(a.id) filter (where a.submitted_at >= now() - interval '90 days') as last_90_days
          from public.todas td
          left join public.franchise_applications a on a.toda_id = td.id
         group by td.name, td.members_count
      ) t
    ),
    'expirations', jsonb_build_object(
      'expired', (select count(*) from public.franchise_records where archived = false and expires_at < now()),
      'within_30_days', (select count(*) from public.franchise_records
                          where archived = false and expires_at >= now() and expires_at < now() + interval '30 days'),
      'within_60_days', (select count(*) from public.franchise_records
                          where archived = false and expires_at >= now() and expires_at < now() + interval '60 days'),
      'within_90_days', (select count(*) from public.franchise_records
                          where archived = false and expires_at >= now() and expires_at < now() + interval '90 days')
    ),
    'documents', jsonb_build_object(
      'total', (select count(*) from public.franchise_documents),
      'verified', (select count(*) from public.franchise_documents where verification_status = 'verified'),
      'pending', (select count(*) from public.franchise_documents where verification_status = 'pending'),
      'rejected', (select count(*) from public.franchise_documents where verification_status = 'rejected')
    ),
    'rejection_reasons_summary', (
      select coalesce(jsonb_agg(row_to_json(r)::jsonb), '[]'::jsonb)
      from (
        select count(*) as occurrences,
               left(regexp_replace(rejection_reason, '\s+', ' ', 'g'), 120) as reason_excerpt
          from public.franchise_applications
         where status = 'rejected' and rejection_reason is not null
         group by 2
         order by 1 desc
         limit 5
      ) r
    )
  ) into v_result;

  return v_result;
end;
$$;

comment on function public.rpc_analytics_ai_context(integer) is
  'Aggregated, anonymised analytics payload. Contains counts, rates, TODA names and error text excerpts only — no applicant names, addresses, plate or engine numbers.';

-- ---------------------------------------------------------------------------
-- Administrator-only: system health and usage
-- ---------------------------------------------------------------------------
create or replace function public.rpc_analytics_system_health()
returns table (
  users_total          bigint,
  users_administrators bigint,
  users_staff          bigint,
  users_drivers        bigint,
  users_inactive       bigint,
  activity_logs_7d     bigint,
  ai_requests_30d      bigint,
  ai_requests_failed_30d bigint,
  certificates_issued  bigint,
  document_objects     bigint,
  certificate_objects  bigint,
  last_activity_at     timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  return query
  select
    (select count(*) from public.profiles),
    (select count(*) from public.profiles where role = 'administrator'),
    (select count(*) from public.profiles where role = 'staff'),
    (select count(*) from public.profiles where role = 'driver'),
    (select count(*) from public.profiles where account_status <> 'active'),
    (select count(*) from public.activity_logs where "timestamp" >= now() - interval '7 days'),
    (select count(*) from public.ai_request_logs where created_at >= now() - interval '30 days'),
    (select count(*) from public.ai_request_logs where created_at >= now() - interval '30 days' and status <> 'success'),
    (select count(*) from public.franchise_records where certificate_storage_path is not null),
    (select count(*) from storage.objects where bucket_id = 'franchise-documents'),
    (select count(*) from storage.objects where bucket_id = 'certificates'),
    (select max("timestamp") from public.activity_logs);
end;
$$;

comment on function public.rpc_analytics_system_health() is
  'Administrator-only system usage counters.';
