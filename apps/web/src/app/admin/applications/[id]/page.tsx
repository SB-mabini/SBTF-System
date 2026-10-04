import { ApplicationDetail } from "@/components/applications/application-detail";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Application — SBTF Administrator" };

export default async function AdminApplicationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireAdministrator();
  const { id } = await params;
  return <ApplicationDetail applicationId={id} basePath="/admin" />;
}
