"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Archive, ArchiveRestore } from "lucide-react";

import { Alert, Button, Field } from "@/components/ui";
import { Modal } from "@/components/dialog";
import { archiveRecordAction } from "@/lib/actions/applications";
import { isDemoMode } from "@/lib/env";

export function ArchiveActions({
  recordId,
  archived,
}: {
  recordId: string;
  archived: boolean;
}) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const readOnly = isDemoMode();

  async function submit() {
    setBusy(true);
    const result = await archiveRecordAction({
      recordId,
      reason: archived ? "" : reason.trim(),
      archived: !archived,
    });
    setBusy(false);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) {
      setOpen(false);
      setReason("");
      startTransition(() => router.refresh());
    }
  }

  return (
    <div className="space-y-3">
      {message ? <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert> : null}

      {archived ? (
        <Button variant="outline" disabled={readOnly} onClick={() => setOpen(true)}>
          <ArchiveRestore className="h-4 w-4" />
          Restore franchise
        </Button>
      ) : (
        <Button variant="danger" disabled={readOnly} onClick={() => setOpen(true)}>
          <Archive className="h-4 w-4" />
          Archive franchise
        </Button>
      )}

      <p className="text-[0.75rem] text-muted">
        Archiving changes the operational status only. The issued franchise number, validity dates
        and verification code stay exactly as issued, because they are part of the documentary
        record.
      </p>

      <Modal
        open={open}
        title={archived ? "Restore this franchise" : "Archive this franchise"}
        description={
          archived
            ? "The franchise becomes active again and can be renewed."
            : "The operator is notified and the reason is written to the activity log."
        }
        onClose={() => setOpen(false)}
        footer={
          <>
            <Button variant="outline" onClick={() => setOpen(false)} disabled={busy}>
              Cancel
            </Button>
            <Button
              variant={archived ? "primary" : "danger"}
              loading={busy}
              disabled={!archived && reason.trim().length < 5}
              onClick={submit}
            >
              {archived ? "Restore" : "Archive"}
            </Button>
          </>
        }
      >
        {!archived ? (
          <Field label="Reason for archiving (required, at least 5 characters)" htmlFor="archive-reason">
            <textarea
              id="archive-reason"
              className="sbtf-input min-h-[90px]"
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="For example: franchise revoked by resolution of the Sangguniang Bayan."
            />
          </Field>
        ) : (
          <p className="text-[0.875rem] text-muted">
            Restoring clears the archive reason. The history of the archive event remains in the
            activity log.
          </p>
        )}
      </Modal>
    </div>
  );
}
