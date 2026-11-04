import { redirect } from "next/navigation";

import { VerifyOtpForm } from "@/components/auth/verify-otp-form";
import { readRecoveryEmail } from "@/lib/auth/recovery";
import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";

export const metadata = { title: "Enter your verification code — SBTF System" };

/**
 * Step two of password recovery: type the code that was e-mailed.
 *
 * The address lives in an httpOnly cookie for the ten minutes the code is valid,
 * so it is never placed in the URL. A visitor who lands here without one has
 * either already finished or never started: a session means they are signed in,
 * so send them to their console; otherwise back to the recovery screen.
 */
export default async function VerifyOtpPage() {
  if (isDemoMode()) redirect("/forgot-password");

  const email = await readRecoveryEmail();

  if (!email) {
    const supabase = await createClient();
    const { data } = await supabase.auth.getUser();
    redirect(data.user ? "/" : "/forgot-password");
  }

  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Enter your verification code</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          We sent a 6-digit code to <strong className="break-all text-ink">{email}</strong>. It
          expires in 10 minutes.
        </p>

        <div className="mt-6">
          <VerifyOtpForm />
        </div>
      </div>

      <p className="mt-4 text-center text-[0.75rem] text-muted">
        The code works once. If you did not request it, ignore the e-mail — your password stays
        unchanged.
      </p>
    </div>
  );
}
