// ===========================================================================
// Edge Function: admin-users
//
// The only place where Supabase Auth administrative operations happen, because
// they require the service-role key:
//
//   create_staff      → create a staff account (or another administrator)
//   deactivate        → ban the account in Supabase Auth + mark the profile
//   activate          → lift the ban + reactivate the profile
//   send_password_reset → issue a recovery link for an account
//
// The caller must be an ACTIVE ADMINISTRATOR. This is verified twice: once with
// the caller's own JWT against the RLS-protected profiles table, and again
// inside the database RPCs, which independently require is_admin().
// ===========================================================================

import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders, errorResponse, json } from "../_shared/http.ts";

type Action = "create_staff" | "deactivate" | "activate" | "send_password_reset";

const ALLOWED_ROLES = ["administrator", "staff"] as const;

/**
 * Where Supabase Auth sends the holder after they follow a recovery link.
 *
 * Set SITE_URL as a function secret (`supabase secrets set SITE_URL=https://…`).
 * It falls back to localhost so local development still produces a usable, if
 * unusable-outside-the-machine, link.
 */
const SITE_URL = Deno.env.get("SITE_URL") ?? "http://localhost:3000";

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

  const authHeader = request.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return errorResponse("unauthorised", "A bearer token is required.", 401, origin);
  }

  // --- 1. Caller must be an active administrator ----------------------------
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: callerData, error: callerError } = await callerClient.auth.getUser();
  if (callerError || !callerData?.user) {
    return errorResponse("unauthorised", "The session is not valid.", 401, origin);
  }

  const { data: callerProfile } = await callerClient
    .from("profiles")
    .select("id, role, account_status")
    .eq("auth_user_id", callerData.user.id)
    .maybeSingle();

  if (
    !callerProfile ||
    callerProfile.role !== "administrator" ||
    callerProfile.account_status !== "active"
  ) {
    return errorResponse("forbidden", "Administrator access is required.", 403, origin);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const payload = await request.json().catch(() => ({}));
  const action = payload?.action as Action;

  // -------------------------------------------------------------------------
  // create_staff
  // -------------------------------------------------------------------------
  if (action === "create_staff") {
    const email = String(payload.email ?? "").trim().toLowerCase();
    const role = String(payload.role ?? "staff") as (typeof ALLOWED_ROLES)[number];
    const firstName = String(payload.first_name ?? "").trim();
    const lastName = String(payload.last_name ?? "").trim();
    const contactNumber = String(payload.contact_number ?? "").trim();

    if (!/^[^@\s]+@[^@\s.]+\.[^@\s]+$/.test(email)) {
      return errorResponse("invalid_email", "A valid e-mail address is required.", 400, origin);
    }
    if (!ALLOWED_ROLES.includes(role)) {
      return errorResponse(
        "invalid_role",
        "Only the staff and administrator roles can be created here.",
        400,
        origin,
      );
    }
    if (firstName.length < 1 || lastName.length < 1) {
      return errorResponse("invalid_name", "First and last name are required.", 400, origin);
    }

    const { data: created, error: createError } = await adminClient.auth.admin.createUser({
      email,
      email_confirm: true,
      // raw_app_meta_data is written only here (service role). The database
      // trigger reads the role from app_metadata, so a client can never
      // self-register an elevated role by supplying user metadata.
      app_metadata: { role, provider: "email", providers: ["email"] },
      user_metadata: {
        first_name: firstName,
        last_name: lastName,
        contact_number: contactNumber,
        account_origin: "admin_users_function",
      },
    });

    if (createError || !created?.user) {
      return errorResponse(
        "creation_failed",
        createError?.message ?? "The account could not be created.",
        400,
        origin,
      );
    }

    await adminClient.from("activity_logs").insert({
      user_id: callerProfile.id,
      action: "user_created",
      target_type: "profile",
      target_id: created.user.id,
      metadata: { email, role, created_by: "admin-users edge function" },
    });

    // Build the password-setup link and hand it back to the console.
    //
    // generateLink only *creates* the link — it does not send anything. The
    // delivery would be left to Supabase's built-in mailer, which on a project
    // without SMTP is rate-limited and often only delivers to addresses already
    // on the project team, so an invitation to a real municipal address silently
    // never arrives. Rather than claim an e-mail was sent, the link is returned
    // and the administrator passes it on through whatever channel the office
    // actually uses.
    const { data: link, error: linkError } = await adminClient.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo: `${SITE_URL}/reset-password` },
    });

    const setupLink: string | null = link?.properties?.action_link ?? null;

    return json(
      {
        ok: true,
        user_id: created.user.id,
        email,
        role,
        setup_link: setupLink,
        message: setupLink
          ? "Account created. No e-mail is sent automatically — copy the setup link below and send it to the new user yourself. The link is single-use and expires; the account cannot sign in until the password is set through it."
          : "Account created, but no setup link could be generated" +
            (linkError ? ` (${linkError.message}).` : ".") +
            " Tell the new user to use “Forgot your password?” on the sign-in page: Supabase Auth will issue the recovery link directly to them.",
      },
      201,
      origin,
    );
  }

  // -------------------------------------------------------------------------
  // deactivate / activate
  // -------------------------------------------------------------------------
  if (action === "deactivate" || action === "activate") {
    const profileId = String(payload.profile_id ?? "");
    const reason = String(payload.reason ?? "").trim();

    if (!/^[0-9a-f-]{36}$/i.test(profileId)) {
      return errorResponse("invalid_profile", "A valid profile id is required.", 400, origin);
    }
    if (action === "deactivate" && reason.length < 5) {
      return errorResponse("reason_required", "A reason is required when deactivating an account.", 400, origin);
    }

    // The database re-validates the administrator role and protects the last
    // active administrator account.
    const { data: updated, error: rpcError } = await callerClient.rpc(
      "rpc_admin_set_account_status",
      {
        p_profile_id: profileId,
        p_status: action === "deactivate" ? "inactive" : "active",
        p_reason: action === "deactivate" ? reason : null,
      },
    );

    if (rpcError) {
      return errorResponse("update_failed", rpcError.message, 400, origin);
    }

    const { data: target } = await adminClient
      .from("profiles")
      .select("auth_user_id, email, role")
      .eq("id", profileId)
      .maybeSingle();

    if (target?.auth_user_id) {
      // Ban the account in Supabase Auth as well, so existing refresh tokens
      // stop working immediately (the ~1 hour access token is still rejected by
      // RLS because current_profile_id() only resolves active profiles).
      await adminClient.auth.admin.updateUserById(target.auth_user_id, {
        ban_duration: action === "deactivate" ? "876000h" : "none",
      });
    }

    return json({ ok: true, profile: updated }, 200, origin);
  }

  // -------------------------------------------------------------------------
  // send_password_reset
  // -------------------------------------------------------------------------
  if (action === "send_password_reset") {
    const email = String(payload.email ?? "").trim().toLowerCase();
    if (!email) {
      return errorResponse("invalid_email", "An e-mail address is required.", 400, origin);
    }

    // Same contract as create_staff: the link is returned, not e-mailed. See the
    // comment there for why.
    const { data, error } = await adminClient.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo: `${SITE_URL}/reset-password` },
    });

    const resetLink: string | null = data?.properties?.action_link ?? null;

    return json(
      {
        ok: true,
        email,
        reset_link: resetLink,
        message: resetLink
          ? "A new password reset link has been created. No e-mail is sent automatically — copy it and pass it to the account holder yourself. It is single-use and the previous link stops working once this one is used."
          : "No reset link could be generated" +
            (error ? ` (${error.message}).` : ".") +
            " Tell the account holder to use “Forgot your password?” on the sign-in page instead.",
      },
      200,
      origin,
    );
  }

  return errorResponse(
    "unknown_action",
    "Supported actions: create_staff, deactivate, activate, send_password_reset.",
    400,
    origin,
  );
});
