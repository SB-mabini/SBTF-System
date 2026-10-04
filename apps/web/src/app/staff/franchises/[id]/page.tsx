import { RecordDetail } from "@/components/records/record-detail";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Franchise record — SBTF Staff" };

export default async function StaffRecordDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireStaff();
  const { id } = await params;
  return <RecordDetail recordId={id} basePath="/staff" />;
}
