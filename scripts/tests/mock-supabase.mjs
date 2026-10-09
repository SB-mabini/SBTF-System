/**
 * In-memory stand-in for a Supabase project, used by `npm run test:verify`.
 *
 * It answers the exact requests scripts/verify-live.mjs makes, so the verifier
 * itself can be exercised in CI without a database:
 *
 *   createMockFetch()                → a healthy project
 *   createMockFetch({ mode: "renamed" }) → the same project with one analytics
 *                                       column renamed, which is the failure the
 *                                       verifier exists to catch
 *
 * Only the handful of endpoints the verifier touches are implemented. Anything
 * else answers 404 with a PostgREST-shaped body so a wrong request is visible
 * rather than silently passing.
 */
const BASE = "https://mock-project.supabase.co";

/** Row templates, one per interface the verifier compares. */
const ROWS = {
  rpc_analytics_overview: {
    total_applications: 42,
    pending_applications: 7,
    approved_applications: 30,
    rejected_applications: 5,
    new_applications: 26,
    renewal_applications: 16,
    approval_rate: 71.43,
    rejection_rate: 11.9,
    avg_processing_days: 3.5,
    median_processing_days: 3,
    active_drivers: 38,
    active_franchises: 30,
    expiring_30: 2,
    expiring_60: 5,
    expiring_90: 9,
    expired_franchises: 1,
    total_todas: 24,
    total_toda_members: 817,
    verified_documents: 120,
    pending_documents: 18,
    rejected_documents: 4,
    submitted_last_30_days: 6,
    submitted_previous_30_days: 9,
    decided_last_30_days: 8,
    unread_notifications: 3,
  },
  rpc_analytics_application_trends: {
    month_start: "2026-01-01T00:00:00+00:00",
    month_label: "Jan 2026",
    submitted: 6,
    new_count: 4,
    renewal_count: 2,
    approved: 5,
    rejected: 1,
    decided: 6,
    avg_process_days: 3.5,
  },
  rpc_analytics_by_toda: {
    toda_id: "11111111-1111-1111-1111-111111111111",
    toda_name: "TODA Anilao Proper",
    members_count: 63,
    applications: 5,
    new_applications: 4,
    renewal_applications: 1,
    approved: 4,
    rejected: 1,
    pending: 0,
    active_franchises: 4,
    approval_rate: 80,
    last_submission_at: "2026-01-05T08:00:00+00:00",
  },
  rpc_analytics_processing_time: {
    month_start: "2026-01-01T00:00:00+00:00",
    month_label: "Jan 2026",
    decided: 6,
    approved: 5,
    rejected: 1,
    avg_days: 3.5,
    median_days: 3,
    p90_days: 7,
    longest_days: 9,
  },
  rpc_analytics_expiring: {
    record_id: "22222222-2222-2222-2222-222222222222",
    franchise_number: "MAB-TR-2026-000001",
    operator_name: "Sample Operator",
    toda_name: "TODA Anilao Proper",
    expires_at: "2026-03-01T00:00:00+00:00",
    days_remaining: 52,
    bucket: "31-60 days",
  },
  rpc_analytics_document_compliance: {
    document_type: "or_cr",
    total: 42,
    verified: 30,
    pending: 8,
    rejected: 4,
    verified_rate: 71.43,
    oldest_pending_days: 12,
  },
  rpc_analytics_prescriptive: {
    indicator_key: "pending_backlog",
    severity: "attention",
    category: "processing",
    finding: "8 documents have been pending for more than 10 days.",
    recommendation: "Assign a second verifier to the oldest pending documents.",
    data_basis: "franchise_documents, last 30 days, 42 rows",
    metric_value: 8,
    threshold_value: 5,
  },
  rpc_analytics_system_health: {
    users_total: 90,
    users_administrators: 2,
    users_staff: 4,
    users_drivers: 84,
    users_inactive: 1,
    activity_logs_7d: 210,
    ai_requests_30d: 12,
    ai_requests_failed_30d: 0,
    certificates_issued: 30,
    document_objects: 168,
    certificate_objects: 30,
    last_activity_at: "2026-01-05T09:12:00+00:00",
  },
  rpc_verify_certificate: {
    verification_status: "valid",
    franchise_number: "MAB-TR-2026-000001",
    operator_display_name: "S***** O******",
    toda_name: "TODA Anilao Proper",
    issued_at: "2026-01-05T00:00:00+00:00",
    expires_at: "2027-01-05T00:00:00+00:00",
    verified_at: "2026-01-05T10:00:00+00:00",
  },
};

const FRANCHISE_RECORDS = [{ verification_code: "ABCD-EFGH-JKMP" }];

/**
 * @param {{ mode?: "healthy" | "renamed" }} options
 * @returns {(input: string | URL, init?: RequestInit) => Promise<Response>}
 */
export function createMockFetch(options = {}) {
  const mode = options.mode ?? "healthy";

  function rowFor(name) {
    const row = { ...ROWS[name] };
    if (mode === "renamed" && name === "rpc_analytics_overview") {
      // The regression this harness guards: a column renamed in the dashboard
      // leaves the repository untouched and breaks the web console silently.
      delete row.total_applications;
      row.total_apps = 42;
    }
    return row;
  }

  function json(status, body) {
    return new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    });
  }

  return async function mockFetch(input) {
    const url = new URL(typeof input === "string" ? input : input.toString());
    const path = url.pathname;

    if (url.origin !== BASE) {
      return json(404, { message: `unexpected host ${url.origin}` });
    }

    // --- analytics / certificate RPCs --------------------------------------
    const rpc = /^\/rest\/v1\/rpc\/([a-z_0-9]+)$/.exec(path);
    if (rpc) {
      const name = rpc[1];
      if (name in ROWS) return json(200, [rowFor(name)]);
      return json(404, {
        code: "PGRST202",
        message: `Could not find the function public.${name} in the schema cache`,
      });
    }

    // --- table reads --------------------------------------------------------
    if (path === "/rest/v1/franchise_records") {
      return json(200, FRANCHISE_RECORDS);
    }

    // --- private storage must refuse anonymous downloads --------------------
    if (/^\/storage\/v1\/object\//.test(path)) {
      return json(403, { statusCode: "403", error: "Unauthorized", message: "Access denied" });
    }

    return json(404, { code: "PGRST205", message: `Unhandled mock route ${path}` });
  };
}

export const MOCK_URL = BASE;
export const MOCK_KEY = "mock-publishable-key-0000000000000000";
