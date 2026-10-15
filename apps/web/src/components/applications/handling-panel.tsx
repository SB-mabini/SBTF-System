"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  CalendarDays,
  CheckCircle2,
  FileText,
  UserCheck,
} from "lucide-react";

import { Alert, Badge, Button, Card, CardHeader, Field } from "@/components/ui";
import { ConfirmDialog, Modal } from "@/components/dialog";
import {
  assignApplicationAction,
  completeApplicationAction,
  markVerifiedAction,
  recordApplicationAction,
  recordDecisionAction,
  recordEndorsementAction,
  releaseDocumentAction,
  requestComplianceAction,
  scheduleAppointmentAction,
  updateAppointmentAction,
} from "@/lib/actions/applications";
import {
  APPLICATION_STAGE_LABELS,
  APPLICATION_STAGE_ORDER,
  APPOINTMENT_KIND_LABELS,
  APPOINTMENT_STATUS_LABELS,
  REQUIRED_DOCUMENTS,
} from "@/lib/constants";
import { formatDateTime } from "@/lib/format";
import { isDemoMode } from "@/lib/env";
import type {
  ApplicationAppointment,
  AppointmentKind,
  AppointmentStatus,
  DocumentRelease,
  FranchiseApplicationDetail,
  Profile,
} from "@/types/database";

const TERMINAL_STAGES = new Set(["completed", "rejected"]);

