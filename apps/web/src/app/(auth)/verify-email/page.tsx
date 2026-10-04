import Link from "next/link";

import { Alert } from "@/components/ui";

export const metadata = { title: "Verify your e-mail — SBTF System" };

export default function VerifyEmailPage() {
  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">Confirm your e-mail address</h1>
        <p className="mt-1 text-[0.8125rem] text-muted">
          Supabase Auth sent a confirmation link when the account was created. Open it to activate
          sign-in for this address.
        </p>

        <div className="mt-4 space-y-3">
          <Alert tone="info" title="Nothing in your inbox?">
            Check the spam folder, confirm that the address is spelled correctly, or ask the
            municipal administrator to re-send the invitation from the Users screen.
          </Alert>

          <p className="text-[0.8125rem] text-muted">
            Staff accounts created by an administrator receive a Supabase Auth invitation e-mail
            with a link to set their own password. Drivers and operators receive a confirmation
            e-mail when they register in the mobile application.
          </p>
        </div>

        <p className="mt-6 text-center text-[0.8125rem]">
          <Link className="text-primary hover:underline" href="/login">
            Back to sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
