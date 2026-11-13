"use client";

import { useState } from "react";
import { KeyRound } from "lucide-react";

import { Alert, Button, Card, CardHeader, Field } from "@/components/ui";
import { changePasswordAction } from "@/lib/actions/profile";
import { isDemoMode } from "@/lib/env";

export function ChangePasswordForm() {
  const readOnly = isDemoMode();
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  async function submit() {
    if (busy) return;
    setBusy(true);
    setMessage(null);
    const result = await changePasswordAction({
      currentPassword,
      newPassword,
      confirmPassword,
    });
    setBusy(false);
    setMessage({ ok: result.ok, text: result.message });
    if (result.ok) {
      setCurrentPassword("");
      setNewPassword("");
      setConfirmPassword("");
    }
  }

  const mismatch = confirmPassword.length > 0 && newPassword !== confirmPassword;

  return (
    <Card>
      <CardHeader
        title="Change password"
        description="Your current password is required. Passwords are held only by Supabase Auth and are never stored in this application."
        icon={KeyRound}
      />

      {message ? (
        <div className="mb-4">
          <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
        </div>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-3">
        <Field label="Current password" htmlFor="current-password">
          <input
            id="current-password"
            type="password"
            autoComplete="current-password"
            className="sbtf-input"
            value={currentPassword}
            onChange={(event) => setCurrentPassword(event.target.value)}
          />
        </Field>
        <Field
          label="New password"
          htmlFor="new-password"
          hint="At least 8 characters."
        >
          <input
            id="new-password"
            type="password"
            autoComplete="new-password"
            className="sbtf-input"
            value={newPassword}
            onChange={(event) => setNewPassword(event.target.value)}
          />
        </Field>
        <Field
          label="Confirm new password"
          htmlFor="confirm-password"
          error={mismatch ? "Passwords do not match." : undefined}
        >
          <input
            id="confirm-password"
            type="password"
            autoComplete="new-password"
            className="sbtf-input"
            value={confirmPassword}
            onChange={(event) => setConfirmPassword(event.target.value)}
            aria-invalid={mismatch}
          />
        </Field>
      </div>

      <div className="mt-4">
        <Button onClick={submit} loading={busy} disabled={readOnly || mismatch}>
          <KeyRound className="h-4 w-4" />
          Update password
        </Button>
      </div>
    </Card>
  );
}
