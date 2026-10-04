import { RecordsPage } from "@/components/records/records-page";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Franchise records — SBTF Administrator" };

export default async function AdminRecordsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireAdministrator();
  return <RecordsPage basePath="/admin" searchParams={await searchParams} />;
}
