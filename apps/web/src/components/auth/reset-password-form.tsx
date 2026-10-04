"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";

import { Alert, Button, Field } from "@/components/ui";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";

export function ResetPasswordForm() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [email, setEmail] = useState<string | null>(null);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (isDemoMode()) return;
    const supabase = getBrowserClient();
    // The recovery link signs the visitor in with a short-lived token; the page
    // then only needs to set a new password.
    supabase.auth.getUser().then(({ data }) => {
      if (data.user) {
        setEmail(data.user.email ?? null);
        setReady(true);
      }
    });
  }, []);

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
    setTimeout(() => router.push("/login"), 2500);
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
        Your password has been changed. Redirecting to the sign-in screen…
      </Alert>
    );
  }

  if (!ready) {
    return (
      <div className="space-y-3">
        <Alert tone="warning" title="Recovery link required">
          Open this page from the password recovery e-mail. The link can be used once and expires
          quickly.
        </Alert>
        <Link className="text-[0.8125rem] text-primary hover:underline" href="/forgot-password">
          Request a new recovery link
        </Link>
      </div>
    );
  }

  return (
    <form className="space-y-4" onSubmit={submit}>
      <p className="text-[0.8125rem] text-muted">
        Setting a new password for <strong className="text-ink">{email}</strong>.
      </p>

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
