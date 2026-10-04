import { RecordsPage } from "@/components/records/records-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Franchise records — SBTF Staff" };

export default async function StaffRecordsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireStaff();
  return <RecordsPage basePath="/staff" searchParams={await searchParams} />;
}
