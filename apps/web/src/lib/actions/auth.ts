"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import {
  clearLoginFailures,
  getLoginLockStatus,
  loginAttemptKey,
  recordFailedLogin,
} from "@/lib/auth/login-guard";
import {
  clearRecoveryEmail,
  readRecoveryEmail,
  saveRecoveryEmail,
} from "@/lib/auth/recovery";
import { resolveWebAccess } from "@/lib/auth/web-access";
import type { ActionState, RecoveryCodeState, SignInState } from "@/lib/actions/types";

/**
 * Requests a password recovery for an e-mail address.
 *
 * The role-specific decision (administrator/active staff get a code, drivers
 * use a one-time password, pending staff wait for approval) is made inside the
 * `password-recovery` Edge Function, which is the only place that can read a
 * profile without a session. The reply is always the same generic message, so
 * this screen cannot be used to find out which addresses have accounts.
 *
 * On an accepted request the address is remembered in an httpOnly cookie for the
 * ten minutes the code is valid, so the next screen can ask for the digits
 * without putting the address in the URL.
 */
export async function requestPasswordRecoveryAction(email: string): Promise<ActionState> {
  if (isDemoMode()) {
    return {
      ok: false,
      message: "Password recovery is disabled in preview mode because Supabase is not connected.",
    };
  }

  const normalized = email.trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s.]+\.[^@\s]+$/.test(normalized)) {
    return { ok: false, message: "Enter a valid e-mail address." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("password-recovery", {
    body: { email: normalized },
  });

  if (error) {
    // Surface the real reason (404 not deployed, 401 Verify JWT still on,
    // 500 runtime error, or a fetch failure) instead of one fixed sentence.
    const status = (error as { context?: { status?: number } }).context?.status;
    return {
      ok: false,
      message:
        `The recovery service did not answer${status ? ` (HTTP ${status})` : ""}: ${error.message}. ` +
        "Check that the password-recovery Edge Function is deployed with Verify JWT disabled.",
    };
  }
  if (data?.error) {
    return { ok: false, message: String(data.message ?? data.error) };
  }

  await saveRecoveryEmail(normalized);

  return {
    ok: true,
    message: String(
      data?.message ??
      "If an account exists for that address, a verification code has been sent.",
    ),
  };
}

/**
 * Checks the 6-digit code GoTrue e-mailed and, on success, signs the visitor in.
 *
 * A verified recovery code *is* a session, which is why the next screen offers a
 * choice: continue to the console, or set a new password. The browser is trusted
 * only for the digits; GoTrue matches them against the account named in the
 * httpOnly cookie. The code is single-use and expires after ten minutes.
 */
export async function verifyRecoveryCodeAction(code: string): Promise<RecoveryCodeState> {
  if (isDemoMode()) {
    return {
      ok: false,
      message: "Password recovery is disabled in preview mode because Supabase is not connected.",
    };
  }

  const email = await readRecoveryEmail();
  if (!email) {
    return {
      ok: false,
      expired: true,
      message: "This code entry has expired. Request a new code from the password recovery screen.",
    };
  }

  const token = code.replace(/\D/g, "");
  if (token.length !== 6) {
    return { ok: false, message: "Enter the 6-digit code from the e-mail." };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.verifyOtp({
    email,
    token,
    type: "recovery",
  });

  if (error || !data.user) {
    // Keep the pending address: a mistyped digit should not restart the flow.
    return {
      ok: false,
      message:
        "That code is incorrect or has expired. Check the six digits, or send a new code.",
    };
  }

  const access = await resolveWebAccess(supabase, data.user.id);
  if (!access.ok) {
    await supabase.auth.signOut();
    return { ok: false, message: access.message };
  }

  await clearRecoveryEmail();
  await supabase.rpc("rpc_log_activity", { p_action: "login" });

  // The session exists now; the choice screen decides what happens next.
  // Redirecting from the action keeps the browser and the new cookies in step.
  redirect("/recovery-choice");
}

/** Sends a fresh code to the address already waiting on the verification screen. */
export async function resendRecoveryCodeAction(): Promise<RecoveryCodeState> {
  if (isDemoMode()) {
    return {
      ok: false,
      message: "Password recovery is disabled in preview mode because Supabase is not connected.",
    };
  }

  const email = await readRecoveryEmail();
  if (!email) {
    return {
      ok: false,
      expired: true,
      message: "Request a new code from the password recovery screen.",
    };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("password-recovery", {
    body: { email },
  });

  if (error) {
    const status = (error as { context?: { status?: number } }).context?.status;
    return {
      ok: false,
      message:
        `The recovery service did not answer${status ? ` (HTTP ${status})` : ""}: ${error.message}. ` +
        "Check that the password-recovery Edge Function is deployed with Verify JWT disabled.",
    };
  }
  if (data?.error) {
    return { ok: false, message: String(data.message ?? data.error) };
  }

  // Restart the ten-minute window alongside the new code.
  await saveRecoveryEmail(email);

  return {
    ok: true,
    message: `A new code has been sent to ${email}. It expires in 10 minutes.`,
  };
}

/** Ends the session and returns to the sign-in screen. */
export async function signOutAction(): Promise<void> {
  if (!isDemoMode()) {
    const supabase = await createClient();
    const { data } = await supabase.auth.getUser();
    if (data.user) {
      await supabase.rpc("rpc_log_activity", { p_action: "logout" });
    }
    await supabase.auth.signOut();
  }
  redirect("/login");
}

/**
 * Signs a staff member or administrator in.
 *
 * Sign-in lives on the server so the five-attempt lockout cannot be bypassed by
 * clearing site data or calling Supabase directly: the counter is held in the
 * server process and the submitted password is never trusted to the browser's
 * own state. Supabase still issues the session cookies, which this action
 * writes through the server client.
 */
export async function signInAction(
  email: string,
  password: string,
  nextPath?: string | null,
): Promise<SignInState> {
  if (isDemoMode()) {
    return {
      ok: false,
      message: "Sign-in is disabled in preview mode because Supabase is not connected.",
    };
  }

  const normalized = email.trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s.]+\.[^@\s]+$/.test(normalized)) {
    return { ok: false, message: "Enter a valid e-mail address." };
  }
  if (password.length === 0) {
    return { ok: false, message: "Enter your password." };
  }

  const key = loginAttemptKey(normalized, await clientIp());

  const lock = getLoginLockStatus(key);
  if (lock.locked) {
    return lockedResult(lock.retryAfterSeconds);
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email: normalized,
    password,
  });

  if (error) {
    // Only a genuinely wrong password counts towards the lockout. Network
    // failures, rate limits and unconfirmed addresses must not lock the form.
    if (error.message === "Invalid login credentials") {
      const status = recordFailedLogin(key);
      if (status.locked) {
        return lockedResult(status.retryAfterSeconds);
      }

      return {
        ok: false,
        remainingAttempts: status.remainingAttempts,
        message:
          "The e-mail address or password is incorrect. " +
          `${status.remainingAttempts} ${status.remainingAttempts === 1 ? "attempt" : "attempts"} ` +
          "remaining before sign-in is temporarily locked.",
      };
    }

    if (error.message === "Email not confirmed") {
      return {
        ok: false,
        message:
          "Your e-mail address has not been confirmed yet. Check your inbox for the verification link.",
      };
    }

    return { ok: false, message: error.message };
  }

  if (!data.user) {
    return {
      ok: false,
      message: "Sign-in did not return a user. Try again or contact the municipal office.",
    };
  }

  // The profile decides where the session may go; RLS decides what it can see.
  const access = await resolveWebAccess(supabase, data.user.id);
  if (!access.ok) {
    await supabase.auth.signOut();
    clearLoginFailures(key);
    return { ok: false, message: access.message };
  }

  clearLoginFailures(key);
  await supabase.rpc("rpc_log_activity", { p_action: "login" });

  return {
    ok: true,
    message: "Signed in. Loading your dashboard…",
    destination:
      safeNextPath(nextPath) ?? (access.role === "administrator" ? "/admin" : "/staff"),
  };
}

/** Client IP used to scope the lockout. Trusts the standard proxy headers. */
async function clientIp(): Promise<string> {
  const headerList = await headers();
  const forwarded = headerList.get("x-forwarded-for")?.split(",")[0]?.trim();
  if (forwarded) return forwarded;
  return headerList.get("x-real-ip")?.trim() || "unknown";
}

/** Only allow same-origin absolute paths; reject protocol-relative URLs. */
function safeNextPath(nextPath?: string | null): string | null {
  if (!nextPath || !nextPath.startsWith("/") || nextPath.startsWith("//")) return null;
  return nextPath;
}

function lockedResult(retryAfterSeconds: number): SignInState {
  const minutes = Math.max(1, Math.ceil(retryAfterSeconds / 60));
  return {
    ok: false,
    locked: true,
    retryAfterSeconds,
    remainingAttempts: 0,
    message:
      `Too many incorrect sign-in attempts. Sign-in is locked for ${minutes} more ` +
      `${minutes === 1 ? "minute" : "minutes"}.`,
  };
}
