import { AccountPage } from "@/components/account/account-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "My account — SBTF Staff" };

export default async function StaffAccountPage() {
  const session = await requireStaff();
  return <AccountPage session={session} />;
}
