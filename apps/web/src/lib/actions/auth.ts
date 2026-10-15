"use server";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";
import type { ActionState } from "@/lib/actions/types";

/**
 * Requests a password recovery for an e-mail address.
 *
 * The role-specific decision (administrator/staff get a link, drivers use a
 * one-time password, pending staff wait for approval) is made inside the
 * `password-recovery` Edge Function, which is the only place that can read a
 * profile without a session. The reply is always the same generic message, so
 * this screen cannot be used to find out which addresses have accounts.
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

  return {
    ok: true,
    message: String(
      data?.message ??
        "If an account exists for that address, recovery instructions have been sent.",
    ),
  };
}
