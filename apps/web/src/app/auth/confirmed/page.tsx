import Link from "next/link";

import { Alert } from "@/components/ui";

export const metadata = { title: "E-mail confirmed — SBTF System" };

/**
 * Landing page for a confirmed address.
 *
 * Self-service recovery no longer uses links — it e-mails a 6-digit code and
 * never reaches this route. The only link that still lands here is the one-time
 * setup link an administrator hands to a new staff member (built by the
 * `admin-users` function and verified by `/auth/confirm`), so `status=invalid`
 * means that setup link, not a recovery link, has to be reissued.
 */
export default async function ConfirmedPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const { status } = await searchParams;
  const invalid = status === "invalid";

  return (
    <div className="w-full max-w-md">
      <div className="sbtf-card p-6">
        {invalid ? (
          <>
            <h1 className="text-lg font-semibold text-ink">This link is no longer valid</h1>
            <p className="mt-1 text-[0.8125rem] text-muted">
              This setup link was already used, has expired, or was copied incompletely. Ask the
              municipal administrator to issue a new one from the Users screen.
            </p>
            <p className="mt-4 text-[0.8125rem]">
              <Link className="text-primary hover:underline" href="/forgot-password">
                Reset a password with a verification code
              </Link>
            </p>
          </>
        ) : (
          <>
            <h1 className="text-lg font-semibold text-ink">E-mail address confirmed</h1>
            <p className="mt-1 text-[0.8125rem] text-muted">
              The address is now confirmed and can be used to sign in. If an administrator created
              the account, it still has to be approved before the console opens.
            </p>
            <div className="mt-4">
              <Alert tone="info">
                Staff accounts are activated by a municipal administrator from the Users screen once
                the address has been confirmed.
              </Alert>
            </div>
            <p className="mt-6 text-center text-[0.8125rem]">
              <Link className="text-primary hover:underline" href="/login">
                Continue to sign in
              </Link>
            </p>
          </>
        )}
      </div>
    </div>
  );
}
