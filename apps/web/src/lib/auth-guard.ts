import { redirect } from "next/navigation";

import { getSessionProfile, type SessionContext } from "@/lib/data";

/**
 * Server-side route guards.
 *
 * These keep the interface tidy — they decide which console a visitor sees.
 * They are NOT the security boundary: every query a page makes is filtered by
 * the Row Level Security policies in PostgreSQL, so a bypassed redirect still
 * returns nothing.
 */
export async function requireAdministrator(): Promise<SessionContext> {
  const session = await getSessionProfile();

  if (!session) redirect("/login");
  if (session.profile.account_status !== "active") {
    redirect("/unauthorized?reason=account_inactive");
  }
  if (session.role !== "administrator") redirect("/unauthorized?reason=forbidden");

  return session;
}

export async function requireStaff(): Promise<SessionContext> {
  const session = await getSessionProfile();

  if (!session) redirect("/login");
  if (session.profile.account_status !== "active") {
    redirect("/unauthorized?reason=account_inactive");
  }
  if (session.role !== "staff" && session.role !== "administrator") {
    redirect("/unauthorized?reason=forbidden");
  }

  return session;
}
