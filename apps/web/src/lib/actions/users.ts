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

export async function createStaffUserAction(input: {
  email: string;
  firstName: string;
  lastName: string;
  contactNumber?: string;
  role: "staff" | "administrator";
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-users", {
    body: {
      action: "create_staff",
      email: input.email.trim().toLowerCase(),
      first_name: input.firstName.trim(),
      last_name: input.lastName.trim(),
      contact_number: input.contactNumber?.trim() ?? "",
      role: input.role,
    },
  });

  revalidatePath("/admin/users");

  if (error) {
    return {
      ok: false,
      message: `The account could not be created: ${error.message ?? "Edge Function unavailable"}.`,
    };
  }
  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };

  return {
    ok: true,
    message:
      "Account created. The new user receives a Supabase Auth e-mail to set their password before signing in.",
  };
}

export async function sendPasswordResetAction(input: { email: string }): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("admin-users", {
    body: { action: "send_password_reset", email: input.email.trim().toLowerCase() },
  });

  if (error) return { ok: false, message: error.message ?? "Edge Function unavailable." };
  if (data?.error) return { ok: false, message: String(data.message ?? data.error) };
  return { ok: true, message: "A password reset link has been generated and e-mailed." };
}
