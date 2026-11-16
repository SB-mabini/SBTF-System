import { AccountPage } from "@/components/account/account-page";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "My account — MTOP Administrator" };

export default async function AdminAccountPage() {
  const session = await requireAdministrator();
  return <AccountPage session={session} />;
}
