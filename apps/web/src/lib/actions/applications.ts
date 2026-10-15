"use server";

import { revalidatePath } from "next/cache";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import { DEMO_WRITE_BLOCKED, type ActionState } from "@/lib/actions/types";

/**
 * Application workflow actions.
 *
 * Every action calls a SECURITY DEFINER RPC that re-validates the caller's role
 * and the business rules inside PostgreSQL. The interface never updates the
 * status of an application directly.
 */

function refreshApplicationViews(applicationId?: string, recordId?: string) {
  revalidatePath("/admin");
  revalidatePath("/admin/applications");
  revalidatePath("/staff");
  revalidatePath("/staff/applications");
  revalidatePath("/admin/franchises");
  revalidatePath("/staff/franchises");
  if (applicationId) {
    revalidatePath(`/admin/applications/${applicationId}`);
    revalidatePath(`/staff/applications/${applicationId}`);
  }
  if (recordId) {
    revalidatePath(`/admin/franchises/${recordId}`);
    revalidatePath(`/staff/franchises/${recordId}`);
  }
}

export async function startReviewAction(applicationId: string): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_start_review", {
    p_application_id: applicationId,
  });

  refreshApplicationViews(applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Review started. The applicant has been notified." };
}

export async function verifyDocumentAction(input: {
  documentId: string;
  applicationId: string;
  status: "verified" | "rejected" | "pending";
  remarks?: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_verify_document", {
    p_document_id: input.documentId,
    p_status: input.status,
    p_remarks: input.remarks ?? null,
  });

  refreshApplicationViews(input.applicationId);
  if (error) return { ok: false, message: error.message };

  const message =
    input.status === "verified"
      ? "Document verified."
      : input.status === "rejected"
        ? "Document rejected. The applicant has been notified with the remark."
        : "Verification reset to pending.";
  return { ok: true, message };
}

export async function approveApplicationAction(applicationId: string): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("rpc_staff_approve_application", {
    p_application_id: applicationId,
  });

  refreshApplicationViews(applicationId);
  if (error) return { ok: false, message: error.message };

  const record = (Array.isArray(data) ? data[0] : data) as { id?: string; franchise_number?: string } | null;
  refreshApplicationViews(applicationId, record?.id);
  return {
    ok: true,
    message: `Application approved. Franchise number ${record?.franchise_number ?? ""} has been issued.`,
    details: { recordId: record?.id, franchiseNumber: record?.franchise_number },
  };
}

/* -------------------------------------------------------------------------- */
/* Phase 1 processing pipeline                                                 */
/* -------------------------------------------------------------------------- */

export async function assignApplicationAction(
  applicationId: string,
  staffId: string,
): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_assign_application", {
    p_application_id: applicationId,
    p_staff_id: staffId,
  });

  refreshApplicationViews(applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Application assigned to the selected staff member." };
}

export async function requestComplianceAction(
  applicationId: string,
  reason: string,
): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (reason.trim().length < 10) {
    return { ok: false, message: "A compliance note of at least 10 characters is required." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_request_compliance", {
    p_application_id: applicationId,
    p_reason: reason.trim(),
  });

  refreshApplicationViews(applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Application sent for compliance. The applicant has been notified." };
}

export async function markVerifiedAction(applicationId: string): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_mark_verified", {
    p_application_id: applicationId,
  });

  refreshApplicationViews(applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Application marked verified. All documentary requirements are complete." };
}

export async function recordApplicationAction(applicationId: string): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { data, error } = await supabase.rpc("rpc_staff_record_application", {
    p_application_id: applicationId,
  });

  refreshApplicationViews(applicationId);
  if (error) return { ok: false, message: error.message };

  const record = (Array.isArray(data) ? data[0] : data) as { id?: string; franchise_number?: string } | null;
  refreshApplicationViews(applicationId, record?.id);
  return {
    ok: true,
    message: `Application recorded. Franchise ${record?.franchise_number ?? ""} is ready for endorsement.`,
    details: { recordId: record?.id, franchiseNumber: record?.franchise_number },
  };
}

