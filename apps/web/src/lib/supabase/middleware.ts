import { NextResponse, type NextRequest } from "next/server";
import { createServerClient } from "@supabase/ssr";

import { SUPABASE_ANON_KEY, SUPABASE_URL, isDemoMode } from "@/lib/env";

const PUBLIC_PATHS = [
  "/login",
  "/forgot-password",
  "/reset-password",
  "/verify-email",
  "/verify",
  "/unauthorized",
  "/auth",
];

/**
 * Refreshes the Supabase session cookie and applies route-level navigation
 * rules. This is a usability layer only: the database re-checks every request
 * through RLS, so a bypassed redirect grants no data access.
 */
export async function updateSession(
  request: NextRequest,
  options: {
    demoRole?: "administrator" | "staff" | null;
  } = {},
): Promise<NextResponse> {
  if (isDemoMode()) {
    return demoRouting(request, options.demoRole ?? "administrator");
  }

  let response = NextResponse.next({ request });

  const supabase = createServerClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
      },
    },
  });

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const path = request.nextUrl.pathname;
  const isPublic = PUBLIC_PATHS.some(
    (publicPath) => path === publicPath || path.startsWith(`${publicPath}/`),
  );

  if (!user && !isPublic && path !== "/") {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("next", path);
    return NextResponse.redirect(url);
  }

  if (user) {
    // Role is read through RLS with the user's own token.
    const { data: profile } = await supabase
      .from("profiles")
      .select("role, account_status")
      .eq("auth_user_id", user.id)
      .maybeSingle();

    const role = profile?.role ?? null;
    const blocked = profile && profile.account_status !== "active";

    if (blocked && !isPublic) {
      const url = request.nextUrl.clone();
      url.pathname = "/unauthorized";
      url.searchParams.set("reason", "account_inactive");
      return NextResponse.redirect(url);
    }

    if (path.startsWith("/admin") && role !== "administrator") {
      const url = request.nextUrl.clone();
      url.pathname = role === "staff" ? "/staff" : "/unauthorized";
      url.search = role === "staff" ? "" : "?reason=forbidden";
      return NextResponse.redirect(url);
    }

    if (path.startsWith("/staff") && role !== "staff" && role !== "administrator") {
      const url = request.nextUrl.clone();
      url.pathname = "/unauthorized";
      url.search = "?reason=forbidden";
      return NextResponse.redirect(url);
    }

    if (path === "/login") {
      const url = request.nextUrl.clone();
      url.pathname = role === "administrator" ? "/admin" : role === "staff" ? "/staff" : "/unauthorized";
      url.search = "";
      return NextResponse.redirect(url);
    }
  }

  return response;
}

/** Preview-mode routing so the dashboard can be reviewed without an account. */
function demoRouting(
  request: NextRequest,
  role: "administrator" | "staff" | null,
): NextResponse {
  const path = request.nextUrl.pathname;
  const requested = request.nextUrl.searchParams.get("as");

  // Persist an explicit ?as=staff / ?as=admin selection in a cookie so that the
  // server components render the matching demo session on later navigations.
  if (requested === "staff" || requested === "admin") {
    const target = requested === "staff" ? "staff" : "administrator";
    const url = request.nextUrl.clone();
    url.searchParams.delete("as");
    if (path.startsWith("/admin") && target !== "administrator") url.pathname = "/staff";
    if (path.startsWith("/staff") && target === "staff") url.pathname = path;
    const response = NextResponse.redirect(url);
    response.cookies.set("sbtf_demo_role", target, {
      httpOnly: false,
      sameSite: "lax",
      path: "/",
    });
    return response;
  }
  const isPublic = PUBLIC_PATHS.some(
    (publicPath) => path === publicPath || path.startsWith(`${publicPath}/`),
  );

  if (path === "/") {
    const url = request.nextUrl.clone();
    url.pathname = role === "staff" ? "/staff" : "/admin";
    url.search = "";
    return NextResponse.redirect(url);
  }

  // The sign-in screen stays reachable in preview mode so that it can be
  // reviewed; in a connected environment it redirects to the matching console.

  if (path.startsWith("/admin") && role !== "administrator") {
    const url = request.nextUrl.clone();
    url.pathname = "/staff";
    url.search = "";
    return NextResponse.redirect(url);
  }

  if (!isPublic && role === null) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return NextResponse.next({ request });
}
