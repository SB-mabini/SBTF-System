"use client";

import { useEffect } from "react";

import { Alert, Button } from "@/components/ui";

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

  return (
    <div className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center px-6 py-12">
      <div className="sbtf-card p-6">
        <h1 className="text-lg font-semibold text-ink">
          {notConfigured ? "The system is not connected yet" : "Something went wrong"}
        </h1>

        <div className="mt-4">
          <Alert tone={notConfigured ? "info" : "danger"}>
            {notConfigured
              ? "Copy apps/web/.env.example to apps/web/.env.local and set the Supabase URL and anon key, or set NEXT_PUBLIC_DEMO_MODE=true to review the interface with sample data."
              : "The page could not be loaded. The error has been logged with a reference the administrator can look up in the activity log."}
          </Alert>
        </div>

        {error.digest ? (
          <p className="mt-3 text-[0.75rem] text-muted">
            Reference: <span className="font-mono">{error.digest}</span>
          </p>
        ) : null}

        <div className="mt-5 flex gap-3">
          <Button onClick={reset}>Try again</Button>
          <a
            className="inline-flex items-center rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
            href="/login"
          >
            Back to sign in
          </a>
        </div>
      </div>
    </div>
  );
}
