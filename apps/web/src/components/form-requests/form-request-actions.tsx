"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { FileCheck2, Link2 } from "lucide-react";

import { Alert, Button, Field } from "@/components/ui";
import { Modal } from "@/components/dialog";
import { convertFormRequestAction, issueFormRequestAction } from "@/lib/actions/form-requests";
import { isDemoMode } from "@/lib/env";
import type { FormRequestStatus } from "@/types/database";

export function FormRequestActions({
  formRequestId,
  status,
  readOnly = false,
}: {
  formRequestId: string;
  status: FormRequestStatus;
  readOnly?: boolean;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [convertOpen, setConvertOpen] = useState(false);
  const [applicationNumber, setApplicationNumber] = useState("");

  const disabled = readOnly || isDemoMode();

  function refresh(result: { ok: boolean; message: string }) {
    setMessage({ ok: result.ok, text: result.message });
    setBusy(false);
    if (result.ok) {
      setConvertOpen(false);
      setApplicationNumber("");
      startTransition(() => router.refresh());
    }
  }

  async function handleIssue() {
    setBusy(true);
    refresh(await issueFormRequestAction(formRequestId));
  }

  async function handleConvert() {
    setBusy(true);
    refresh(await convertFormRequestAction({ formRequestId, applicationNumber }));
  }

  if (status !== "requested" && status !== "issued") return null;

  return (
    <div className="space-y-2">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      {status === "requested" ? (
        <Button variant="secondary" disabled={disabled || busy} loading={busy} onClick={handleIssue}>
          <FileCheck2 className="h-4 w-4" />
          Issue form
        </Button>
      ) : (
        <Button variant="outline" disabled={disabled || busy} onClick={() => setConvertOpen(true)}>
          <Link2 className="h-4 w-4" />
          Link to application
        </Button>
      )}

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
