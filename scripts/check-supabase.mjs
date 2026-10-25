#!/usr/bin/env node
/**
 * Read-only diagnosis of a live Supabase project (8 steps).
 *
 *   npm run db:check
 *
 * The check walks the chain from the outside in and stops at the first broken
 * link, because every later step is meaningless without the earlier one:
 *
 *   1. environment         — is the app pointed at a real project at all?
 *   2. reachability        — does the project answer on the network?
 *   3. key acceptance      — does the project accept the configured key?
 *   4. tables              - are all 19 tables present in the live schema?
 *   5. functions           — are all 35 public RPCs present?
 *   6. buckets             — are the two private storage buckets present?
 *   7. sign-in (optional)  — does a real account authenticate end to end?
 *   8. RLS probe           — does the anon key get NO rows from protected tables?
 *
 * Everything is read-only and uses the publishable key only. Secrets are never
 * printed: only the last four characters of the key appear in the output.
 *
 * Step 7 runs only when SBTF_CHECK_EMAIL and SBTF_CHECK_PASSWORD are set, so
 * the check is safe to run in CI.
 */
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const ENV_FILE = join(ROOT, "apps", "web", ".env.local");
const MIGRATIONS_DIR = join(ROOT, "supabase", "migrations");

const TIMEOUT_MS = 15_000;

// The 19 tables the migrations create. Kept as an explicit list (rather than
// scraped from the migrations) so a renamed table shows up as a mismatch the
// reader has to resolve, not as a silently-moving target.
const TABLES = [
  "activity_logs",
  "ai_briefings",
  "ai_request_logs",
  "application_status_history",
  "barangays",
  "franchise_applications",
  "franchise_documents",
  "franchise_records",
  "franchise_number_sequences",
  "form_requests",
  "application_appointments",
  "document_releases",
  "notifications",
  "profiles",
  "renewal_reminders_sent",
  "roles",
  "system_settings",
  "toda_members",
  "todas",
];

// The 35 functions that make up the documented public API surface.
const RPCS = [
  "rpc_log_activity",
  "rpc_driver_submit_application",
  "rpc_driver_replace_document",
  "rpc_driver_request_form",
  "rpc_driver_cancel_form_request",
  "rpc_staff_start_review",
  "rpc_staff_verify_document",
  "rpc_staff_approve_application",
  "rpc_staff_reject_application",
  "rpc_staff_assign_application",
  "rpc_staff_request_compliance",
  "rpc_staff_mark_verified",
  "rpc_staff_record_application",
  "rpc_staff_record_endorsement",
  "rpc_staff_record_decision",
  "rpc_staff_release_document",
  "rpc_staff_complete_application",
  "rpc_staff_schedule_appointment",
  "rpc_staff_update_appointment",
  "rpc_staff_issue_form_request",
  "rpc_staff_convert_form_request",
  "rpc_staff_attach_certificate",
  "rpc_staff_archive_franchise_record",
  "rpc_admin_set_user_role",
  "rpc_admin_set_account_status",
  "rpc_analytics_overview",
  "rpc_analytics_application_trends",
  "rpc_analytics_by_toda",
  "rpc_analytics_processing_time",
  "rpc_analytics_expiring",
  "rpc_analytics_document_compliance",
  "rpc_analytics_prescriptive",
  "rpc_analytics_ai_context",
  "rpc_analytics_system_health",
  "rpc_verify_certificate",
];

const BUCKETS = ["franchise-documents", "certificates"];

let failures = 0;

const ok = (message) => console.log(`  ✓ ${message}`);
const info = (message) => console.log(`  · ${message}`);
const bad = (message) => {
  failures++;
  console.error(`  ✗ ${message}`);
};
const step = (number, title) => console.log(`\n${number}. ${title}`);

/** Only the tail of a secret is ever printed. */
function suffix(value) {
  if (!value) return "(empty)";
  return value.length <= 8 ? "(too short)" : `…${value.slice(-4)}`;
}

