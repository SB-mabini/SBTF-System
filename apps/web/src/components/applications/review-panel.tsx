"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  CheckCircle2,
  ExternalLink,
  Eye,
  FileText,
  RotateCcw,
  ThumbsDown,
  ThumbsUp,
  XCircle,
} from "lucide-react";

import { Alert, Badge, Button, Card, CardHeader, DocumentStatusBadge, Field } from "@/components/ui";
import { ConfirmDialog, Modal } from "@/components/dialog";
import {
  approveApplicationAction,
  rejectApplicationAction,
  startReviewAction,
  verifyDocumentAction,
} from "@/lib/actions/applications";
import { DOCUMENT_LABELS, REQUIRED_DOCUMENTS } from "@/lib/constants";
import { documentLabel, fileSize, formatDateTime } from "@/lib/format";
import { isDemoMode } from "@/lib/env";
import type { DocumentType, FranchiseDocument, FranchiseApplicationDetail } from "@/types/database";

type DocumentWithUrl = FranchiseDocument & { signed_url?: string | null };

export function ReviewPanel({
  application,
  documents,
}: {
  application: FranchiseApplicationDetail;
  documents: DocumentWithUrl[];
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [approveOpen, setApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [rejectReason, setRejectReason] = useState("");
  const [documentReject, setDocumentReject] = useState<DocumentWithUrl | null>(null);
  const [documentRemark, setDocumentRemark] = useState("");

  const readOnly = isDemoMode();
  const decided = application.status !== "pending";
  const verifiedCount = documents.filter((document) => document.verification_status === "verified").length;
  const allVerified = REQUIRED_DOCUMENTS.every((type) =>
    documents.some((document) => document.document_type === type && document.verification_status === "verified"),
  );

  const byType = new Map<DocumentType, DocumentWithUrl>();
  documents.forEach((document) => byType.set(document.document_type, document));

  function refresh(result: { ok: boolean; message: string }) {
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) {
      setApproveOpen(false);
      setRejectOpen(false);
      setDocumentReject(null);
      setDocumentRemark("");
      startTransition(() => router.refresh());
    }
  }

  async function handleStartReview() {
    setBusy(true);
    refresh(await startReviewAction(application.id));
  }

  async function handleVerify(document: DocumentWithUrl, status: "verified" | "rejected" | "pending", remarks?: string) {
    setBusy(true);
    refresh(
      await verifyDocumentAction({
        documentId: document.id,
        applicationId: application.id,
        status,
        remarks,
      }),
    );
  }

  async function handleApprove() {
    setBusy(true);
    refresh(await approveApplicationAction(application.id));
  }

  async function handleReject() {
    setBusy(true);
    refresh(await rejectApplicationAction(application.id, rejectReason));
  }

  return (
    <div className="space-y-4">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      <Card>
        <CardHeader
          title="Review workspace"
          description={
            decided
              ? "This application has been decided. The record below is read-only."
              : "Verify each documentary requirement, then record the decision."
          }
          icon={Eye}
          action={
            application.review_started_at ? (
              <Badge tone="info">Review started {formatDateTime(application.review_started_at)}</Badge>
            ) : (
              <Button
                variant="secondary"
                disabled={readOnly || decided || busy}
                loading={busy && !decided}
                onClick={handleStartReview}
              >
                Start review
              </Button>
            )
          }
        />

        <ol className="space-y-3">
          {REQUIRED_DOCUMENTS.map((type) => {
            const document = byType.get(type);
            return (
              <li key={type} className="rounded-lg border border-line p-3.5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[0.875rem] font-medium text-ink">{DOCUMENT_LABELS[type]}</p>
                    {document ? (
                      <p className="mt-0.5 text-[0.75rem] text-muted">
                        {document.file_name} · {fileSize(document.file_size_bytes)} ·{" "}
                        {document.mime_type}
                        {document.uploaded_at ? ` · uploaded ${formatDateTime(document.uploaded_at)}` : ""}
                      </p>
                    ) : (
                      <p className="mt-0.5 text-[0.75rem] text-secondary-600">
                        Not submitted — this requirement is missing.
                      </p>
                    )}
                  </div>
                  {document ? <DocumentStatusBadge status={document.verification_status} /> : null}
                </div>

                {document ? (
                  <>
                    {document.remarks ? (
                      <p className="mt-2 rounded-md bg-secondary-50 px-2.5 py-1.5 text-[0.75rem] text-secondary-700">
                        Remark: {document.remarks}
                      </p>
                    ) : null}

                    <div className="mt-3 flex flex-wrap items-center gap-2">
                      {document.signed_url ? (
                        <a
                          className="inline-flex items-center gap-1.5 rounded-lg border border-line-strong bg-white px-2.5 py-1.5 text-[0.75rem] font-medium text-ink hover:bg-page"
                          href={document.signed_url}
                          target="_blank"
                          rel="noreferrer"
                        >
                          <ExternalLink className="h-3.5 w-3.5" />
                          Open file
                        </a>
                      ) : (
                        <span className="inline-flex items-center gap-1.5 rounded-lg border border-line bg-page px-2.5 py-1.5 text-[0.75rem] text-muted">
                          <FileText className="h-3.5 w-3.5" />
                          {isDemoMode() ? "Preview mode — no file" : "Signed link unavailable"}
                        </span>
                      )}

                      <Button
                        variant="secondary"
                        disabled={readOnly || decided || busy}
                        onClick={() => handleVerify(document, "verified")}
                      >
                        <ThumbsUp className="h-3.5 w-3.5" />
                        Verify
                      </Button>

                      <Button
                        variant="outline"
                        disabled={readOnly || decided || busy}
                        onClick={() => {
                          setDocumentReject(document);
                          setDocumentRemark("");
                        }}
                      >
                        <ThumbsDown className="h-3.5 w-3.5" />
                        Reject document
                      </Button>

                      {document.verification_status !== "pending" && !decided ? (
                        <Button
                          variant="ghost"
                          disabled={readOnly || busy}
                          onClick={() => handleVerify(document, "pending")}
                        >
                          <RotateCcw className="h-3.5 w-3.5" />
                          Reset
                        </Button>
                      ) : null}
                    </div>
                  </>
                ) : null}
              </li>
            );
          })}
        </ol>

        <div className="mt-4 flex flex-wrap items-center justify-between gap-3 border-t border-line pt-4">
          <p className="text-[0.8125rem] text-muted">
            <span className="font-medium text-ink">{verifiedCount} of 4</span> requirements verified.
            Approval needs all four verified.
          </p>

          {decided ? (
            <Badge tone={application.status === "approved" ? "approved" : "rejected"}>
              {application.status === "approved" ? "Approved" : "Rejected"}
            </Badge>
          ) : (
            <div className="flex flex-wrap gap-2">
              <Button
                disabled={readOnly || !allVerified || busy}
                title={allVerified ? undefined : "All four documents must be verified first"}
                onClick={() => setApproveOpen(true)}
              >
                <CheckCircle2 className="h-4 w-4" />
                Approve and issue franchise
              </Button>
              <Button variant="danger" disabled={readOnly || busy} onClick={() => setRejectOpen(true)}>
                <XCircle className="h-4 w-4" />
                Reject application
              </Button>
            </div>
          )}
        </div>
      </Card>

      {/* Approve */}
      <ConfirmDialog
        open={approveOpen}
        title="Approve this application?"
        message="A franchise number and validity dates will be issued, a franchise record will be created, the applicant will be notified, and the decision will be written to the activity log. Approvals cannot be reverted from the interface."
        confirmLabel="Approve and issue"
        loading={busy}
        onConfirm={handleApprove}
        onCancel={() => setApproveOpen(false)}
      >
        <dl className="grid gap-2 text-[0.8125rem]">
          <Row label="Application" value={application.application_number} />
          <Row label="Operator" value={`${application.operator_first_name} ${application.operator_last_name}`} />
          <Row label="Plate" value={application.plate_number} />
          <Row label="TODA" value={application.toda?.name ?? "—"} />
          <Row
            label="Type"
            value={application.application_type === "renewal" ? "Renewal" : "New franchise"}
          />
        </dl>
      </ConfirmDialog>

      {/* Reject */}
      <Modal
        open={rejectOpen}
        title="Reject this application"
        description="The applicant receives the reason in the mobile app and by notification."
        onClose={() => setRejectOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setRejectOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="danger"
              loading={busy}
              disabled={rejectReason.trim().length < 10}
              onClick={handleReject}
            >
              Reject application
            </Button>
          </>
        }
      >
        <Field
          label="Reason for rejection (required, at least 10 characters)"
          htmlFor="reject-reason"
          hint={`${rejectReason.trim().length} character(s) entered.`}
        >
          <textarea
            id="reject-reason"
            className="sbtf-input min-h-[110px]"
            value={rejectReason}
            onChange={(event) => setRejectReason(event.target.value)}
            placeholder="State the specific deficiency and what the applicant must submit again."
          />
        </Field>
        <div className="mt-3">
          <Alert tone="info">
            Rejection reasons are part of the public record of the transaction and appear in the
            activity log and the applicant&apos;s timeline.
          </Alert>
        </div>
      </Modal>

      {/* Reject a single document */}
      <Modal
        open={documentReject !== null}
        title="Reject this document"
        description={documentReject ? documentLabel(documentReject.document_type) : undefined}
        onClose={() => setDocumentReject(null)}
        footer={
          <>
            <Button variant="outline" onClick={() => setDocumentReject(null)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant="danger"
              loading={busy}
              disabled={documentRemark.trim().length < 5}
              onClick={() => {
                if (documentReject) {
                  void handleVerify(documentReject, "rejected", documentRemark.trim());
                }
              }}
            >
              Reject document
            </Button>
          </>
        }
      >
        <Field
          label="Remark for the applicant (required, at least 5 characters)"
          htmlFor="document-remark"
        >
          <textarea
            id="document-remark"
            className="sbtf-input min-h-[90px]"
            value={documentRemark}
            onChange={(event) => setDocumentRemark(event.target.value)}
            placeholder="For example: the clearance presented expires on 12 March; submit a current one."
          />
        </Field>
        <p className="mt-2 text-[0.75rem] text-muted">
          The applicant can replace the document while the application stays pending; the
          replacement returns to the verification queue.
        </p>
      </Modal>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-muted">{label}</dt>
      <dd className="text-right font-medium text-ink">{value}</dd>
    </div>
  );
}

export function ApplicationSummaryCard({
  application,
}: {
  application: FranchiseApplicationDetail;
}) {
  const rows: Array<[string, string | null | undefined]> = [
    ["Application number", application.application_number],
    ["Type", application.application_type === "renewal" ? "Renewal" : "New franchise"],
    ["Status", application.status],
    ["Submitted", formatDateTime(application.submitted_at)],
    ["Review started", application.review_started_at ? formatDateTime(application.review_started_at) : "Not started"],
    ["Decided", application.reviewed_at ? formatDateTime(application.reviewed_at) : "Pending"],
    ["Reviewed by", application.reviewer?.full_name ?? "—"],
  ];

  return (
    <Card>
      <CardHeader title="Application" description={application.application_number} icon={FileText} />
      <dl className="space-y-2 text-[0.8125rem]">
        {rows.map(([label, value]) => (
          <div key={label} className="flex justify-between gap-4">
            <dt className="text-muted">{label}</dt>
            <dd className="text-right font-medium text-ink">{value ?? "—"}</dd>
          </div>
        ))}
      </dl>
      {application.rejection_reason ? (
        <div className="mt-3">
          <Alert tone="danger" title="Reason for rejection">
            {application.rejection_reason}
          </Alert>
        </div>
      ) : null}
    </Card>
  );
}
