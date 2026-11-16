import { AccountPage } from "@/components/account/account-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "My account — MTOP Staff" };

export default async function StaffAccountPage() {
  const session = await requireStaff();
  return <AccountPage session={session} />;
}
