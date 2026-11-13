"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Eye, FileCheck2, Printer, Undo2 } from "lucide-react";

import { Alert, Button, Field, LinkButton } from "@/components/ui";
import { Modal } from "@/components/dialog";
import {
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
  convertedApplicationId = null,
  readOnly = false,
}: {
  formRequestId: string;
  status: FormRequestStatus;
  printed?: boolean;
  convertedApplicationId?: string | null;
  readOnly?: boolean;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [reason, setReason] = useState("");

  const disabled = readOnly || isDemoMode();

  function refresh(result: { ok: boolean; message: string }) {
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) {
      setRejectOpen(false);
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
          {status === "converted" && convertedApplicationId ? (
            <LinkButton variant="outline" href={`/staff/applications/${convertedApplicationId}`}>
              <Eye className="h-4 w-4" />
              View
            </LinkButton>
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
    </div>
  );
}
