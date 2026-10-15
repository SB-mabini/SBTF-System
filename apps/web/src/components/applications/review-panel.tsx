"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  ExternalLink,
  Eye,
  FileText,
  RotateCcw,
  ThumbsDown,
  ThumbsUp,
} from "lucide-react";

import { Alert, Badge, Button, Card, CardHeader, DocumentStatusBadge, Field } from "@/components/ui";
import { Modal } from "@/components/dialog";
import { startReviewAction, verifyDocumentAction } from "@/lib/actions/applications";
import { DOCUMENT_LABELS, REQUIRED_DOCUMENTS } from "@/lib/constants";
import { fileSize, formatDateTime } from "@/lib/format";
import { isDemoMode } from "@/lib/env";
import type { DocumentType, FranchiseDocument, FranchiseApplicationDetail } from "@/types/database";

type DocumentWithUrl = FranchiseDocument & { signed_url?: string | null };

export function ReviewPanel({
  application,
  documents,
  readOnly = false,
}: {
  application: FranchiseApplicationDetail;
  documents: DocumentWithUrl[];
  readOnly?: boolean;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [documentReject, setDocumentReject] = useState<DocumentWithUrl | null>(null);
  const [documentRemark, setDocumentRemark] = useState("");

  const disabled = readOnly || isDemoMode();
  const decided = application.status !== "pending";
  const verifiedCount = documents.filter((document) => document.verification_status === "verified").length;

  const byType = new Map<DocumentType, DocumentWithUrl>();
  documents.forEach((document) => byType.set(document.document_type, document));

  function refresh(result: { ok: boolean; message: string }) {
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) {
      setDocumentReject(null);
      setDocumentRemark("");
      startTransition(() => router.refresh());
    }
  }

  async function handleStartReview() {
    setBusy(true);
    refresh(await startReviewAction(application.id));
  }

  async function handleVerify(
    document: DocumentWithUrl,
    status: "verified" | "rejected" | "pending",
    remarks?: string,
  ) {
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

  return (
    <div className="space-y-4">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      <Card>
        <CardHeader
          title="Documentary requirements"
          description={
            decided
              ? "This application has been decided. The documents below are read-only."
              : "Verify each documentary requirement before the application can be marked verified."
          }
          icon={Eye}
          action={
            application.review_started_at ? (
              <Badge tone="info">Review started {formatDateTime(application.review_started_at)}</Badge>
            ) : (
              <Button
                variant="secondary"
                disabled={disabled || decided || busy}
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
                        disabled={disabled || decided || busy}
                        onClick={() => handleVerify(document, "verified")}
                      >
                        <ThumbsUp className="h-3.5 w-3.5" />
                        Verify
                      </Button>

                      <Button
                        variant="outline"
                        disabled={disabled || decided || busy}
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
                          disabled={disabled || busy}
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
            {verifiedCount} of {REQUIRED_DOCUMENTS.length} documentary requirements verified.
          </p>
          {decided ? (
            <Badge tone={application.status === "approved" ? "approved" : "rejected"}>
              {application.status === "approved" ? "Approved" : "Rejected"}
            </Badge>
          ) : null}
        </div>
      </Card>

      {/* Reject document */}
      <Modal
        open={documentReject !== null}
        title="Reject document"
        description="The applicant is notified with the remark below."
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

export function ApplicationSummaryCard({
  application,
}: {
  application: FranchiseApplicationDetail;
}) {
  const rows: Array<[string, string | null | undefined]> = [
    ["Application number", application.application_number],
    ["Type", application.application_type === "renewal" ? "Renewal" : "New franchise"],
    ["Status", application.status],
    ["Stage", application.stage.replace(/_/g, " ")],
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
            <dd className="text-right font-medium capitalize text-ink">{value ?? "—"}</dd>
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
