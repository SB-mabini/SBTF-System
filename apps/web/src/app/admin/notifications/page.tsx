import { NotificationsPage } from "@/components/notifications/notifications-page";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Notifications — SBTF Administrator" };

export default async function AdminNotificationsPage() {
  await requireAdministrator();
  return <NotificationsPage basePath="/admin" />;
}
