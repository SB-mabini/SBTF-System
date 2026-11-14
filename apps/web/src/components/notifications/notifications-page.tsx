import { NotificationList } from "@/components/notifications/notification-list";
import { SectionTitle } from "@/components/ui";
import { listNotifications } from "@/lib/data";

export async function NotificationsPage({ basePath }: { basePath: "/admin" | "/staff" }) {
  const notifications = await listNotifications(50);

  return (
    <div>
      <SectionTitle title="Notifications" />
      <NotificationList notifications={notifications} basePath={basePath} />
    </div>
  );
}
