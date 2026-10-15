"use client";

import Link from "next/link";
import { useState } from "react";

import { Alert, Button, Field } from "@/components/ui";
import { requestPasswordRecoveryAction } from "@/lib/actions/auth";
import { isDemoMode } from "@/lib/env";

export function ForgotPasswordForm() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (isDemoMode()) {
    return (
      <Alert tone="warning" title="Preview mode">
        Password recovery is disabled because Supabase is not configured.
      </Alert>
    );
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setLoading(true);
    setError(null);

    const result = await requestPasswordRecoveryAction(email);

    setLoading(false);
    if (!result.ok) {
      setError(result.message);
      return;
    }
    setNotice(result.message);
    setSent(true);
  }

  if (sent) {
    return (
      <div className="space-y-4">
        <Alert tone="success" title="Request accepted">
          {notice ??
            "If an account exists for that address, recovery instructions have been sent."}
        </Alert>
        <p className="text-[0.8125rem] text-muted">
          Administrators and approved staff receive a recovery link by e-mail. Staff accounts that
          are still awaiting approval cannot be recovered until an administrator approves them.
          Drivers and operators sign in with a one-time password in the SBTF mobile app.
        </p>
        <Link className="text-[0.8125rem] text-primary hover:underline" href="/login">
          Back to sign in
        </Link>
      </div>
    );
  }

  return (
    <form className="space-y-4" onSubmit={submit}>
      {error ? <Alert tone="danger">{error}</Alert> : null}

      <Field
        label="Official e-mail address"
        htmlFor="email"
        hint="Recovery instructions are sent to this address if it belongs to an account."
      >
        <input
          id="email"
          className="sbtf-input"
          type="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
        />
      </Field>

      <Button type="submit" loading={loading} className="w-full">
        Send recovery instructions
      </Button>

      <p className="text-center text-[0.8125rem]">
        <Link className="text-primary hover:underline" href="/login">
          Back to sign in
        </Link>
      </p>
    </form>
  );
}
