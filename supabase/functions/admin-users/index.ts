// ===========================================================================
// Edge Function: admin-users
//
// The only place where Supabase Auth administrative operations happen, because
// they require the service-role key:
//
//   create_staff      → create a staff account and e-mail the invitation
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
 * The two statuses the console can choose when deactivating an account. Both
 * stop the profile from resolving under RLS; the distinction is administrative
 * (a suspension is usually temporary, an inactive account is not).
 */
const DEACTIVATION_STATUSES = ["inactive", "suspended"] as const;
type DeactivationStatus = (typeof DEACTIVATION_STATUSES)[number];

/**
 * The public web origin used for Auth redirects.
 *
 * Set SITE_URL as a function secret (`supabase secrets set SITE_URL=https://…`).
 * It falls back to localhost so local development still produces a usable, if
 * unusable-outside-the-machine, link.
 */
const SITE_URL = Deno.env.get("SITE_URL") ?? "http://localhost:3000";

/**
 * Builds the link the web app verifies at /auth/confirm.
 *
 * Supabase's own `action_link` points at GoTrue's verify endpoint and hands the
 * caller a session in the URL fragment; the web app could not consume that.
 * Instead the raw single-use `hashed_token` is embedded in our own route, which
 * calls `verifyOtp` server-side. This keeps Supabase's expiring, single-use
 * token while giving us a link that actually resolves.
 */
