import { NotificationsPage } from "@/components/notifications/notifications-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Notifications — SBTF Staff" };

export default async function StaffNotificationsPage() {
  await requireStaff();
  return <NotificationsPage basePath="/staff" />;
}
