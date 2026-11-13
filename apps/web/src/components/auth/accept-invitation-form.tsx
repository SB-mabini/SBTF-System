"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

import { Alert, Button, Field } from "@/components/ui";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";

/**
 * Sets the password for a staff account created by an administrator.
 *
 * The session was established by /auth/confirm after it verified the invitation
 * token, so this form never has to consume a link itself. Unlike the recovery
 * form, it signs the visitor out afterwards: an invitation is the first sign-in,
 * and the next step should be the normal /login screen with the new password.
 */
export function AcceptInvitationForm() {
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

    if (updateError) {
      setLoading(false);
      setError(updateError.message);
      return;
    }

    // Clear the invitation session so the next step really is a sign-in with
    // the new password, not an already-open console.
    await supabase.auth.signOut();
    setLoading(false);
    setDone(true);

    setTimeout(() => {
      router.replace("/login?notice=password-set");
      router.refresh();
    }, 1200);
  }

  if (isDemoMode()) {
    return (
      <Alert tone="warning" title="Preview mode">
        Accepting an invitation is disabled because Supabase is not configured.
      </Alert>
    );
  }

  if (done) {
    return (
      <Alert tone="success" title="Password set">
        Your password has been saved. Taking you to the sign-in screen…
      </Alert>
    );
  }

  return (
    <form className="space-y-4" onSubmit={submit}>
      {error ? <Alert tone="danger">{error}</Alert> : null}

      <Field label="New password" htmlFor="invite-password" hint="At least 8 characters.">
        <input
          id="invite-password"
          className="sbtf-input"
          type="password"
          autoComplete="new-password"
          required
          minLength={8}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
        />
      </Field>

      <Field label="Confirm new password" htmlFor="invite-confirm">
        <input
          id="invite-confirm"
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
        Save password and continue
      </Button>
    </form>
  );
}
