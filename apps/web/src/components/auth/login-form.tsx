"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import Link from "next/link";
import { Eye, EyeOff, LogIn } from "lucide-react";

import { Alert, Button, Field } from "@/components/ui";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";

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

  if (isDemoMode()) {
    return (
      <div className="space-y-4">
        <Alert tone="warning" title="Preview mode">
          Supabase is not configured, so sign-in is disabled and the consoles run on bundled
          sample data. Every write action is blocked.
        </Alert>
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
      </div>
    );
  }

  async function signIn(event: React.FormEvent) {
    event.preventDefault();
    setError(null);
    setNotice(null);
    setLoading(true);

    const supabase = getBrowserClient();
    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim().toLowerCase(),
      password,
    });

    if (signInError) {
      setLoading(false);
      setError(
        signInError.message === "Invalid login credentials"
          ? "The e-mail address or password is incorrect."
          : signInError.message === "Email not confirmed"
            ? "Your e-mail address has not been confirmed yet. Check your inbox for the verification link."
            : signInError.message,
      );
      return;
    }

    // The profile decides where the session may go; RLS decides what it can see.
    const { data: profile } = await supabase
      .from("profiles")
      .select("role, account_status")
      .eq("auth_user_id", data.user.id)
      .maybeSingle();

    if (!profile) {
      setLoading(false);
      setError("No profile is linked to this account. Contact the municipal office.");
      return;
    }

    if (profile.account_status !== "active") {
      await supabase.auth.signOut();
      setLoading(false);
      setError(
        "This account is not active. Contact the administrator of the SBTF System at the municipal office.",
      );
      return;
    }

    if (profile.role !== "administrator" && profile.role !== "staff") {
      await supabase.auth.signOut();
      setLoading(false);
      setError(
        "Tricycle drivers and operators use the SBTF mobile application. The web console is for municipal staff and administrators only.",
      );
      return;
    }

    await supabase.rpc("rpc_log_activity", { p_action: "login" });

    const destination =
      nextPath && nextPath.startsWith("/") ? nextPath : profile.role === "administrator" ? "/admin" : "/staff";

    setNotice("Signed in. Loading your console…");
    router.push(destination);
    router.refresh();
  }

  return (
    <form className="space-y-4" onSubmit={signIn}>
      {error ? <Alert tone="danger">{error}</Alert> : null}
      {notice ? <Alert tone="success">{notice}</Alert> : null}

      <Field label="Official e-mail address" htmlFor="email">
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

      <Field label="Password" htmlFor="password">
        <div className="relative">
          <input
            id="password"
            className="sbtf-input pr-10"
            type={showPassword ? "text" : "password"}
            autoComplete="current-password"
            required
            minLength={8}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          <button
            type="button"
            className="absolute right-2 top-1/2 -translate-y-1/2 rounded p-1 text-muted hover:bg-page"
            onClick={() => setShowPassword((current) => !current)}
            aria-label={showPassword ? "Hide password" : "Show password"}
          >
            {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
          </button>
        </div>
      </Field>

      <Button type="submit" loading={loading} className="w-full">
        <LogIn className="h-4 w-4" />
        Sign in
      </Button>

      <p className="text-center text-[0.8125rem]">
        <Link className="text-primary hover:underline" href="/forgot-password">
          Forgot your password?
        </Link>
      </p>
    </form>
  );
}
