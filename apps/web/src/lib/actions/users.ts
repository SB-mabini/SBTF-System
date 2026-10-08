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
      reason: input.reason,
    },
  });

  revalidatePath("/admin/users");
  revalidatePath(`/admin/users/${input.profileId}`);

  if (error) {
    return {
      ok: false,
      message:
        "The account could not be deactivated through the admin-users function. " +
        (error.message ?? "Check that the Edge Function is deployed."),
    };
  }
  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  return { ok: true, message: "Account deactivated. The session can no longer access any data." };
}

/**
 * The admin-users Edge Function hands the recovery link back instead of sending
 * an e-mail (Supabase's built-in mailer is rate-limited and usually only reaches
 * addresses already on the project team). The actions forward that link into
 * `ActionState.details`, which is the only channel a server action has for
 * returning data alongside the message.
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

/**
 * supabase.functions.invoke throws a FunctionsHttpError when the function is not
 * deployed or answers with a non-2xx status. Both are reported as failures: a
 * half-created account would leave an auth user with no profile, so nothing is
 * presented as success unless the function said so.
 */
function edgeFunctionUnavailable(error: { message?: string } | null): ActionState {
  return {
    ok: false,
    message:
      `The admin-users Edge Function did not answer: ${error?.message ?? "unknown error"}. ` +
      "Deploy it with `supabase functions deploy admin-users` and set the SITE_URL secret. " +
      "No account has been created.",
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

  const email = input.email.trim().toLowerCase();

  if (!/^[^\s@]+@[^\s@.]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid official e-mail address." };
  }
  if (input.firstName.trim().length < 1 || input.lastName.trim().length < 1) {
    return { ok: false, message: "First and last name are required." };
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

  if (error) return edgeFunctionUnavailable(error);

  revalidatePath("/admin/users");

  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  return {
    ok: true,
    message:
      data?.message ??
      "Account created. No e-mail is sent automatically — copy the setup link and send it to the new user yourself.",
    details: linkDetails(data, ["setup_link", "email", "role", "user_id"]),
  };
}

export async function sendPasswordResetAction(input: { email: string }): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-users", {
    body: { action: "send_password_reset", email: input.email.trim().toLowerCase() },
  });

  if (error) return edgeFunctionUnavailable(error);
  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  return {
    ok: true,
    message:
      data?.message ??
      "A new password reset link has been created. No e-mail is sent automatically — copy it and pass it on.",
    details: linkDetails(data, ["reset_link", "email"]),
  };
}
