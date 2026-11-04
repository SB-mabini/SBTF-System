"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useEffect, useState } from "react";
import Link from "next/link";
import { Eye, EyeOff, LogIn } from "lucide-react";

import { Alert, Button, Field } from "@/components/ui";
import { signInAction } from "@/lib/actions/auth";
import { isDemoMode } from "@/lib/env";

function formatCountdown(totalSeconds: number): string {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${String(seconds).padStart(2, "0")}`;
}

export function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const nextPath = searchParams.get("next");

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [lockedUntil, setLockedUntil] = useState<number | null>(null);
  const [remainingSeconds, setRemainingSeconds] = useState(0);

  // Preview mode never replaces the form: a hidden sign-in reads as "not
  // implemented". The real form is rendered underneath the banner, disabled, so
  // it is visibly the same screen a connected deployment serves.
  const demo = isDemoMode();
  const locked = remainingSeconds > 0;

  // The lock is enforced by the server action. This timer only renders the
  // countdown and re-enables the form once the server will accept an attempt.
  useEffect(() => {
    if (lockedUntil === null) return;

    const timer = window.setInterval(() => {
      const seconds = Math.max(0, Math.ceil((lockedUntil - Date.now()) / 1000));
      setRemainingSeconds(seconds);
      if (seconds === 0) setLockedUntil(null);
    }, 1000);

    return () => window.clearInterval(timer);
  }, [lockedUntil]);

  function applyLock(seconds: number) {
    if (seconds <= 0) return;
    setRemainingSeconds(seconds);
    setLockedUntil(Date.now() + seconds * 1000);
  }

  async function signIn(event: React.FormEvent) {
    event.preventDefault();
    if (locked) return;

    setError(null);
    setNotice(null);
    setLoading(true);

    try {
      const result = await signInAction(email, password, nextPath);

      if (result.locked) {
        applyLock(result.retryAfterSeconds ?? 0);
        setPassword("");
        return;
      }

      if (!result.ok) {
        setError(result.message);
        return;
      }

      setNotice(result.message);
      if (result.destination) {
        router.push(result.destination);
        router.refresh();
      }
    } catch {
      setError("Sign-in could not be completed. Check your connection and try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="space-y-4" onSubmit={signIn}>
      {demo ? (
        <Alert tone="warning" title="Preview mode">
          Supabase is not connected, so sign-in is shown but disabled. The consoles run on bundled
          sample data and every write action is blocked. Use the preview links below instead.
        </Alert>
      ) : null}

      {locked ? (
        <Alert tone="warning" title="Sign-in temporarily locked">
          Too many incorrect password attempts. For your security, try again in{" "}
          <span className="font-semibold tabular-nums">{formatCountdown(remainingSeconds)}</span>.
        </Alert>
      ) : null}

      {error ? <Alert tone="danger">{error}</Alert> : null}
      {notice ? <Alert tone="success">{notice}</Alert> : null}

      <Field label="Official e-mail address" htmlFor="email">
        <input
          id="email"
          className="sbtf-input"
          type="email"
          autoComplete="username"
          required
          disabled={demo || locked}
          aria-disabled={demo || locked}
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="name@mabini.gov.ph"
        />
      </Field>

      <Field label="Password" htmlFor="password">
        <div className="relative">
          <input
            id="password"
            className="sbtf-input pr-10"
            type={showPassword ? "text" : "password"}
            autoComplete="current-password"
            required
            minLength={8}
            disabled={demo || locked}
            aria-disabled={demo || locked}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          <button
            type="button"
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-muted hover:bg-page"
            onClick={() => setShowPassword((current) => !current)}
            disabled={demo || locked}
            aria-label={showPassword ? "Hide password" : "Show password"}
          >
            {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
          </button>
        </div>
      </Field>

      <Button type="submit" loading={loading} disabled={demo || locked} className="w-full">
        <LogIn className="h-4 w-4" />
        Sign in
      </Button>

      {demo ? (
        <div className="grid gap-2 sm:grid-cols-2">
          <Link
            className="inline-flex items-center justify-center rounded-lg bg-primary px-3.5 py-2 text-[0.8125rem] font-medium text-white hover:bg-primary-600"
            href="/admin?as=admin"
          >
            Preview administrator console
          </Link>
          <Link
            className="inline-flex items-center justify-center rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
            href="/staff?as=staff"
          >
            Preview staff console
          </Link>
        </div>
      ) : (
        <p className="text-center text-[0.8125rem]">
          <Link className="text-primary hover:underline" href="/forgot-password">
            Forgot your password?
          </Link>
        </p>
      )}
    </form>
  );
}
