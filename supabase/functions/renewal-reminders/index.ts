// ===========================================================================
// Edge Function: renewal-reminders
//
// Scheduled server-side routine that notifies operators whose franchise is
// approaching expiry (90 / 60 / 30 days by default). It is an alternative to
// the pg_cron schedule created by the migration
// 20260101091200_phase0_scheduled_jobs.sql — both call exactly the same
// database routine, and both are idempotent.
//
// Security:
//   * no JWT is required (verify_jwt = false) because the scheduler has none;
//   * the caller must present the shared secret configured as
//     REMINDER_CRON_SECRET, compared in constant time;
//   * the database function is revoked from anon/authenticated and only the
//     service role may execute it;
//   * the routine only READS franchise records and only INSERTS notifications:
//     it never approves, renews, expires or modifies any record.
// ===========================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, errorResponse, json } from "../_shared/http.ts";

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let mismatch = 0;
  for (let index = 0; index < a.length; index++) {
    mismatch |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return mismatch === 0;
}

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405, origin);
  }

  const expectedSecret = Deno.env.get("REMINDER_CRON_SECRET");
  const providedSecret =
    request.headers.get("x-sbtf-cron-secret") ??
    (request.headers.get("Authorization")?.replace(/^Bearer\s+/i, "") ?? "");

  if (!expectedSecret) {
    return errorResponse("misconfigured", "REMINDER_CRON_SECRET is not configured.", 500, origin);
  }
  if (!providedSecret || !timingSafeEqual(expectedSecret, providedSecret)) {
    return errorResponse("forbidden", "A valid scheduler secret is required.", 403, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse("misconfigured", "Supabase environment variables are missing.", 500, origin);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  // Reminder windows are configurable through system settings.
  const { data: setting } = await adminClient
    .from("system_settings")
    .select("value")
    .eq("key", "renewal_reminder_days")
    .maybeSingle();

  const windows: number[] = Array.isArray(setting?.value)
    ? (setting!.value as number[]).map(Number).filter((value) => Number.isFinite(value) && value > 0)
    : [90, 60, 30];

  const { data, error } = await adminClient.rpc("rpc_generate_renewal_reminders", {
    p_days: windows.length > 0 ? windows : [90, 60, 30],
  });

  if (error) {
    console.error("Renewal reminder run failed", error);
    return errorResponse("reminder_failed", error.message, 500, origin);
  }

  const summary = Array.isArray(data) ? data[0] : data;

  return json(
    {
      ok: true,
      windows_applied: windows,
      records_evaluated: summary?.records_evaluated ?? 0,
      reminders_created: summary?.reminders_created ?? 0,
      ran_at: new Date().toISOString(),
      note: "Notifications created only. No franchise record was modified.",
    },
    200,
    origin,
  );
});
