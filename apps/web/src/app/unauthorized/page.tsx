import Link from "next/link";

import { Alert } from "@/components/ui";
import { MUNICIPALITY } from "@/lib/constants";

export const metadata = { title: "Access denied — SBTF System" };

const REASONS: Record<string, { title: string; body: string }> = {
  forbidden: {
    title: "Your role cannot open this section",
    body:
      "The municipality's records are released by role. An administrator has access to every section; staff accounts process applications, verify documents, issue certificates and read operational analytics.",
  },
  account_inactive: {
    title: "This account is not active",
    body:
      "An inactive or suspended account is treated as having no identity in the database, so it cannot read or change any record. Contact the municipal administrator to restore access.",
  },
  driver_on_web: {
    title: "Drivers and operators use the mobile application",
    body:
      "Franchise applications, document uploads, status tracking and certificate downloads are available in the SBTF mobile application.",
  },
};

export default async function UnauthorizedPage({
  searchParams,
}: {
  searchParams: Promise<{ reason?: string }>;
}) {
  const { reason } = await searchParams;
  const detail = REASONS[reason ?? "forbidden"] ?? REASONS.forbidden!;

  return (
    <div className="mx-auto flex min-h-screen max-w-lg flex-col justify-center px-6 py-12">
      <div className="sbtf-card p-6">
        <p className="text-[0.6875rem] font-medium uppercase tracking-wide text-secondary-600">
          Access denied
        </p>
        <h1 className="mt-1 text-xl font-semibold text-ink">{detail.title}</h1>
        <p className="mt-2 text-[0.875rem] text-muted">{detail.body}</p>

        <div className="mt-4">
          <Alert tone="info">
            For the {MUNICIPALITY} franchise office this check runs in PostgreSQL as well as in the
            interface: hiding a button is never the control that protects the data.
          </Alert>
        </div>

        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            className="inline-flex items-center rounded-lg bg-primary px-3.5 py-2 text-[0.8125rem] font-medium text-white hover:bg-primary-600"
            href="/login"
          >
            Sign in with another account
          </Link>
          <Link
            className="inline-flex items-center rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
            href="/verify"
          >
            Verify a certificate
          </Link>
        </div>
      </div>
    </div>
  );
}
