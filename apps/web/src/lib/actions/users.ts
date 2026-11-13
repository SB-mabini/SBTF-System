"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";
import type { AccountStatus, UserRole } from "@/types/database";

export async function setUserRoleAction(input: {
  profileId: string;
  role: UserRole;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_admin_set_user_role", {
    p_profile_id: input.profileId,
    p_role: input.role,
  });

  revalidatePath("/admin/users");
  revalidatePath(`/admin/users/${input.profileId}`);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: `Role updated to ${input.role}. The change is recorded in the activity log.` };
}

export async function setAccountStatusAction(input: {
  profileId: string;
  status: AccountStatus;
  reason?: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (input.status !== "active" && (input.reason ?? "").trim().length < 5) {
    return { ok: false, message: "A reason of at least 5 characters is required." };
  }

  // Account deactivation also needs the Supabase Auth ban, which requires the
  // service-role key — so it runs through the admin-users Edge Function.
  if (input.status !== "active") {
    return deactivateThroughEdgeFunction(input);
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_admin_set_account_status", {
    p_profile_id: input.profileId,
    p_status: "active",
    p_reason: null,
  });

  revalidatePath("/admin/users");
  revalidatePath(`/admin/users/${input.profileId}`);
  return error ? { ok: false, message: error.message } : { ok: true, message: "Account activated." };
}

async function deactivateThroughEdgeFunction(input: {
  profileId: string;
  status: AccountStatus;
  reason?: string;
}): Promise<ActionState> {
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-users", {
    body: {
      action: "deactivate",
      profile_id: input.profileId,
      status: input.status === "suspended" ? "suspended" : "inactive",
      reason: input.reason,
    },
  });

  revalidatePath("/admin/users");
  revalidatePath(`/admin/users/${input.profileId}`);

  if (error) {
    return edgeFunctionFailure(error, "The account could not be deactivated");
  }
  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  return { ok: true, message: "Account deactivated. The session can no longer access any data." };
}

/**
 * Permanently deletes an account: profile, franchise records, documents,
 * notifications and audit-log entries, plus the Supabase Auth user. The
 * Edge Function removes the storage files before the database purge.
 *
 * The function refuses accounts that acted on other people's records; that
 * answer is surfaced verbatim because it is actionable ("deactivate instead").
 */
