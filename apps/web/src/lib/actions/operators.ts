"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";

const CONTACT_PATTERN = /^[0-9+\-() ]{7,20}$/;

export interface OperatorDetailsInput {
  profileId: string;
  contactNumber?: string;
  addressLine?: string;
  barangayCode?: string;
}

/**
 * Administrators may correct an operator's *descriptive* details from the
 * console. This is deliberately the minimal set: the TODA, the role, the
 * account status and the membership roster entry are managed by the
 * registration and administrative workflows, not by this form.
 *
 * Row Level Security is the real boundary — only an active administrator can
 * update another profile — but the function also refuses anything that is not
 * an operator account so a mistyped id cannot rewrite a staff record.
 */
export async function updateOperatorDetailsAction(
  input: OperatorDetailsInput,
): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const contactNumber = input.contactNumber?.trim() || null;
  const addressLine = input.addressLine?.trim() || null;
  const barangayCode = input.barangayCode?.trim() || null;

  if (contactNumber && !CONTACT_PATTERN.test(contactNumber)) {
    return { ok: false, message: "Enter a valid contact number, for example 0917 123 4567." };
  }
  if (addressLine && addressLine.length > 200) {
    return { ok: false, message: "Keep the address to 200 characters or fewer." };
  }

  const supabase = await createClient();

  const { data: target, error: targetError } = await supabase
    .from("profiles")
    .select("id, role")
    .eq("id", input.profileId)
    .maybeSingle();

  if (targetError) return { ok: false, message: targetError.message };
  if (!target) return { ok: false, message: "That operator account no longer exists." };
  if (target.role !== "driver") {
    return { ok: false, message: "Only tricycle operator accounts can be edited here." };
  }

  const { error } = await supabase
    .from("profiles")
    .update({
      contact_number: contactNumber,
      address_line: addressLine,
      barangay_code: barangayCode,
    })
    .eq("id", input.profileId);

  if (error) return { ok: false, message: error.message };

  const { error: logError } = await supabase.rpc("rpc_log_activity", {
    p_action: "profile_update",
    p_target_type: "profile",
    p_target_id: input.profileId,
    p_metadata: {
      actor: "administrator",
      fields: ["contact_number", "address_line", "barangay_code"],
    },
  });

  revalidatePath(`/admin/operators/${input.profileId}`);
  revalidatePath(`/staff/operators/${input.profileId}`);
  revalidatePath("/admin/users");

  if (logError) {
    return {
      ok: false,
      message: `The details were saved, but the activity log entry could not be written: ${logError.message}`,
    };
  }

  return {
    ok: true,
    message: "Operator details updated. The change is recorded in the activity log.",
  };
}