function confirmLink(hashedToken: string | null | undefined, type: "recovery" | "invite"): string | null {
  if (!hashedToken) return null;
  return `${SITE_URL}/auth/confirm?token_hash=${encodeURIComponent(hashedToken)}&type=${type}`;
}

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

    // Refuse an address that already has a profile before touching Auth. The
    // unique index on lower(email) means the invitation would fail anyway, and
    // an explicit answer points the administrator at the existing account
    // instead of surfacing GoTrue's "already registered" message.
    const { data: existingProfile, error: existingError } = await adminClient
      .from("profiles")
      .select("id")
      .eq("email", email)
      .maybeSingle();

    if (existingError) {
      return errorResponse("lookup_failed", existingError.message, 500, origin);
    }
    if (existingProfile) {
      return errorResponse(
        "already_registered",
        "An account with this e-mail address already exists. Use “Send password reset” on that account instead of creating a new one.",
        409,
        origin,
      );
    }

    // inviteUserByEmail creates the Auth user AND sends the invitation through
    // the project's SMTP. The custom invite template
    // (supabase/templates/invite.html) builds its link from the token hash and
    // points at /auth/confirm, which routes the recipient to /accept-invitation
    // to choose a password. Do NOT switch this back to generateLink(): that only
    // creates a link and sends nothing, which is why staff invitations used to
    // be copied and handed over by hand.
    const { data: invited, error: inviteError } = await adminClient.auth.admin.inviteUserByEmail(
      email,
      {
        redirectTo: `${SITE_URL}/auth/confirm`,
        data: {
          first_name: firstName,
          last_name: lastName,
          contact_number: contactNumber,
          account_origin: "admin_users_function",
        },
      },
    );

    if (inviteError || !invited?.user) {
      const alreadyRegistered = /already|registered|exists/i.test(inviteError?.message ?? "");

      // A failed *send* can leave the Auth user behind on some GoTrue versions.
      // The pre-check above proved the address had no profile before this call,
      // so anything created by this request is safe to remove. Never do this for
      // a duplicate-address error: that account belongs to somebody else.
      if (!alreadyRegistered) {
        const { data: orphan } = await adminClient
          .from("profiles")
          .select("id, auth_user_id")
          .eq("email", email)
          .maybeSingle();

        if (orphan?.auth_user_id) {
          await adminClient.from("profiles").delete().eq("id", orphan.id);
          await adminClient.auth.admin.deleteUser(orphan.auth_user_id);
        }
      }

      return errorResponse(
        "invite_failed",
        alreadyRegistered
          ? "An account with this e-mail address already exists. Use “Send password reset” on that account instead."
          : (inviteError?.message ?? "The invitation e-mail could not be sent."),
        400,
        origin,
      );
    }

    // The Admin invite API does not accept app_metadata, so the role is written
    // after the user exists. The profile update below is what the web app
    // authorises on; this keeps Auth metadata consistent for the sign-up trigger
    // and for support tooling.
    const { error: metadataError } = await adminClient.auth.admin.updateUserById(
      invited.user.id,
      { app_metadata: { role, provider: "email", providers: ["email"] } },
    );
    if (metadataError) {
      console.error("admin-users: could not write app_metadata.role", metadataError.message);
    }

    // The profiles trigger creates new rows as `active` and falls back to
    // `driver` when it cannot read the role from app_metadata. Write the full
    // record here so an administrator-created account is always Staff, and start
    // it as `pending`; approval runs through rpc_admin_set_account_status from
    // the Users screen.
    //
    // If this update fails, the Auth user is rolled back. Leaving it behind would
    // make every retry fail with "already registered" while no usable account
    // exists — the exact half-created state this function must avoid.
    const { data: profile, error: profileError } = await adminClient
      .from("profiles")
      .update({
        role,
        first_name: firstName,
        last_name: lastName,
        email,
        contact_number: contactNumber || null,
        account_status: "pending",
        status_reason: "Invited by an administrator; awaiting approval.",
      })
      .eq("auth_user_id", invited.user.id)
      .select("id, role")
      .maybeSingle();

    if (profileError || !profile || profile.role !== role) {
      await adminClient.from("profiles").delete().eq("auth_user_id", invited.user.id);
      await adminClient.auth.admin.deleteUser(invited.user.id);

      const detail = profileError?.message ?? "The profile row was not created.";
      const hint = /pending|account_status/i.test(detail)
        ? " Apply supabase/migrations/20260101091400_pending_account_status.sql and redeploy this function."
        : " Check that the auth-user trigger is installed, then redeploy this function.";

      return errorResponse(
        "profile_setup_failed",
        detail + hint + " The invitation e-mail may already have been sent; its link is now invalid.",
        500,
        origin,
      );
    }

    const { error: logError } = await adminClient.from("activity_logs").insert({
      user_id: callerProfile.id,
      action: "user_created",
      target_type: "profile",
      target_id: profile.id,
      metadata: {
        email,
        role,
        account_status: "pending",
        invited: true,
        created_by: "admin-users edge function",
      },
    });

    if (logError) {
      console.error("admin-users: could not write the activity log", logError.message);
    }

    return json(
      {
        ok: true,
        user_id: invited.user.id,
        email,
        role,
        invited: true,
        message:
          `Account created and an invitation e-mail was sent to ${email}. ` +
          "The account is awaiting approval — approve it from the Users screen before the new staff member tries to use the console. " +
          "The invitation takes them to a page where they choose a password, then to the sign-in screen.",
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
    // Older callers did not send a status. Keep them working by defaulting to
    // `inactive`, but honour `suspended` when the console supplies it.
    const requestedStatus = String(payload.status ?? "inactive").trim().toLowerCase();

    if (!/^[0-9a-f-]{36}$/i.test(profileId)) {
      return errorResponse("invalid_profile", "A valid profile id is required.", 400, origin);
    }
    if (
      action === "deactivate" &&
      !DEACTIVATION_STATUSES.includes(requestedStatus as DeactivationStatus)
    ) {
      return errorResponse(
        "invalid_status",
        "Deactivation status must be either inactive or suspended.",
        400,
        origin,
      );
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
        p_status: action === "deactivate" ? requestedStatus : "active",
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

    // Same contract as create_staff: our own /auth/confirm link is returned, not
    // e-mailed. See the comment there for why.
    const { data, error } = await adminClient.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo: `${SITE_URL}/auth/confirm` },
    });

    const resetLink: string | null = confirmLink(data?.properties?.hashed_token, "recovery");

    return json(
      {
        ok: true,
        email,
        reset_link: resetLink,
        message: resetLink
          ? "A new password reset link has been created. No e-mail is sent automatically — copy it and pass it to the account holder yourself. It is single-use and the previous link stops working once this one is used."
          : "No reset link could be generated" +
            (error ? ` (${error.message}).` : ".") +
            " The account holder can request a new link from “Forgot your password?” if it has already been approved.",
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
