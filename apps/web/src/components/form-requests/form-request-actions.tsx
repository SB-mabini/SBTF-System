"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { FileCheck2, Link2, Printer, Undo2 } from "lucide-react";

import { Alert, Button, Field } from "@/components/ui";
import { Modal } from "@/components/dialog";
import {
  convertFormRequestAction,
  issueFormRequestAction,
  markFormRequestPrintedAction,
  rejectFormRequestAction,
} from "@/lib/actions/form-requests";
import { isDemoMode } from "@/lib/env";
import type { FormRequestStatus } from "@/types/database";

export function FormRequestActions({
  formRequestId,
  status,
  printed = false,
  readOnly = false,
}: {
  formRequestId: string;
  status: FormRequestStatus;
  printed?: boolean;
  readOnly?: boolean;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [convertOpen, setConvertOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [applicationNumber, setApplicationNumber] = useState("");
  const [reason, setReason] = useState("");

  const disabled = readOnly || isDemoMode();

  function refresh(result: { ok: boolean; message: string }) {
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) {
      setConvertOpen(false);
      setRejectOpen(false);
      setApplicationNumber("");
      setReason("");
      startTransition(() => router.refresh());
    }
  }

  async function handleIssue() {
    setBusy(true);
    refresh(await issueFormRequestAction(formRequestId));
  }

  async function handleReject() {
    setBusy(true);
    refresh(await rejectFormRequestAction({ formRequestId, reason }));
  }

  async function handlePrint() {
    setBusy(true);
    refresh(await markFormRequestPrintedAction(formRequestId));
  }

  async function handleConvert() {
    setBusy(true);
    refresh(await convertFormRequestAction({ formRequestId, applicationNumber }));
  }

  if (status !== "requested" && status !== "issued" && status !== "converted") return null;

  return (
    <div className="space-y-2">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      {status === "requested" ? (
        <div className="flex flex-wrap gap-2">
          <Button variant="secondary" disabled={disabled || busy} loading={busy} onClick={handleIssue}>
            <FileCheck2 className="h-4 w-4" />
            Approve &amp; issue form
          </Button>
          <Button
            variant="outline"
            disabled={disabled || busy}
            onClick={() => setRejectOpen(true)}
          >
            <Undo2 className="h-4 w-4" />
            Return for changes
          </Button>
        </div>
      ) : (
        <div className="flex flex-wrap gap-2">
          {!printed ? (
            <Button variant="secondary" disabled={disabled || busy} loading={busy} onClick={handlePrint}>
              <Printer className="h-4 w-4" />
              Mark as printed
            </Button>
          ) : null}
          {status === "issued" ? (
            <Button variant="outline" disabled={disabled || busy} onClick={() => setConvertOpen(true)}>
              <Link2 className="h-4 w-4" />
              Link to application
            </Button>
          ) : null}
        </div>
      )}

      <Modal
        open={rejectOpen}
        title="Return form request for changes"
        description="The driver is notified with this reason and can edit and resubmit the same request."
        onClose={() => setRejectOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setRejectOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              disabled={reason.trim().length < 10}
              onClick={handleReject}
            >
              Return request
            </Button>
          </>
        }
      >
        <Field label="Reason (required, at least 10 characters)" htmlFor="reject-reason">
          <textarea
            id="reject-reason"
            className="sbtf-input min-h-28"
            value={reason}
            maxLength={1000}
            onChange={(event) => setReason(event.target.value)}
            placeholder="For example: The OR/CR photo is blurry. Please upload a clearer copy."
          />
        </Field>
      </Modal>

      <Modal
        open={convertOpen}
        title="Link form request to an application"
        description="Enter the application number the submitted form belongs to."
        onClose={() => setConvertOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setConvertOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              loading={busy}
              disabled={applicationNumber.trim().length === 0}
              onClick={handleConvert}
            >
              Link
            </Button>
          </>
        }
      >
        <Field label="Application number (required)" htmlFor="application-number">
          <input
            id="application-number"
            className="sbtf-input"
            value={applicationNumber}
            onChange={(event) => setApplicationNumber(event.target.value)}
            placeholder="For example: APP-2026-000123"
          />
        </Field>
      </Modal>
    </div>
  );
}
