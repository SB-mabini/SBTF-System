import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";

import { createClient } from "@/lib/supabase/server";
import { isDemoMode } from "@/lib/env";

/**
 * Single verified entry point for every Supabase auth link.
 *
 * Both shapes are accepted because two producers exist:
 *
 *   - The `admin-users` Edge Function builds our own link from
 *     `generateLink().properties.hashed_token` and points it here with
 *     `?token_hash=…&type=recovery`. That is the link an administrator hands to
 *     a new staff member, so the verification is entirely ours.
 *   - Supabase's own mailer (used for self-service recovery on an account whose
 *     e-mail delivery is configured) redirects here with `?code=…` under the
 *     PKCE flow.
 *
 * Only `verifyOtp` / `exchangeCodeForSession` can turn either into a session,
 * which is why links previously dead-ended: nothing consumed the token.
 *
 * Routes:
 *   recovery / invite → /reset-password   (set a password)
 *   everything else   → /auth/confirmed    (address confirmed)
 */
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);

  /**
   * Stay on the host that received the link.
   *
   * This used to redirect to `SITE_URL`, which falls back to http://localhost:3000
   * when NEXT_PUBLIC_SITE_URL is missing from the build. A production link then
   * verified successfully, set its session cookie for the Vercel domain, and
   * redirected to localhost — where that cookie does not exist, so the reset form
   * never found a session and the visitor saw a dead link. Deriving the origin
   * from the request also keeps preview deployments and custom domains working
   * without extra configuration, and it guarantees the redirect target matches
   * the host the cookie was just written for.
   */
  const redirectTo = (path: string) =>
    NextResponse.redirect(new URL(path, request.nextUrl.origin));

  if (isDemoMode()) return redirectTo("/login");

  // Supabase forwards its own failures (expired token, already used) here.
  if (searchParams.get("error_description") || searchParams.get("error")) {
    return redirectTo("/auth/confirmed?status=invalid");
  }

  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const next = searchParams.get("next");

  const supabase = await createClient();

  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) return redirectTo("/auth/confirmed?status=invalid");
    return redirectTo(safeNext(next) ?? destinationForType(type));
  }

  if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });
    if (error) return redirectTo("/auth/confirmed?status=invalid");
    return redirectTo(safeNext(next) ?? destinationForType(type));
  }

  return redirectTo("/auth/confirmed?status=invalid");
}

/** Only same-site, absolute paths are honoured so the route cannot be an open redirect. */
function safeNext(next: string | null): string | null {
  return next && next.startsWith("/") && !next.startsWith("//") ? next : null;
}

function destinationForType(type: EmailOtpType | null): string {
  return type === "recovery" || type === "invite" ? "/reset-password" : "/auth/confirmed";
}
