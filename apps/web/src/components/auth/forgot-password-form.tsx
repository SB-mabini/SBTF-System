"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { Alert, Button, Field } from "@/components/ui";
import { requestPasswordRecoveryAction } from "@/lib/actions/auth";
import { isDemoMode } from "@/lib/env";

export function ForgotPasswordForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
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

    try {
      const result = await requestPasswordRecoveryAction(email);

      if (!result.ok) {
        setError(result.message);
        return;
      }

      // The action stored the address in an httpOnly cookie, so the next screen
      // only has to ask for the six digits.
      router.push("/verify-otp");
    } catch {
      setError("The request could not be sent. Check your connection and try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="space-y-4" onSubmit={submit}>
      {error ? <Alert tone="danger">{error}</Alert> : null}

      <Field
        label="Official e-mail address"
        htmlFor="email"
        hint="A 6-digit code is sent to this address if it belongs to an account."
      >
        <input
          id="email"
          className="sbtf-input"
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="name@mabini.gov.ph"
        />
      </Field>

      <Button type="submit" loading={loading} className="w-full">
        Send verification code
      </Button>

      <p className="text-center text-[0.8125rem]">
        <Link className="text-primary hover:underline" href="/login">
          Back to sign in
        </Link>
      </p>
    </form>
  );
}
