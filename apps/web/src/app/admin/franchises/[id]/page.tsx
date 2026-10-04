import { RecordDetail } from "@/components/records/record-detail";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Franchise record — SBTF Administrator" };

export default async function AdminRecordDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireAdministrator();
  const { id } = await params;
  return <RecordDetail recordId={id} basePath="/admin" />;
}
