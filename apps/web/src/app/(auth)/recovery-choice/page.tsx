import { redirect } from "next/navigation";

import { LinkButton } from "@/components/ui";
import { signOutAction } from "@/lib/actions/auth";
import { getSessionProfile } from "@/lib/data";
import { homePathForRole } from "@/lib/permissions";

export const metadata = { title: "Continue — SBTF System" };

/**
 * Step three of password recovery: the code created a session, so the visitor
 * now decides what that session is for.
 *
 * "Continue" opens the console as themselves; "Set a new password" hands over to
 * the same form an administrator-issued setup link uses. The page is public so
 * middleware does not interfere, and guards itself: without a usable session it
 * sends the visitor back to the start.
 */
export default async function RecoveryChoicePage() {
  const session = await getSessionProfile();
  if (!session) redirect("/forgot-password");

  const { profile, role } = session;
  if ((role !== "administrator" && role !== "staff") || profile.account_status !== "active") {
    redirect("/unauthorized");
  }

  const consoleName = role === "administrator" ? "administrator" : "staff";

  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Your code was accepted</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          You are signed in as <strong className="break-all text-ink">{profile.email}</strong>. What
          would you like to do next?
        </p>

        <div className="mt-6 space-y-3">
          <LinkButton href={homePathForRole(role)} className="w-full">
            Continue to the {consoleName} console
          </LinkButton>
          <LinkButton href="/reset-password" variant="outline" className="w-full">
            Set a new password
          </LinkButton>
        </div>

        <p className="mt-5 text-[0.75rem] text-muted">
          Set a new password if you did not request this code, or if you think someone else knows
          your current one.
        </p>

        <form action={signOutAction} className="mt-6 border-t border-line pt-4 text-center">
          <button
            type="submit"
            className="text-[0.8125rem] text-muted hover:text-ink hover:underline"
          >
            Not you? Sign out
          </button>
        </form>
      </div>
    </div>
  );
}
