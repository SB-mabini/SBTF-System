import { ApplicationsPage } from "@/components/applications/applications-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Applications — SBTF Staff" };

export default async function StaffApplicationsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireStaff();
  return <ApplicationsPage basePath="/staff" searchParams={await searchParams} />;
}
