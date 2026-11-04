"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { Alert, Button, Field } from "@/components/ui";
import { resendRecoveryCodeAction, verifyRecoveryCodeAction } from "@/lib/actions/auth";

/**
 * How long the "Resend code" control stays disabled.
 *
 * GoTrue will not send another message for the same address within
 * `smtp_max_frequency` (60 seconds), so offering it sooner would only produce a
 * silent no-op and a confusing "sent" message.
 */
const RESEND_COOLDOWN_SECONDS = 60;

export function VerifyOtpForm() {
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [cooldown, setCooldown] = useState(RESEND_COOLDOWN_SECONDS);
  const [expired, setExpired] = useState(false);

  // Countdown for the resend control; restarts only when a new code is sent.
  useEffect(() => {
    if (cooldown === 0) return;
    const timer = window.setTimeout(() => setCooldown((current) => Math.max(0, current - 1)), 1000);
    return () => window.clearTimeout(timer);
  }, [cooldown]);

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setLoading(true);

    try {
      const result = await verifyRecoveryCodeAction(code);
      // On success the action redirects to /recovery-choice, so there is no
      // success branch to render here.
      if (result?.ok === false) {
        setError(result.message);
        setExpired(Boolean(result.expired));
        setCode("");
      }
    } catch {
      setError("The code could not be checked. Check your connection and try again.");
    } finally {
      setLoading(false);
    }
  }

  async function resend() {
    setError(null);
    setNotice(null);
    setResending(true);

    try {
      const result = await resendRecoveryCodeAction();
      if (!result.ok) {
        setError(result.message);
        setExpired(Boolean(result.expired));
        return;
      }
      setCode("");
      setNotice(result.message);
      setCooldown(RESEND_COOLDOWN_SECONDS);
    } catch {
      setError("A new code could not be requested. Check your connection and try again.");
    } finally {
      setResending(false);
    }
  }

  return (
    <form className="space-y-4" onSubmit={submit}>
      {error ? <Alert tone="danger">{error}</Alert> : null}
      {notice ? <Alert tone="success">{notice}</Alert> : null}

      <Field
        label="6-digit code"
        htmlFor="code"
        hint="Numbers only. The code is in the e-mail we just sent."
      >
        <input
          id="code"
          className="sbtf-input text-center text-lg font-semibold tracking-[0.4em] tabular-nums"
          type="text"
          inputMode="numeric"
          autoComplete="one-time-code"
          autoFocus
          required
          maxLength={6}
          pattern="[0-9]{6}"
          disabled={expired}
          aria-disabled={expired}
          value={code}
          onChange={(event) => setCode(event.target.value.replace(/\D/g, "").slice(0, 6))}
        />
      </Field>

      <Button type="submit" loading={loading} disabled={expired || code.length !== 6} className="w-full">
        Continue
      </Button>

      {expired ? (
        <p className="text-center text-[0.8125rem]">
          <Link className="text-primary hover:underline" href="/forgot-password">
            Request a new code
          </Link>
        </p>
      ) : (
        <div className="flex items-center justify-between gap-3 text-[0.8125rem]">
          <Link className="text-primary hover:underline" href="/forgot-password">
            Use a different e-mail
          </Link>
          <button
            type="button"
            className="text-primary hover:underline disabled:cursor-not-allowed disabled:text-muted"
            onClick={resend}
            disabled={resending || cooldown > 0 || loading}
          >
            {cooldown > 0 ? `Resend in ${cooldown}s` : resending ? "Sending…" : "Resend code"}
          </button>
        </div>
      )}
    </form>
  );
}
