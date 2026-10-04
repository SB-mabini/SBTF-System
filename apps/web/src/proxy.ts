import type { NextRequest } from "next/server";

import { updateSession } from "@/lib/supabase/middleware";

/**
 * Request proxy (Next.js 16 name for the former middleware).
 *
 * It keeps the Supabase session fresh and decides which console a visitor may
 * open. This is usability routing only: every table the consoles read is
 * protected by row level security in PostgreSQL, so bypassing this file does
 * not expose anything.
 *
 * In preview mode (?as=staff|admin) the role is taken from a cookie so both
 * dashboards can be reviewed without a Supabase project.
 */
export default async function proxy(request: NextRequest) {
  const requested = request.nextUrl.searchParams.get("as");
  const demoRole =
    requested === "staff"
      ? "staff"
      : requested === "admin"
        ? "administrator"
        : ((request.cookies.get("sbtf_demo_role")?.value as
            | "administrator"
            | "staff"
            | undefined) ?? "administrator");

  return updateSession(request, { demoRole: demoRole ?? null });
}

export const config = {
  matcher: [
    /*
     * Match all request paths except static assets and image optimisation:
     *   /_next/static, /_next/image, favicon, and public file requests.
     */
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico)$).*)",
  ],
};
