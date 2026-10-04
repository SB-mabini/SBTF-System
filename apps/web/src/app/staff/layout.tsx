import type { ReactNode } from "react";

import { DashboardShell } from "@/components/layout/dashboard-shell";
import { requireStaff } from "@/lib/auth-guard";

/**
 * Staff console. Administrators may open it as well: the operations screens are
 * a subset of what their role can already do, and the database grants both roles
 * the same processing functions.
 */
export default async function StaffLayout({ children }: { children: ReactNode }) {
  const session = await requireStaff();

  return <DashboardShell session={session}>{children}</DashboardShell>;
}
