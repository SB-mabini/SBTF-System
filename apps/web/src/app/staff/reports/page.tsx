import { ReportsPage } from "@/components/reports/reports-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Reports — SBTF Staff" };

export default async function StaffReportsPage() {
  const session = await requireStaff();
  return <ReportsPage session={session} />;
}