export async function recordEndorsementAction(input: {
  applicationId: string;
  endorsedTo: string;
  reference?: string;
  note?: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (input.endorsedTo.trim().length === 0) {
    return { ok: false, message: "The endorsing body or office is required." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_record_endorsement", {
    p_application_id: input.applicationId,
    p_endorsed_to: input.endorsedTo.trim(),
    p_reference: input.reference?.trim() || null,
    p_note: input.note?.trim() || null,
  });

  refreshApplicationViews(input.applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Endorsement recorded. The application is now for approval." };
}

export async function recordDecisionAction(input: {
  applicationId: string;
  decision: "approved" | "rejected";
  approvingAuthority?: string;
  reference?: string;
  reason?: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (input.decision === "approved") {
    if ((input.approvingAuthority ?? "").trim().length === 0) {
      return { ok: false, message: "The approving authority must be recorded when approving." };
    }
    if ((input.reference ?? "").trim().length === 0) {
      return { ok: false, message: "The decision reference (resolution/order) is required when approving." };
    }
  } else if ((input.reason ?? "").trim().length < 10) {
    return { ok: false, message: "A rejection reason of at least 10 characters is required." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_record_decision", {
    p_application_id: input.applicationId,
    p_decision: input.decision,
    p_approving_authority: input.approvingAuthority?.trim() || null,
    p_reference: input.reference?.trim() || null,
    p_reason: input.reason?.trim() || null,
  });

  refreshApplicationViews(input.applicationId);
  return error
    ? { ok: false, message: error.message }
    : {
        ok: true,
        message:
          input.decision === "approved"
            ? "Decision recorded: approved and ready for release."
            : "Decision recorded: rejected. The applicant has been notified.",
      };
}

export async function releaseDocumentAction(input: {
  applicationId: string;
  receivedByName: string;
  receivedById?: string;
  relationship?: string;
  notes?: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (input.receivedByName.trim().length === 0) {
    return { ok: false, message: "The name of the person receiving the document is required." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_release_document", {
    p_application_id: input.applicationId,
    p_received_by_name: input.receivedByName.trim(),
    p_received_by_id: input.receivedById?.trim() || null,
    p_relationship: input.relationship?.trim() || null,
    p_notes: input.notes?.trim() || null,
  });

  refreshApplicationViews(input.applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Release recorded. The franchise document has been handed over." };
}

export async function completeApplicationAction(applicationId: string): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_complete_application", {
    p_application_id: applicationId,
  });

  refreshApplicationViews(applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Application completed." };
}

export async function scheduleAppointmentAction(input: {
  applicationId: string;
  kind: "evaluation" | "physical_documents" | "hearing" | "release" | "other";
  scheduledAt: string;
  venue: string;
  notes?: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (!input.scheduledAt) return { ok: false, message: "An appointment date and time is required." };
  if (input.venue.trim().length === 0) return { ok: false, message: "An appointment venue is required." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_schedule_appointment", {
    p_application_id: input.applicationId,
    p_kind: input.kind,
    p_scheduled_at: new Date(input.scheduledAt).toISOString(),
    p_venue: input.venue.trim(),
    p_notes: input.notes?.trim() || null,
  });

  refreshApplicationViews(input.applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Appointment scheduled. The applicant has been notified." };
}

export async function updateAppointmentAction(input: {
  appointmentId: string;
  applicationId: string;
  status: "scheduled" | "completed" | "no_show" | "rescheduled" | "cancelled";
  outcome?: string;
  scheduledAt?: string;
  venue?: string;
  notes?: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_update_appointment", {
    p_appointment_id: input.appointmentId,
    p_status: input.status,
    p_outcome: input.outcome?.trim() || null,
    p_scheduled_at: input.scheduledAt ? new Date(input.scheduledAt).toISOString() : null,
    p_venue: input.venue?.trim() || null,
    p_notes: input.notes?.trim() || null,
  });

  refreshApplicationViews(input.applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Appointment updated." };
}

export async function rejectApplicationAction(
  applicationId: string,
  reason: string,
): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (reason.trim().length < 10) {
    return { ok: false, message: "A rejection reason of at least 10 characters is required." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_reject_application", {
    p_application_id: applicationId,
    p_reason: reason.trim(),
  });

  refreshApplicationViews(applicationId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Application rejected. The reason has been recorded and sent to the applicant." };
}

export async function archiveRecordAction(input: {
  recordId: string;
  reason: string;
  archived: boolean;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  if (input.archived && input.reason.trim().length < 5) {
    return { ok: false, message: "An archive reason of at least 5 characters is required." };
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_archive_franchise_record", {
    p_record_id: input.recordId,
    p_reason: input.reason.trim(),
    p_archived: input.archived,
  });

  refreshApplicationViews(undefined, input.recordId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: input.archived ? "Franchise record archived." : "Franchise record restored." };
}

export async function attachCertificateAction(input: {
  recordId: string;
  storagePath: string;
}): Promise<ActionState> {
  if (isDemoMode()) return DEMO_WRITE_BLOCKED;

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_staff_attach_certificate", {
    p_record_id: input.recordId,
    p_storage_path: input.storagePath,
  });

  refreshApplicationViews(undefined, input.recordId);
  return error
    ? { ok: false, message: error.message }
    : { ok: true, message: "Certificate stored and linked to the franchise record." };
}

/** Records interface-level audit events (sign-in, certificate download…). */
export async function logActivityAction(input: {
  action: "login" | "logout" | "certificate_generation" | "profile_update" | "notification_preferences_update" | "security_event";
  targetType?: "profile" | "franchise_record" | "franchise_application" | "system";
  targetId?: string;
  metadata?: Record<string, unknown>;
}): Promise<ActionState> {
  if (isDemoMode()) return { ok: true, message: "Preview mode: activity not recorded." };

  const supabase = await createClient();
  const { error } = await supabase.rpc("rpc_log_activity", {
    p_action: input.action,
    p_target_type: input.targetType ?? null,
    p_target_id: input.targetId ?? null,
    p_metadata: input.metadata ?? {},
  });

  return error ? { ok: false, message: error.message } : { ok: true, message: "Recorded." };
}
