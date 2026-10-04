"use client";

import Link from "next/link";
import { useState } from "react";

import { Alert, Button, Field } from "@/components/ui";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode, SITE_URL } from "@/lib/env";

export function ForgotPasswordForm() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
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

    const supabase = getBrowserClient();
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
      { redirectTo: `${SITE_URL}/reset-password` },
    );

    setLoading(false);
    if (resetError) {
      setError(resetError.message);
      return;
    }
    setSent(true);
  }

  if (sent) {
    return (
      <div className="space-y-4">
        <Alert tone="success" title="Check your inbox">
          If an account exists for <strong>{email}</strong>, Supabase Auth has sent a password
          recovery link. The link expires after a short time and can only be used once.
        </Alert>
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
        hint="A recovery link is sent to this address if it belongs to an account."
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
        Send recovery link
      </Button>

      <p className="text-center text-[0.8125rem]">
        <Link className="text-primary hover:underline" href="/login">
          Back to sign in
        </Link>
      </p>
    </form>
  );
}
