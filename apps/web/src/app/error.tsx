"use client";

import Link from "next/link";
import { useEffect } from "react";

import { Alert, Button } from "@/components/ui";
import { classifyDatabaseError } from "@/lib/supabase/errors";

/**
 * Route-level error boundary.
 *
 * Next.js renders this instead of the page when a Server Component throws. It is
 * the last place a database failure can be explained in words, so it reuses the
 * same classifier as the middleware: a schema or connectivity failure sends the
 * reader to /setup-required with the matching guidance, everything else is
 * reported as an ordinary error with the digest an administrator can look up.
 *
 * Only `error.digest` and the classified kind reach the browser. The message
 * itself is shown only when it is already a user-safe sentence produced by this
 * application, never a raw driver or SQL error.
 */
export default function ErrorBoundary({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // The digest ties this screen to the server log entry; no personal data is
    // written to the browser console.
    console.error("SBTF interface error", error.digest ?? error.message);
  }, [error]);

  const notConfigured = error.message.includes("Supabase is not configured");
  const failure = classifyDatabaseError({
    message: error.message,
    name: error.name,
    digest: error.digest,
  });
  const databaseNotReady = notConfigured || failure.blocking;

  const title = notConfigured
    ? "The system is not connected yet"
    : databaseNotReady
      ? "The database is not ready"
      : "Something went wrong";

  return (
    <div className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center px-6 py-12">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">{title}</h1>

        <div className="mt-4 space-y-3">
          <Alert tone={databaseNotReady ? "warning" : "danger"}>
            {notConfigured
              ? "Copy apps/web/.env.example to apps/web/.env.local and set the Supabase URL and publishable key, or set NEXT_PUBLIC_DEMO_MODE=true to review the interface with sample data."
              : failure.blocking
                ? failure.reason
                : "The page could not be loaded. The error has been logged with a reference the administrator can look up in the activity log."}
          </Alert>

          {databaseNotReady && failure.blocking ? (
            <p className="text-[0.8125rem] text-muted">
              {failure.hint} No franchise record was changed by this failure.
            </p>
          ) : null}
        </div>

        <dl className="mt-4 space-y-1 text-[0.75rem] text-muted">
          {failure.code ? (
            <div className="flex gap-2">
              <dt className="font-medium">Code</dt>
              <dd className="font-mono">{failure.code}</dd>
            </div>
          ) : null}
          {error.digest ? (
            <div className="flex gap-2">
              <dt className="font-medium">Reference</dt>
              <dd className="font-mono">{error.digest}</dd>
            </div>
          ) : null}
        </dl>

        <div className="mt-5 flex flex-wrap gap-3">
          <Button onClick={reset}>Try again</Button>

          {databaseNotReady ? (
            <Link
              className="inline-flex items-center rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
              href={`/setup-required?reason=${notConfigured ? "not_configured" : failure.kind}`}
            >
              What needs fixing
            </Link>
          ) : null}

          <Link
            className="inline-flex items-center rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
            href="/login"
          >
            Back to sign in
          </Link>
        </div>
      </div>
    </div>
  );
}
