import type { ReactNode } from "react";

import { DashboardShell } from "@/components/layout/dashboard-shell";
import { requireAdministrator } from "@/lib/auth-guard";

/**
 * Administrator console. The layout resolves the session once and renders the
 * shared chrome; the individual pages assume the same guard (the database
 * re-checks everything they read).
 */
export default async function AdminLayout({ children }: { children: ReactNode }) {
  const session = await requireAdministrator();

  return <DashboardShell session={session}>{children}</DashboardShell>;
}
