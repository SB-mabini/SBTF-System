"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { Alert, Button, Field } from "@/components/ui";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";

/**
 * Sets a new password for the session that already exists.
 *
 * Reaching this form requires a verified recovery code or an administrator-issued
 * password-reset link; both leave a session behind, and the server page refuses
 * to render without one. There is therefore no "open the link first" state to
 * handle here. New staff invitations use /accept-invitation instead.
 */
export function ResetPasswordForm() {
  const router = useRouter();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [loading, setLoading] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);

    if (password.length < 8) {
      setError("Use at least 8 characters.");
      return;
    }
    if (password !== confirm) {
      setError("The two passwords do not match.");
      return;
    }

    setLoading(true);
    const supabase = getBrowserClient();
    const { error: updateError } = await supabase.auth.updateUser({ password });
    setLoading(false);

    if (updateError) {
      setError(updateError.message);
      return;
    }

    await supabase.rpc("rpc_log_activity", { p_action: "security_event" });
    setDone(true);
    // The session survives the change, so "/" routes to the console that
    // matches the account's role.
    setTimeout(() => {
      router.push("/");
      router.refresh();
    }, 2500);
  }

  if (isDemoMode()) {
    return (
      <Alert tone="warning" title="Preview mode">
        Password reset is disabled because Supabase is not configured.
      </Alert>
    );
  }

  if (done) {
    return (
      <Alert tone="success" title="Password updated">
        Your password has been changed. Opening your console…
      </Alert>
    );
  }

  return (
    <form className="space-y-4" onSubmit={submit}>
      {error ? <Alert tone="danger">{error}</Alert> : null}

      <Field label="New password" htmlFor="password" hint="At least 8 characters.">
        <input
          id="password"
          className="sbtf-input"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
      </Field>

      <Field label="Confirm new password" htmlFor="confirm">
        <input
          id="confirm"
          className="sbtf-input"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          value={confirm}
          onChange={(event) => setConfirm(event.target.value)}
        />
      </Field>

      <Button type="submit" loading={loading} className="w-full">
        Update password
      </Button>
    </form>
  );
}
