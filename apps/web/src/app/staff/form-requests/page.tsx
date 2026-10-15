import { FormRequestsPage } from "@/components/form-requests/form-requests-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Form Requests — SBTF Staff" };

export default async function StaffFormRequestsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireStaff();
  return <FormRequestsPage searchParams={await searchParams} />;
}
