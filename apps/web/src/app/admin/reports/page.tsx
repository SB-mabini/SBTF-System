import { ReportsPage } from "@/components/reports/reports-page";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Reports — MTOP Administrator" };

export default async function AdminReportsPage() {
  const session = await requireAdministrator();
  return <ReportsPage session={session} />;
}
