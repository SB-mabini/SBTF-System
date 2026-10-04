import { ApplicationsPage } from "@/components/applications/applications-page";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Applications — SBTF Administrator" };

export default async function AdminApplicationsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireAdministrator();
  return <ApplicationsPage basePath="/admin" searchParams={await searchParams} />;
}
