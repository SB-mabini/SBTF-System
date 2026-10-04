"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { getSessionProfile } from "@/lib/data";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";

export interface ProfileUpdateInput {
  firstName: string;
  middleName?: string;
  lastName: string;
  contactNumber?: string;
  addressLine?: string;
  barangayCode?: string;
  emailNotifications: boolean;
  renewalReminders: boolean;
}

const NAME_PATTERN = /^[A-Za-zÀ-ÖØ-öø-ÿ.'\-\s]{1,60}$/;
const CONTACT_PATTERN = /^[0-9+\-() ]{7,20}$/;

/**
 * Updates the signed-in user's own descriptive profile fields.
 *
 * The role and the account status are not part of this input on purpose: the
 * database grants UPDATE only on the descriptive columns, so an administrator
 * cannot escalate anyone (or themselves) from this form.
 */
export async function updateProfileAction(input: ProfileUpdateInput): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const session = await getSessionProfile();
  if (!session) return { ok: false, message: "Your session has expired. Sign in again." };

  const firstName = input.firstName.trim();
  const lastName = input.lastName.trim();
  const middleName = input.middleName?.trim() || null;
  const contactNumber = input.contactNumber?.trim() || null;
  const addressLine = input.addressLine?.trim() || null;

  if (!NAME_PATTERN.test(firstName) || !NAME_PATTERN.test(lastName)) {
    return { ok: false, message: "Enter a valid first and last name." };
  }
  if (middleName && !NAME_PATTERN.test(middleName)) {
    return { ok: false, message: "Enter a valid middle name, or leave it blank." };
  }
  if (contactNumber && !CONTACT_PATTERN.test(contactNumber)) {
    return { ok: false, message: "Enter a valid contact number, for example 0917 123 4567." };
  }

  const supabase = await createClient();
  const { error } = await supabase
    .from("profiles")
    .update({
      first_name: firstName,
      middle_name: middleName,
      last_name: lastName,
      contact_number: contactNumber,
      address_line: addressLine,
      barangay_code: input.barangayCode?.trim() || null,
      email_notifications: input.emailNotifications,
      renewal_reminders: input.renewalReminders,
    })
    .eq("id", session.profile.id);

  if (error) return { ok: false, message: error.message };

  const { error: logError } = await supabase.rpc("rpc_log_activity", {
    p_action: "profile_update",
    p_target_type: "profile",
    p_target_id: session.profile.id,
    p_metadata: { fields: ["name", "contact", "address", "barangay", "notification_preferences"] },
  });
  if (logError) {
    // The profile change succeeded; failing to write the audit entry must be
    // surfaced rather than silently swallowed.
    return {
      ok: false,
      message: `Your details were saved, but the activity log entry could not be written: ${logError.message}`,
    };
  }

  revalidatePath("/admin/account");
  revalidatePath("/staff/account");
  return { ok: true, message: "Your details have been updated." };
}
