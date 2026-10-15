import Link from "next/link";

import { Alert } from "@/components/ui";

export const metadata = { title: "E-mail confirmed — SBTF System" };

/**
 * Landing page for a confirmed address. Password recovery and invitations are
 * redirected to /reset-password instead, so this page only reports that the
 * address is now usable for sign-in.
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
              The link was already used, has expired, or was copied incompletely. Request a new one
              and open it in the same browser.
            </p>
            <p className="mt-4 text-[0.8125rem]">
              <Link className="text-primary hover:underline" href="/forgot-password">
                Request a new recovery link
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