export function HandlingPanel({
  application,
  staff,
  appointments,
  release,
  readOnly = false,
}: {
  application: FranchiseApplicationDetail;
  staff: Profile[];
  appointments: ApplicationAppointment[];
  release: DocumentRelease | null;
  readOnly?: boolean;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const [assignOpen, setAssignOpen] = useState(false);
  const [assignStaffId, setAssignStaffId] = useState(application.assigned_staff_id ?? "");
  const [complianceOpen, setComplianceOpen] = useState(false);
  const [complianceReason, setComplianceReason] = useState("");
  const [endorsementOpen, setEndorsementOpen] = useState(false);
  const [endorsedTo, setEndorsedTo] = useState(application.endorsed_to ?? "");
  const [endorsementReference, setEndorsementReference] = useState(application.endorsement_reference ?? "");
  const [endorsementNote, setEndorsementNote] = useState("");
  const [decisionOpen, setDecisionOpen] = useState(false);
  const [decision, setDecision] = useState<"approved" | "rejected">("approved");
  const [approvingAuthority, setApprovingAuthority] = useState("");
  const [decisionReference, setDecisionReference] = useState("");
  const [decisionReason, setDecisionReason] = useState("");
  const [releaseOpen, setReleaseOpen] = useState(false);
  const [receivedByName, setReceivedByName] = useState("");
  const [receivedById, setReceivedById] = useState("");
  const [relationship, setRelationship] = useState("");
  const [releaseNotes, setReleaseNotes] = useState("");
  const [completeOpen, setCompleteOpen] = useState(false);

  const [scheduleOpen, setScheduleOpen] = useState(false);
  const [scheduleKind, setScheduleKind] = useState<AppointmentKind>("evaluation");
  const [scheduleAt, setScheduleAt] = useState("");
  const [scheduleVenue, setScheduleVenue] = useState("");
  const [scheduleNotes, setScheduleNotes] = useState("");
  const [appointmentEdit, setAppointmentEdit] = useState<ApplicationAppointment | null>(null);
  const [appointmentStatus, setAppointmentStatus] = useState<AppointmentStatus>("completed");
  const [appointmentOutcome, setAppointmentOutcome] = useState("");
  const [appointmentAt, setAppointmentAt] = useState("");
  const [appointmentVenue, setAppointmentVenue] = useState("");
  const [appointmentNotes, setAppointmentNotes] = useState("");

  const locked = readOnly || isDemoMode();
  const stage = application.stage;
  const decided = application.status !== "pending";
  const terminal = TERMINAL_STAGES.has(stage);
  const approved = application.status === "approved";
  const verifiedCount = (application.documents ?? []).filter(
    (document) => document.verification_status === "verified",
  ).length;
  const allVerified = REQUIRED_DOCUMENTS.every((type) =>
    (application.documents ?? []).some(
      (document) => document.document_type === type && document.verification_status === "verified",
    ),
  );

  function run(
    promise: Promise<{ ok: boolean; message: string }>,
    close?: () => void,
  ) {
    setBusy(true);
    void promise.then((result) => {
      setMessage({ ok: result.ok, text: result.message });
      setBusy(false);
      if (result.ok) {
        close?.();
        startTransition(() => router.refresh());
      }
    });
  }

  const currentIndex = APPLICATION_STAGE_ORDER.indexOf(
    stage === "rejected" ? "completed" : stage,
  );

  return (
    <div className="space-y-4">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      <Card>
        <CardHeader
          title="Processing pipeline"
          description={
            terminal
              ? "This application has reached a terminal stage; the pipeline below is a record."
              : "Advance the application through each processing stage."
          }
          icon={FileText}
          action={<Badge tone={stage === "rejected" ? "rejected" : "info"}>{APPLICATION_STAGE_LABELS[stage]}</Badge>}
        />

        <ol className="mb-4 space-y-1.5">
          {APPLICATION_STAGE_ORDER.map((entry, index) => {
            const done = currentIndex > index && !(stage === "rejected" && index > 6);
            const active = entry === stage;
            return (
              <li key={entry} className="flex items-center gap-2.5 text-[0.8125rem]">
                <span
                  className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[0.625rem] font-semibold ${
                    active
                      ? "bg-primary text-white"
                      : done
                        ? "bg-primary-100 text-primary-700"
                        : "bg-page text-muted"
                  }`}
                >
                  {done ? "✓" : index + 1}
                </span>
                <span className={active ? "font-semibold text-ink" : done ? "text-ink" : "text-muted"}>
                  {APPLICATION_STAGE_LABELS[entry]}
                </span>
              </li>
            );
          })}
        </ol>

        <div className="grid gap-3 border-t border-line pt-4 sm:grid-cols-2">
          <div className="text-[0.8125rem]">
            <p className="text-muted">Assigned to</p>
            <p className="font-medium text-ink">
              {staff.find((member) => member.id === application.assigned_staff_id)?.full_name ?? "Unassigned"}
            </p>
          </div>
          <div className="text-[0.8125rem]">
            <p className="text-muted">Documentary requirements</p>
            <p className="font-medium text-ink">
              {verifiedCount} of {REQUIRED_DOCUMENTS.length} verified
            </p>
          </div>
          {application.for_compliance_reason ? (
            <div className="sm:col-span-2">
              <Alert tone="warning" title="For compliance">
                {application.for_compliance_reason}
              </Alert>
            </div>
          ) : null}
          {application.endorsed_to ? (
            <div className="text-[0.8125rem] sm:col-span-2">
              <p className="text-muted">Endorsed to</p>
              <p className="font-medium text-ink">
                {application.endorsed_to}
                {application.endorsement_reference ? ` · ${application.endorsement_reference}` : ""}
              </p>
            </div>
          ) : null}
        </div>

        {!locked ? (
          <div className="mt-4 flex flex-wrap gap-2 border-t border-line pt-4">
            <Button variant="secondary" onClick={() => setAssignOpen(true)}>
              <UserCheck className="h-4 w-4" />
              Assign
            </Button>

            {!decided ? (
              <>
                {stage !== "for_compliance" ? (
                  <Button variant="outline" disabled={busy} onClick={() => setComplianceOpen(true)}>
                    Send for compliance
                  </Button>
                ) : null}

                {["submitted", "under_verification", "for_compliance"].includes(stage) ? (
                  <Button
                    disabled={!allVerified || busy}
                    title={allVerified ? undefined : "Every documentary requirement must be verified first"}
                    onClick={() => run(markVerifiedAction(application.id))}
                  >
                    <CheckCircle2 className="h-4 w-4" />
                    Mark verified
                  </Button>
                ) : null}

                {stage === "verified" ? (
                  <Button disabled={!allVerified || busy} onClick={() => run(recordApplicationAction(application.id))}>
                    <FileText className="h-4 w-4" />
                    Record application
                  </Button>
                ) : null}

                {["recorded", "for_endorsement"].includes(stage) ? (
                  <Button disabled={busy} onClick={() => setEndorsementOpen(true)}>
                    Record endorsement
                  </Button>
                ) : null}

                {stage === "for_approval" ? (
                  <Button disabled={busy} onClick={() => setDecisionOpen(true)}>
                    Record decision
                  </Button>
                ) : null}
              </>
            ) : null}

            {approved && stage === "ready_for_release" ? (
              <Button disabled={busy} onClick={() => setReleaseOpen(true)}>
                Release document
              </Button>
            ) : null}

            {stage === "released" ? (
              <Button disabled={busy} onClick={() => setCompleteOpen(true)}>
                Complete application
              </Button>
            ) : null}
          </div>
        ) : (
          <p className="mt-4 border-t border-line pt-4 text-[0.75rem] text-muted">
            {readOnly ? "Administrator view — processing actions are performed by staff." : "Preview mode — actions are disabled."}
          </p>
        )}
      </Card>

      <Card>
        <CardHeader
          title="Appointments"
          description="Meetings, physical-document submissions, hearings and releases."
          icon={CalendarDays}
          action={
            !locked && !terminal ? (
              <Button variant="secondary" onClick={() => setScheduleOpen(true)}>
                Schedule
              </Button>
            ) : null
          }
        />

        {appointments.length === 0 ? (
          <p className="text-[0.8125rem] text-muted">No appointments scheduled.</p>
        ) : (
          <ul className="space-y-2.5">
            {appointments.map((appointment) => (
              <li key={appointment.id} className="rounded-lg border border-line p-3.5">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div>
                    <p className="text-[0.875rem] font-medium text-ink">
                      {APPOINTMENT_KIND_LABELS[appointment.kind]}
                    </p>
                    <p className="mt-0.5 text-[0.75rem] text-muted">
                      {formatDateTime(appointment.scheduled_at)} · {appointment.venue}
                    </p>
                    {appointment.outcome ? (
                      <p className="mt-1 text-[0.75rem] text-ink">Outcome: {appointment.outcome}</p>
                    ) : null}
                  </div>
                  <Badge tone={appointment.status === "completed" ? "success" : appointment.status === "cancelled" ? "rejected" : "info"}>
                    {APPOINTMENT_STATUS_LABELS[appointment.status]}
                  </Badge>
                </div>
                {!locked && appointment.status === "scheduled" ? (
                  <div className="mt-2.5 flex flex-wrap gap-2">
                    <Button
                      variant="outline"
                      onClick={() => {
                        setAppointmentEdit(appointment);
                        setAppointmentStatus("completed");
                        setAppointmentOutcome("");
                        setAppointmentAt(appointment.scheduled_at.slice(0, 16));
                        setAppointmentVenue(appointment.venue);
                        setAppointmentNotes("");
                      }}
                    >
                      Update
                    </Button>
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        )}

        {release ? (
          <div className="mt-4 border-t border-line pt-3 text-[0.8125rem]">
            <p className="font-medium text-ink">Document released</p>
            <p className="mt-0.5 text-muted">
              {formatDateTime(release.released_at)} · received by {release.received_by_name}
              {release.relationship ? ` (${release.relationship})` : ""}
            </p>
          </div>
        ) : null}
      </Card>

      {/* Assign */}
      <Modal
        open={assignOpen}
        title="Assign application"
        onClose={() => setAssignOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setAssignOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              disabled={!assignStaffId}
              onClick={() => run(assignApplicationAction(application.id, assignStaffId), () => setAssignOpen(false))}
            >
              Assign
            </Button>
          </>
        }
      >
        <Field label="Staff member" htmlFor="assign-staff">
          <select
            id="assign-staff"
            className="sbtf-input"
            value={assignStaffId}
            onChange={(event) => setAssignStaffId(event.target.value)}
          >
            <option value="">Select a staff member…</option>
            {staff.map((member) => (
              <option key={member.id} value={member.id}>
                {member.full_name}
              </option>
            ))}
          </select>
        </Field>
      </Modal>

      {/* Compliance */}
      <Modal
        open={complianceOpen}
        title="Send for compliance"
        description="The applicant is notified to correct or complete the requirements."
        onClose={() => setComplianceOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setComplianceOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              disabled={complianceReason.trim().length < 10}
              onClick={() => run(requestComplianceAction(application.id, complianceReason), () => setComplianceOpen(false))}
            >
              Send for compliance
            </Button>
          </>
        }
      >
        <Field
          label="What must the applicant comply with? (required, at least 10 characters)"
          htmlFor="compliance-reason"
          hint={`${complianceReason.trim().length} character(s).`}
        >
          <textarea
            id="compliance-reason"
            className="sbtf-input min-h-[110px]"
            value={complianceReason}
            onChange={(event) => setComplianceReason(event.target.value)}
          />
        </Field>
      </Modal>

      {/* Endorsement */}
      <Modal
        open={endorsementOpen}
        title="Record endorsement"
        description="Record the body or office the application is endorsed to for approval."
        onClose={() => setEndorsementOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setEndorsementOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              disabled={endorsedTo.trim().length === 0}
              onClick={() =>
                run(
                  recordEndorsementAction({
                    applicationId: application.id,
                    endorsedTo,
                    reference: endorsementReference,
                    note: endorsementNote,
                  }),
                  () => setEndorsementOpen(false),
                )
              }
            >
              Record endorsement
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <Field label="Endorsing body / office (required)" htmlFor="endorsed-to">
            <input
              id="endorsed-to"
              className="sbtf-input"
              value={endorsedTo}
              onChange={(event) => setEndorsedTo(event.target.value)}
              placeholder="For example: Committee on Transportation"
            />
          </Field>
          <Field label="Reference" htmlFor="endorsement-reference">
            <input
              id="endorsement-reference"
              className="sbtf-input"
              value={endorsementReference}
              onChange={(event) => setEndorsementReference(event.target.value)}
              placeholder="Indorsement / committee reference"
            />
          </Field>
          <Field label="Note" htmlFor="endorsement-note">
            <textarea
              id="endorsement-note"
              className="sbtf-input min-h-[80px]"
              value={endorsementNote}
              onChange={(event) => setEndorsementNote(event.target.value)}
            />
          </Field>
        </div>
      </Modal>

      {/* Decision */}
      <Modal
        open={decisionOpen}
        title="Record decision"
        description="Capture the decision of the approving authority. Staff record the outcome; they do not decide it."
        onClose={() => setDecisionOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setDecisionOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={decision === "rejected" ? "danger" : "primary"}
              loading={busy}
              disabled={
                decision === "approved"
                  ? approvingAuthority.trim().length === 0 || decisionReference.trim().length === 0
                  : decisionReason.trim().length < 10
              }
              onClick={() =>
                run(
                  recordDecisionAction({
                    applicationId: application.id,
                    decision,
                    approvingAuthority,
                    reference: decisionReference,
                    reason: decisionReason,
                  }),
                  () => setDecisionOpen(false),
                )
              }
            >
              Record decision
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <Field label="Decision (required)" htmlFor="decision-choice">
            <select
              id="decision-choice"
              className="sbtf-input"
              value={decision}
              onChange={(event) => setDecision(event.target.value as "approved" | "rejected")}
            >
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
            </select>
          </Field>

          {decision === "approved" ? (
            <>
              <Field label="Approving authority (required)" htmlFor="approving-authority">
                <input
                  id="approving-authority"
                  className="sbtf-input"
                  value={approvingAuthority}
                  onChange={(event) => setApprovingAuthority(event.target.value)}
                  placeholder="Body, office or official that approved"
                />
              </Field>
              <Field label="Resolution / order reference (required)" htmlFor="decision-reference">
                <input
                  id="decision-reference"
                  className="sbtf-input"
                  value={decisionReference}
                  onChange={(event) => setDecisionReference(event.target.value)}
                />
              </Field>
            </>
          ) : (
            <Field
              label="Reason for rejection (required, at least 10 characters)"
              htmlFor="decision-reason"
              hint={`${decisionReason.trim().length} character(s) entered.`}
            >
              <textarea
                id="decision-reason"
                className="sbtf-input min-h-[100px]"
                value={decisionReason}
                onChange={(event) => setDecisionReason(event.target.value)}
              />
            </Field>
          )}
        </div>
      </Modal>

      {/* Release */}
      <Modal
        open={releaseOpen}
        title="Release franchise document"
        description="Record who physically received the issued franchise document."
        onClose={() => setReleaseOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setReleaseOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              disabled={receivedByName.trim().length === 0}
              onClick={() =>
                run(
                  releaseDocumentAction({
                    applicationId: application.id,
                    receivedByName,
                    receivedById,
                    relationship,
                    notes: releaseNotes,
                  }),
                  () => setReleaseOpen(false),
                )
              }
            >
              Release document
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <Field label="Received by (required)" htmlFor="received-by-name">
            <input
              id="received-by-name"
              className="sbtf-input"
              value={receivedByName}
              onChange={(event) => setReceivedByName(event.target.value)}
            />
          </Field>
          <Field label="ID / reference number" htmlFor="received-by-id">
            <input
              id="received-by-id"
              className="sbtf-input"
              value={receivedById}
              onChange={(event) => setReceivedById(event.target.value)}
            />
          </Field>
          <Field label="Relationship to applicant" htmlFor="release-relationship">
            <input
              id="release-relationship"
              className="sbtf-input"
              value={relationship}
              onChange={(event) => setRelationship(event.target.value)}
              placeholder="For example: Applicant, Spouse, Authorised representative"
            />
          </Field>
          <Field label="Notes" htmlFor="release-notes">
            <textarea
              id="release-notes"
              className="sbtf-input min-h-[80px]"
              value={releaseNotes}
              onChange={(event) => setReleaseNotes(event.target.value)}
            />
          </Field>
        </div>
      </Modal>

      {/* Complete */}
      <ConfirmDialog
        open={completeOpen}
        title="Complete this application?"
        message="The application will be marked completed. This is the final processing stage and cannot be undone from the interface."
        confirmLabel="Complete application"
        loading={busy}
        onConfirm={() => run(completeApplicationAction(application.id), () => setCompleteOpen(false))}
        onCancel={() => setCompleteOpen(false)}
      />

      {/* Schedule appointment */}
      <Modal
        open={scheduleOpen}
        title="Schedule appointment"
        onClose={() => setScheduleOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setScheduleOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              disabled={!scheduleAt || scheduleVenue.trim().length === 0}
              onClick={() =>
                run(
                  scheduleAppointmentAction({
                    applicationId: application.id,
                    kind: scheduleKind,
                    scheduledAt: scheduleAt,
                    venue: scheduleVenue,
                    notes: scheduleNotes,
                  }),
                  () => setScheduleOpen(false),
                )
              }
            >
              Schedule
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <Field label="Type" htmlFor="appointment-kind">
            <select
              id="appointment-kind"
              className="sbtf-input"
              value={scheduleKind}
              onChange={(event) => setScheduleKind(event.target.value as AppointmentKind)}
            >
              {(Object.keys(APPOINTMENT_KIND_LABELS) as AppointmentKind[]).map((kind) => (
                <option key={kind} value={kind}>
                  {APPOINTMENT_KIND_LABELS[kind]}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Date and time (required)" htmlFor="appointment-at">
            <input
              id="appointment-at"
              type="datetime-local"
              className="sbtf-input"
              value={scheduleAt}
              onChange={(event) => setScheduleAt(event.target.value)}
            />
          </Field>
          <Field label="Venue (required)" htmlFor="appointment-venue">
            <input
              id="appointment-venue"
              className="sbtf-input"
              value={scheduleVenue}
              onChange={(event) => setScheduleVenue(event.target.value)}
            />
          </Field>
          <Field label="Notes" htmlFor="appointment-notes">
            <textarea
              id="appointment-notes"
              className="sbtf-input min-h-[80px]"
              value={scheduleNotes}
              onChange={(event) => setScheduleNotes(event.target.value)}
            />
          </Field>
        </div>
      </Modal>

      {/* Update appointment */}
      <Modal
        open={appointmentEdit !== null}
        title="Update appointment"
        onClose={() => setAppointmentEdit(null)}
        footer={
          <>
            <Button variant="outline" onClick={() => setAppointmentEdit(null)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              onClick={() => {
                if (!appointmentEdit) return;
                run(
                  updateAppointmentAction({
                    appointmentId: appointmentEdit.id,
                    applicationId: application.id,
                    status: appointmentStatus,
                    outcome: appointmentStatus === "completed" ? appointmentOutcome : undefined,
                    scheduledAt: appointmentStatus === "rescheduled" ? appointmentAt : undefined,
                    venue: appointmentStatus === "rescheduled" ? appointmentVenue : undefined,
                    notes: appointmentNotes,
                  }),
                  () => setAppointmentEdit(null),
                );
              }}
            >
              Save
            </Button>
          </>
        }
      >
        <div className="space-y-3">
          <Field label="Status" htmlFor="appointment-status">
            <select
              id="appointment-status"
              className="sbtf-input"
              value={appointmentStatus}
              onChange={(event) => setAppointmentStatus(event.target.value as AppointmentStatus)}
            >
              {(Object.keys(APPOINTMENT_STATUS_LABELS) as AppointmentStatus[])
                .filter((status) => status !== "scheduled")
                .map((status) => (
                  <option key={status} value={status}>
                    {APPOINTMENT_STATUS_LABELS[status]}
                  </option>
                ))}
            </select>
          </Field>
          {appointmentStatus === "rescheduled" ? (
            <>
              <Field label="New date and time" htmlFor="appointment-reschedule-at">
                <input
                  id="appointment-reschedule-at"
                  type="datetime-local"
                  className="sbtf-input"
                  value={appointmentAt}
                  onChange={(event) => setAppointmentAt(event.target.value)}
                />
              </Field>
              <Field label="Venue" htmlFor="appointment-reschedule-venue">
                <input
                  id="appointment-reschedule-venue"
                  className="sbtf-input"
                  value={appointmentVenue}
                  onChange={(event) => setAppointmentVenue(event.target.value)}
                />
              </Field>
            </>
          ) : null}
          {appointmentStatus === "completed" ? (
            <Field label="Outcome" htmlFor="appointment-outcome">
              <textarea
                id="appointment-outcome"
                className="sbtf-input min-h-[80px]"
                value={appointmentOutcome}
                onChange={(event) => setAppointmentOutcome(event.target.value)}
              />
            </Field>
          ) : null}
          <Field label="Notes" htmlFor="appointment-update-notes">
            <textarea
              id="appointment-update-notes"
              className="sbtf-input min-h-[80px]"
              value={appointmentNotes}
              onChange={(event) => setAppointmentNotes(event.target.value)}
            />
          </Field>
        </div>
      </Modal>
    </div>
  );
}
