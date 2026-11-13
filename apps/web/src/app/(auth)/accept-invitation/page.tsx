import { redirect } from "next/navigation";

import { AcceptInvitationForm } from "@/components/auth/accept-invitation-form";
import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";

export const metadata = { title: "Set your password — SBTF System" };

/**
 * Reached only after /auth/confirm has verified an invitation token
 * (`type=invite`), which leaves a session behind. The guard is server-side so
 * the panel never renders without that verified session; an expired or reused
 * link is handled by /auth/confirm before it ever gets here.
 */
export default async function AcceptInvitationPage() {
  if (!isDemoMode()) {
    const supabase = await createClient();
    const { data } = await supabase.auth.getUser();
    if (!data.user) redirect("/login");
  }

  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Set your password</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          Your SBTF staff account has been created. Choose a password you do not use for another
          service, then sign in.
        </p>

        <div className="mt-6">
          <AcceptInvitationForm />
        </div>
      </div>
    </div>
  );
}
