import { ApplicationDetail } from "@/components/applications/application-detail";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Application — MTOP Staff" };

export default async function StaffApplicationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireStaff();
  const { id } = await params;
  return <ApplicationDetail applicationId={id} basePath="/staff" />;
}
