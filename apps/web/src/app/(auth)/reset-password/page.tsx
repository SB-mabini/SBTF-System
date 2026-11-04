import { redirect } from "next/navigation";

import { ResetPasswordForm } from "@/components/auth/reset-password-form";
import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";

export const metadata = { title: "Set a new password — SBTF System" };

/**
 * Reached in two ways, both of which already established a session:
 *
 *   - a verified 6-digit recovery code, via /recovery-choice;
 *   - an administrator-issued setup link, via /auth/confirm.
 *
 * The guard is server-side so the form never renders for a visitor without a
 * session, and so there is no "open the link in the same browser" placeholder to
 * misread as an expired link.
 */
export default async function ResetPasswordPage() {
  if (!isDemoMode()) {
    const supabase = await createClient();
    const { data } = await supabase.auth.getUser();
    if (!data.user) redirect("/forgot-password");
  }

  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Set a new password</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          Choose a password you do not use for another service.
        </p>
        <div className="mt-6">
          <ResetPasswordForm />
        </div>
      </div>
    </div>
  );
}