export async function purgeAccountAction(input: {
  profileId: string;
  reason: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const reason = input.reason.trim();
  if (reason.length < 5) {
    return { ok: false, message: "A reason of at least 5 characters is required." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-users", {
    body: { action: "purge_account", profile_id: input.profileId, reason },
  });

  revalidatePath("/admin/users");
  revalidatePath(`/admin/users/${input.profileId}`);

  if (error) {
    const failure = await readEdgeFunctionFailure(error);
    if (failure.code === "account_has_workflow_history") {
      return { ok: false, message: failure.detail };
    }
    if (failure.code === "storage_cleanup_failed") {
      return { ok: false, message: failure.detail };
    }
    return edgeFunctionFailure(
      error,
      "The account could not be deleted",
      " No data has been removed.",
    );
  }

  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  return {
    ok: true,
    message: data?.message ?? "Account permanently deleted.",
    details: {
      applications: data?.applications,
      records: data?.records,
    },
  };
}

/**
 * `send_password_reset` still hands a recovery link back instead of sending an
 * e-mail, so the action forwards it into `ActionState.details` — the only
 * channel a server action has for returning data alongside the message. Its
 * only caller is the account owner's own reset form in Account settings; the
 * administrator's Users screen no longer offers it.
 *
 * Staff invitations no longer produce a link: `create_staff` sends the message
 * itself. `setup_link` is still read when present so the console keeps working
 * against an older deployed Edge Function during a rollout.
 */
function linkDetails(payload: unknown, keys: string[]): Record<string, unknown> | undefined {
  if (!payload || typeof payload !== "object") return undefined;
  const details: Record<string, unknown> = {};
  for (const key of keys) {
    const value = (payload as Record<string, unknown>)[key];
    if (typeof value === "string" && value.length > 0) details[key] = value;
  }
  return Object.keys(details).length > 0 ? details : undefined;
}

interface EdgeFunctionFailure {
  status?: number;
  code?: string;
  detail: string;
}

/**
 * supabase.functions.invoke wraps every non-2xx answer in a FunctionsHttpError
 * whose `context` is the original Response. The function's own JSON body — the
 * useful part ("already registered", "reason required", "environment missing")
 * — is not in `error.message`, so it has to be read from the response.
 */
async function readEdgeFunctionFailure(error: unknown): Promise<EdgeFunctionFailure> {
  const fallback = error instanceof Error ? error.message : "unknown error";
  const context = (error as { context?: unknown }).context;
  const response = asResponse(context);

  if (!response) {
    return { detail: fallback };
  }

  let body: unknown = null;
  try {
    body = await response.clone().json();
  } catch {
    try {
      body = await response.clone().text();
    } catch {
      body = null;
    }
  }

  if (body && typeof body === "object") {
    const record = body as Record<string, unknown>;
    return {
      status: response.status,
      code: typeof record.error === "string" ? record.error : undefined,
      detail: typeof record.message === "string" ? record.message : fallback,
    };
  }

  return { status: response.status, detail: fallback };
}

/**
 * `instanceof Response` is not reliable across runtimes (the error may be built
 * by a different Response implementation), so fall back to its shape.
 */
function asResponse(value: unknown): Response | null {
  if (typeof Response !== "undefined" && value instanceof Response) return value;
  if (
    value &&
    typeof value === "object" &&
    typeof (value as Response).clone === "function" &&
    typeof (value as Response).status === "number"
  ) {
    return value as Response;
  }
  return null;
}

/**
 * Turns a failed Edge Function call into an actionable message. A 404 is almost
 * always a deployment problem; anything else is reported with the function's
 * own explanation instead of the old catch-all "did not answer" sentence.
 */
async function edgeFunctionFailure(
  error: unknown,
  fallbackAction: string,
  consequence = "",
): Promise<ActionState> {
  const failure = await readEdgeFunctionFailure(error);

  if (failure.status === 404) {
    return {
      ok: false,
      message:
        `${fallbackAction}: the admin-users Edge Function is not deployed on this Supabase project (HTTP 404). ` +
        "Deploy it with `supabase functions deploy admin-users` (add `--use-api` if Docker is unavailable), " +
        `set the SITE_URL secret, then try again.${consequence}`,
    };
  }

  if (failure.status === 401) {
    return {
      ok: false,
      message:
        "The admin-users function rejected the session (HTTP 401). Sign out and sign in again, then retry.",
    };
  }

  if (failure.status === 403) {
    return {
      ok: false,
      message:
        "The admin-users function refused the request (HTTP 403). Only an active administrator can perform this action.",
    };
  }

  return {
    ok: false,
    message:
      `${fallbackAction} ` +
      `(${failure.status ? `HTTP ${failure.status}` : "no response"}): ${failure.detail}`,
  };
}

export async function createStaffUserAction(input: {
  email: string;
  firstName: string;
  lastName: string;
  contactNumber?: string;
  role: "staff" | "administrator";
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (input.role !== "staff") {
    return { ok: false, message: "Administrators can only create Staff accounts." };
  }

  const email = input.email.trim().toLowerCase();

  if (!/^[^\s@]+@[^\s@.]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid official e-mail address." };
  }
  if (input.firstName.trim().length < 2 || input.lastName.trim().length < 2) {
    return { ok: false, message: "First and last name must each be at least 2 characters." };
  }
  if (input.contactNumber && input.contactNumber.trim().length > 0) {
    const cleaned = input.contactNumber.replace(/[\s-]/g, "");
    if (!/^09\d{9}$/.test(cleaned)) {
      return { ok: false, message: "Contact number must be an 11-digit mobile number starting with 09 (e.g., 0917 123 4567)." };
    }
  }

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-users", {
    body: {
      action: "create_staff",
      email,
      first_name: input.firstName.trim(),
      last_name: input.lastName.trim(),
      contact_number: input.contactNumber?.trim() ?? "",
      role: input.role,
    },
  });

  if (error) {
    return edgeFunctionFailure(error, "The account could not be created", " No account has been created.");
  }

  revalidatePath("/admin/users");

  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  const details = {
    ...(linkDetails(data, ["setup_link", "email", "role", "user_id"]) ?? {}),
  };
  if (data?.invited === true) details.invited = true;

  return {
    ok: true,
    message:
      data?.message ??
      "Account created and the invitation e-mail was sent to the staff address.",
    details: Object.keys(details).length > 0 ? details : undefined,
  };
}

export async function sendPasswordResetAction(input: { email: string }): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-users", {
    body: { action: "send_password_reset", email: input.email.trim().toLowerCase() },
  });

  if (error) return edgeFunctionFailure(error, "A password reset link could not be created");
  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  return {
    ok: true,
    message:
      data?.message ??
      "A new password reset link has been created. No e-mail is sent automatically — copy it and pass it on.",
    details: linkDetails(data, ["reset_link", "email"]),
  };
}
