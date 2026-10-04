import { redirect } from "next/navigation";

import { getSessionProfile } from "@/lib/data";
import { isDemoMode } from "@/lib/env";
import { homePathForRole } from "@/lib/permissions";

/**
 * The interface has no public landing page: visitors are routed to their own
 * console (or to the sign-in screen) by the session. Certificate verification,
 * which must be reachable without an account, lives at /verify.
 */
export default async function RootPage() {
  if (isDemoMode()) redirect("/admin");

  const session = await getSessionProfile();
  redirect(session ? homePathForRole(session.role) : "/login");
}
