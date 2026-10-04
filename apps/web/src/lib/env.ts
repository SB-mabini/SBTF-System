/**
 * Environment access with explicit validation.
 *
 * Preview mode (`NEXT_PUBLIC_DEMO_MODE=true`) lets the interface run on bundled
 * sample data with every write action disabled. It exists so the interface can
 * be reviewed without a Supabase project; it is never used in production.
 */

export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
export const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/$/, "") ?? "http://localhost:3000";

export function isDemoMode(): boolean {
  return process.env.NEXT_PUBLIC_DEMO_MODE === "true";
}

export function isSupabaseConfigured(): boolean {
  return (
    SUPABASE_URL.startsWith("http") &&
    SUPABASE_ANON_KEY.length > 20 &&
    !SUPABASE_URL.includes("your-project-ref")
  );
}

/**
 * Guard for server-side data access. Throws a typed error the pages translate
 * into a helpful "not configured" screen instead of a stack trace.
 */
export function assertSupabaseConfigured(): void {
  if (!isSupabaseConfigured()) {
    throw new SupabaseNotConfiguredError();
  }
}

export class SupabaseNotConfiguredError extends Error {
  constructor() {
    super(
      "Supabase is not configured. Copy apps/web/.env.example to .env.local and set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY, or enable NEXT_PUBLIC_DEMO_MODE=true to review the interface with sample data.",
    );
    this.name = "SupabaseNotConfiguredError";
  }
}
