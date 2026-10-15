// ===========================================================================
// Edge Function: password-recovery
//
// Unauthenticated, and deliberately so: it backs the "Forgot your password?"
// screen, which is used before anyone has a session.
//
// It exists because recovery is role-specific, and a role can only be read with
// the service role — the web app has no service-role key, and RLS blocks an
// anonymous caller from reading another user's profile:
//
//   administrator     → a recovery link is e-mailed (set a new password)
//   staff (approved)  → a recovery link is e-mailed
//   staff (pending)   → nothing is sent; an administrator must approve first
//   driver / operator → nothing is sent; they use a one-time password in the
//                       mobile application instead
//
// The response is ALWAYS the same generic confirmation, whatever the account's
// role, status, or existence. That is intentional: it stops the endpoint from
// being used to enumerate which addresses have accounts, and it is why the web
// screen says only that the request was accepted.
// ===========================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, errorResponse, json } from "../_shared/http.ts";

const SITE_URL = Deno.env.get("SITE_URL") ?? "http://localhost:3000";

const GENERIC_MESSAGE =
  "If an account exists for that address, recovery instructions have been sent. " +
  "Drivers and operators set access through the one-time password option in the SBTF mobile app.";

Deno.serve(async (request: Request) => {
  const origin = request.headers.get("origin");

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (request.method !== "POST") {
    return errorResponse("method_not_allowed", "Use POST.", 405, origin);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return errorResponse("misconfigured", "Supabase environment variables are missing.", 500, origin);
  }

  const payload = await request.json().catch(() => ({}));
  const email = String(payload?.email ?? "").trim().toLowerCase();

  if (!/^[^@\s]+@[^@\s.]+\.[^@\s]+$/.test(email)) {
    return errorResponse("invalid_email", "A valid e-mail address is required.", 400, origin);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const anonClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false },
  });

  // E-mails are stored lower-cased by every writer in the system.
  const { data: profile } = await adminClient
    .from("profiles")
    .select("role, account_status")
    .eq("email", email)
    .maybeSingle();

  const mayReceiveLink =
    profile !== null &&
    (profile.role === "administrator" ||
      (profile.role === "staff" && profile.account_status === "active"));

  if (mayReceiveLink) {
    // Fire and forget: delivery is Supabase's mailer, and any failure (rate
    // limit, missing SMTP) must still answer with the same generic confirmation
    // so the response cannot be used to probe the account.
    await anonClient.auth
      .resetPasswordForEmail(email, { redirectTo: `${SITE_URL}/auth/confirm` })
      .catch(() => undefined);
  }

  return json({ ok: true, message: GENERIC_MESSAGE }, 200, origin);
});
