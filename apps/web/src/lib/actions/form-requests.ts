"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";

/**
 * Form-request handling actions.
 *
 * Requests are created by drivers in the mobile app (rpc_driver_request_form);
 * the console only issues and converts them. Every action calls a SECURITY
 * DEFINER RPC that re-validates the caller's role inside PostgreSQL.
 */

function refreshFormRequestViews(formRequestId?: string) {
  revalidatePath("/staff");
  revalidatePath("/staff/form-requests");
  if (formRequestId) revalidatePath(`/staff/form-requests/${formRequestId}`);
}

export async function issueFormRequestAction(formRequestId: string): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_issue_form_request", {
    p_form_request_id: formRequestId,
  });

  refreshFormRequestViews(formRequestId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Form request issued. The applicant has been notified to collect the form." };
}

export async function convertFormRequestAction(input: {
  formRequestId: string;
  applicationNumber: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const number = input.applicationNumber.trim();
  if (number.length === 0) {
    return { ok: false, message: "Enter the application number to link this request to." };
  }

  const supabase = await createClient();
  const { data: application } = await supabase
    .from("franchise_applications")
    .select("id")
    .eq("application_number", number)
    .maybeSingle();

  if (!application) {
    return { ok: false, message: `No application found with number ${number}.` };
  }

  const { error } = await supabase.rpc("rpc_staff_convert_form_request", {
    p_form_request_id: input.formRequestId,
    p_application_id: application.id,
  });

  refreshFormRequestViews(input.formRequestId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: `Form request linked to application ${number}.` };
}