function readEnvFile() {
  const env = {};
  for (const raw of readFileSync(ENV_FILE, "utf8").split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    env[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
  }
  return env;
}

console.log("SBTF Supabase diagnosis — read-only, 8 steps\n");

/* -------------------------------------------------------------------------- */
/* 1. Environment                                                              */
/* -------------------------------------------------------------------------- */
step(1, "Environment");

let fileEnv = {};
try {
  fileEnv = readEnvFile();
  ok(`environment read from apps/web/.env.local`);
} catch {
  info("apps/web/.env.local not found — falling back to the process environment");
}

const env = { ...fileEnv, ...process.env };

if (env.NEXT_PUBLIC_DEMO_MODE === "true") {
  bad(
    "NEXT_PUBLIC_DEMO_MODE=true — the app is serving bundled sample data, not this database. " +
      "Set it to false before diagnosing a project.",
  );
  process.exit(1);
}

const url = (env.NEXT_PUBLIC_SUPABASE_URL ?? "").replace(/\/$/, "");
const key =
  env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
  env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  "";

if (!url.startsWith("https://") || url.includes("your-project-ref")) {
  bad("NEXT_PUBLIC_SUPABASE_URL is not a real project URL");
  process.exit(1);
}
if (key.length <= 20) {
  bad("NEXT_PUBLIC_SUPABASE_ANON_KEY is missing or too short");
  process.exit(1);
}

const projectRef = url.replace(/^https?:\/\//, "").split(".")[0];
ok(`project ${projectRef} — key ${suffix(key)}`);

const headers = {
  apikey: key,
  Authorization: `Bearer ${key}`,
  "Content-Type": "application/json",
};

async function call(pathname, init = {}) {
  return fetch(`${url}${pathname}`, {
    ...init,
    headers: { ...headers, ...(init.headers ?? {}) },
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
}

/* -------------------------------------------------------------------------- */
/* 2. Reachability                                                             */
/* -------------------------------------------------------------------------- */
step(2, "Reachability");

try {
  const res = await call("/auth/v1/health");
  if (!res.ok) {
    bad(`the auth service answered ${res.status} ${res.statusText}`);
    process.exit(1);
  }
  const body = await res.json().catch(() => ({}));
  ok(`auth service reachable${body.version ? ` (GoTrue ${body.version})` : ""}`);
} catch (error) {
  bad(`the project is unreachable: ${error.message}`);
  process.exit(1);
}

/* -------------------------------------------------------------------------- */
/* 3. Key acceptance                                                           */
/* -------------------------------------------------------------------------- */
step(3, "Key acceptance");

try {
  const res = await call("/rest/v1/barangays?select=code&limit=1");
  if (res.status === 401 || res.status === 403) {
    const body = await res.text();
    bad(
      `the project rejected the key (${res.status}). ${body.slice(0, 160)} ` +
        `— re-copy the publishable key from Dashboard → Project Settings → API.`,
    );
    process.exit(1);
  }
  if (!res.ok) {
    bad(`unexpected response from the data API: ${res.status} ${res.statusText}`);
    process.exit(1);
  }
  ok("the data API accepts the publishable key");
} catch (error) {
  bad(`the data API could not be reached: ${error.message}`);
  process.exit(1);
}

/* -------------------------------------------------------------------------- */
/* 4. Tables                                                                   */
/* -------------------------------------------------------------------------- */
step(4, `Tables (${TABLES.length} expected)`);

let missingTables = 0;
let rlsBlocked = 0;

for (const table of TABLES) {
  let res;
  try {
    res = await call(`/rest/v1/${table}?select=*&limit=1`, { headers: { Accept: "application/json" } });
  } catch (error) {
    bad(`${table.padEnd(28)} ${error.message}`);
    missingTables++;
    continue;
  }

  if (res.ok) {
    const rows = await res.json();
    ok(`${table.padEnd(28)} present — anon reads ${rows.length} row(s)`);
    if (rows.length > 0 && table !== "barangays" && table !== "roles" && table !== "todas") {
      bad(`${table.padEnd(28)} leaks ${rows.length} row(s) to the anon key — check RLS`);
    }
    continue;
  }

  const body = await res.text();
  if (res.status === 401 || res.status === 403) {
    rlsBlocked++;
    ok(`${table.padEnd(28)} present — RLS blocks the anon role (expected)`);
    continue;
  }
  if (body.includes("PGRST205") || res.status === 404) {
    missingTables++;
    bad(`${table.padEnd(28)} MISSING — the migrations are not applied`);
    continue;
  }
  bad(`${table.padEnd(28)} HTTP ${res.status}: ${body.slice(0, 120)}`);
  missingTables++;
}

if (missingTables > 0) {
  const onDisk = readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith(".sql")).length;
  console.error(
    `\n  ${missingTables} table(s) missing while ${onDisk} migration file(s) exist on disk.\n` +
      `  Apply supabase/migrations (see docs/deployment.md §2) and re-run this check.`,
  );
  process.exit(1);
}
if (rlsBlocked > 0) info(`${rlsBlocked} table(s) shielded by RLS from the anon role`);

/* -------------------------------------------------------------------------- */
/* 5. Functions                                                                */
/* -------------------------------------------------------------------------- */
step(5, `Functions (${RPCS.length} expected)`);

let missingRpc = 0;

// PostgREST resolves a function by its argument names, so a call with an empty
// body reports PGRST202 for every function that has *required* parameters —
// even when the function exists. Probe those with all required arguments, using
// values that cannot mutate anything (zero UUIDs, invalid enums, an empty
// payload). Functions the anon role may not execute then answer 42501, which
// still proves the function is present.
const PROBE_UUID = "00000000-0000-0000-0000-000000000000";
const PROBE_TEXT = "SBTF diagnostic probe";
const PROBE_ENUM = "sbtf_probe"; // invalid for every enum used here

const RPC_PROBES = {
  rpc_log_activity: { p_action: PROBE_ENUM },
  rpc_driver_submit_application: { p_payload: {} },
  rpc_driver_replace_document: { p_document_id: PROBE_UUID, p_storage_path: PROBE_TEXT },
  rpc_driver_request_form: { p_payload: {} },
  rpc_driver_cancel_form_request: { p_form_request_id: PROBE_UUID },
  rpc_staff_start_review: { p_application_id: PROBE_UUID },
  rpc_staff_verify_document: { p_document_id: PROBE_UUID, p_status: PROBE_ENUM },
  rpc_staff_approve_application: { p_application_id: PROBE_UUID },
  rpc_staff_reject_application: { p_application_id: PROBE_UUID, p_reason: PROBE_TEXT },
  rpc_staff_assign_application: { p_application_id: PROBE_UUID, p_staff_id: PROBE_UUID },
  rpc_staff_request_compliance: { p_application_id: PROBE_UUID, p_reason: PROBE_TEXT },
  rpc_staff_mark_verified: { p_application_id: PROBE_UUID },
  rpc_staff_record_application: { p_application_id: PROBE_UUID },
  rpc_staff_record_endorsement: { p_application_id: PROBE_UUID, p_endorsed_to: PROBE_TEXT },
  rpc_staff_record_decision: { p_application_id: PROBE_UUID, p_decision: PROBE_ENUM },
  rpc_staff_release_document: { p_application_id: PROBE_UUID, p_received_by_name: PROBE_TEXT },
  rpc_staff_complete_application: { p_application_id: PROBE_UUID },
  rpc_staff_schedule_appointment: {
    p_application_id: PROBE_UUID,
    p_kind: PROBE_ENUM,
    p_scheduled_at: "1970-01-01T00:00:00Z",
    p_venue: PROBE_TEXT,
  },
  rpc_staff_update_appointment: { p_appointment_id: PROBE_UUID, p_status: PROBE_ENUM },
  rpc_staff_issue_form_request: { p_form_request_id: PROBE_UUID },
  rpc_staff_convert_form_request: {
    p_form_request_id: PROBE_UUID,
    p_application_id: PROBE_UUID,
  },
  rpc_staff_attach_certificate: { p_record_id: PROBE_UUID, p_storage_path: PROBE_TEXT },
  rpc_staff_archive_franchise_record: { p_record_id: PROBE_UUID, p_reason: PROBE_TEXT },
  rpc_admin_set_user_role: { p_profile_id: PROBE_UUID, p_role: PROBE_ENUM },
  rpc_admin_set_account_status: { p_profile_id: PROBE_UUID, p_status: PROBE_ENUM },
  rpc_verify_certificate: { p_code: "SBTF-DIAGNOSTIC-PROBE" },
};

for (const rpc of RPCS) {
  let res;
  let body = "";
  try {
    // A missing function reports PGRST202 even with the correct argument names;
    // a present one answers with a permission, validation or result response.
    res = await call(`/rest/v1/rpc/${rpc}`, {
      method: "POST",
      body: JSON.stringify(RPC_PROBES[rpc] ?? {}),
    });
    body = await res.text();
  } catch (error) {
    bad(`${rpc.padEnd(38)} ${error.message}`);
    missingRpc++;
    continue;
  }

  if (body.includes("PGRST202")) {
    missingRpc++;
    bad(`${rpc.padEnd(38)} MISSING — not in the PostgREST schema cache`);
    continue;
  }
  ok(`${rpc.padEnd(38)} present`);
}

if (missingRpc > 0) {
  console.error(
    `\n  ${missingRpc} function(s) missing. Either the migrations are not fully applied or\n` +
      `  PostgREST has not reloaded its schema cache (Dashboard → Database → "Reload schema cache").`,
  );
  process.exit(1);
}

/* -------------------------------------------------------------------------- */
/* 6. Storage buckets                                                          */
/* -------------------------------------------------------------------------- */
step(6, `Storage buckets (${BUCKETS.length} expected)`);

try {
  const res = await call("/storage/v1/bucket");
  if (res.ok) {
    const buckets = await res.json();
    const names = new Set(buckets.map((bucket) => bucket.name));
    if (names.size === 0) {
      // Storage hides private buckets from the publishable key: an empty list is
      // not evidence that the buckets are missing, so this cannot be asserted
      // from the anon role. Confirm them in Dashboard → Storage instead.
      info(
        "no bucket is visible to the publishable key — private buckets are hidden by design; " +
          "confirm franchise-documents and certificates in Dashboard → Storage",
      );
    }
    for (const name of BUCKETS) {
      if (names.size === 0) break;
      if (names.has(name)) {
        const bucket = buckets.find((candidate) => candidate.name === name);
        ok(`${name.padEnd(28)} present${bucket?.public ? " (PUBLIC — should be private)" : " (private)"}`);
        if (bucket?.public) bad(`${name.padEnd(28)} is public; both buckets must stay private`);
      } else {
        bad(`${name.padEnd(28)} MISSING`);
      }
    }
  } else {
    // Listing buckets is an authenticated operation on most projects; a 400 here
    // is expected with the publishable key and is not treated as a failure.
    info(
      `bucket listing refused with the publishable key (HTTP ${res.status}) — ` +
        `this is expected; confirm the buckets in Dashboard → Storage.`,
    );
  }
} catch (error) {
  info(`bucket listing unavailable: ${error.message}`);
}

/* -------------------------------------------------------------------------- */
/* 7. Optional sign-in                                                         */
/* -------------------------------------------------------------------------- */
step(7, "Sign-in (optional)");

const email = env.SBTF_CHECK_EMAIL;
const password = env.SBTF_CHECK_PASSWORD;

if (!email || !password) {
  info("skipped — set SBTF_CHECK_EMAIL and SBTF_CHECK_PASSWORD to exercise a real sign-in");
} else {
  try {
    const res = await call("/auth/v1/token?grant_type=password", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    });
    if (res.ok) {
      const session = await res.json();
      ok(`sign-in succeeded for ${email} (token ${suffix(session.access_token ?? "")})`);

      const profileRes = await call("/rest/v1/profiles?select=role,account_status&limit=1", {
        headers: { Authorization: `Bearer ${session.access_token}` },
      });
      if (profileRes.ok) {
        const rows = await profileRes.json();
        ok(`the session reads its own profile: ${JSON.stringify(rows[0] ?? null)}`);
      } else {
        bad(`the signed-in session could not read its own profile (HTTP ${profileRes.status})`);
      }
    } else {
      const body = await res.text();
      bad(`sign-in failed for ${email}: HTTP ${res.status} ${body.slice(0, 160)}`);
    }
  } catch (error) {
    bad(`sign-in could not be attempted: ${error.message}`);
  }
}

/* -------------------------------------------------------------------------- */
/* 8. RLS probe                                                                */
/* -------------------------------------------------------------------------- */
step(8, "RLS probe (anon key must see nothing)");

for (const table of ["profiles", "franchise_applications", "franchise_documents", "franchise_records"]) {
  try {
    const res = await call(`/rest/v1/${table}?select=*&limit=5`);
    if (res.status === 401 || res.status === 403) {
      ok(`${table.padEnd(28)} refused to the anon role`);
      continue;
    }
    if (res.ok) {
      const rows = await res.json();
      if (rows.length === 0) {
        ok(`${table.padEnd(28)} reachable but empty for the anon role`);
      } else {
        bad(`${table.padEnd(28)} returned ${rows.length} row(s) to the anon key — RLS is not enforced`);
      }
      continue;
    }
    ok(`${table.padEnd(28)} HTTP ${res.status} (no rows returned)`);
  } catch (error) {
    bad(`${table.padEnd(28)} ${error.message}`);
  }
}

/* -------------------------------------------------------------------------- */
console.log("");
if (failures === 0) {
  console.log("No problems found. The project is reachable, migrated and locked down.\n");
} else {
  console.log(`${failures} problem(s) found.\n`);
}
process.exit(failures > 0 ? 1 : 0);
