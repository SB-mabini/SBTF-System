import Link from "next/link";

import { Alert, Card, CardHeader } from "@/components/ui";
import { MUNICIPALITY } from "@/lib/constants";
import { isDemoMode, isSupabaseConfigured } from "@/lib/env";

export const metadata = { title: "Setup required — SBTF System" };

/**
 * Shown when the database is not in a usable state.
 *
 * The middleware redirects here instead of sending the visitor back to /login.
 * That matters: when the project is unreachable or the migrations were never
 * applied, `getUser()` fails on every request, so the old behaviour was an
 * endless /login ↔ /unauthorized loop with nothing on screen to explain it.
 *
 * The page is public on purpose (see PUBLIC_PATHS in
 * src/lib/supabase/middleware.ts) and never reads the database, so it renders
 * even when nothing else can.
 */

const REASONS: Record<
  string,
  { title: string; body: string; fix: string; command?: string }
> = {
  schema_missing: {
    title: "The database schema is not applied",
    body:
      "The application is connected to the Supabase project, but the tables, functions or row level security policies it expects are not there. This is the normal state of a brand new project, and it happens to an existing one when a migration was applied by hand and partly failed.",
    fix: "Apply supabase/migrations to the project, then reload the PostgREST schema cache.",
    command: "npm run db:bundle   # writes supabase/setup-all.sql",
  },
  unreachable: {
    title: "The Supabase project could not be reached",
    body:
      "No response came back from the project URL. Check that NEXT_PUBLIC_SUPABASE_URL is correct, that the project is not paused in the Supabase dashboard, and that outbound HTTPS is allowed from where the application runs.",
    fix: "Run the connectivity check — it reports which link in the chain is broken.",
    command: "npm run db:check",
  },
  unauthorised: {
    title: "The database refused this session",
    body:
      "The project answered, but the request was rejected. The usual causes are a rotated publishable key, an expired session, or row level security policies that were never applied.",
    fix: "Confirm the key in the environment, sign in again, then re-check the project.",
    command: "npm run db:check",
  },
  unknown: {
    title: "The database returned an unexpected error",
    body:
      "The request failed for a reason the application does not recognise. The error has been logged with a reference an administrator can look up.",
    fix: "Retry. If it persists, check the Supabase dashboard logs for the same minute.",
    command: "npm run db:verify",
  },
  not_configured: {
    title: "Supabase is not configured",
    body:
      "No Supabase URL or publishable key is present in the environment, so the application has nothing to connect to.",
    fix: "Copy apps/web/.env.example to apps/web/.env.local and set the project URL and key.",
    command: "npm run db:check",
  },
};

export default async function SetupRequiredPage({
  searchParams,
}: {
  searchParams: Promise<{ reason?: string }>;
}) {
  const { reason } = await searchParams;

  // With no environment at all there is no project to diagnose, so the reason is
  // overridden rather than guessed from the query string.
  const configured = isSupabaseConfigured();
  const key = !configured && !isDemoMode() ? "not_configured" : (reason ?? "unknown");
  const detail = REASONS[key] ?? REASONS.unknown!;

  return (
    <div className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center px-6 py-12">
      <div className="sbtf-card p-6">
        <p className="text-[0.6875rem] font-medium uppercase tracking-wide text-secondary-600">
          Setup required
        </p>
        <h1 className="mt-1 text-xl font-semibold text-ink">{detail.title}</h1>
        <p className="mt-2 text-[0.875rem] text-muted">{detail.body}</p>

        <div className="mt-4">
          <Alert tone="warning">{detail.fix}</Alert>
        </div>

        {detail.command ? (
          <pre className="mt-4 overflow-x-auto rounded-lg bg-page px-3.5 py-3 font-mono text-[0.75rem] text-ink">
            {detail.command}
          </pre>
        ) : null}

        <Card className="mt-5">
          <CardHeader
            title="How to apply the schema"
            description="Two supported routes. Both are idempotent: re-running them changes nothing that is already correct."
          />
          <ol className="mt-3 list-decimal space-y-2 pl-5 text-[0.8125rem] text-muted">
            <li>
              Supabase CLI — <span className="font-mono">supabase link</span> then{" "}
              <span className="font-mono">supabase db push</span>. Preferred: it records the
              migration history so later migrations apply cleanly.
            </li>
            <li>
              SQL Editor — run <span className="font-mono">npm run db:bundle</span> and paste{" "}
              <span className="font-mono">supabase/setup-all.sql</span> into a new query. Use this
              when the CLI is not available. Afterwards open Database → API and reload the schema
              cache.
            </li>
          </ol>
        </Card>

        <Card className="mt-4">
          <CardHeader
            title="Diagnosis commands"
            description="Run from the repository root. None of them writes to the database."
          />
          <dl className="mt-3 space-y-2 text-[0.8125rem]">
            <Row
              term="npm run db:check"
              detail="Eight read-only steps: environment, reachability, key acceptance, tables, functions, buckets, sign-in, RLS probe. Stops at the first broken link."
            />
            <Row
              term="npm run db:verify"
              detail="Replays the queries the console actually runs and compares the live response shapes with the TypeScript interfaces."
            />
            <Row
              term="npm run validate:sql"
              detail="Parses every migration with the real PostgreSQL grammar without connecting anywhere."
            />
          </dl>
        </Card>

        <div className="mt-6 flex flex-wrap gap-3">
          <Link
            className="inline-flex items-center rounded-lg bg-primary px-3.5 py-2 text-[0.8125rem] font-medium text-white hover:bg-primary-600"
            href="/login"
          >
            Back to sign in
          </Link>
          <Link
            className="inline-flex items-center rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
            href="/verify"
          >
            Verify a certificate
          </Link>
        </div>

        <p className="mt-4 text-[0.75rem] text-muted">
          This page is public and reads nothing from the database, so it stays available while the
          rest of the {MUNICIPALITY} console cannot.
        </p>
      </div>
    </div>
  );
}

function Row({ term, detail }: { term: string; detail: string }) {
  return (
    <div>
      <dt className="font-mono text-[0.75rem] text-ink">{term}</dt>
      <dd className="text-muted">{detail}</dd>
    </div>
  );
}
