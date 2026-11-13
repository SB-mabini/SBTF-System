import { AnnouncementsPage } from "@/components/announcements/announcements-page";
import { requireAdministrator } from "@/lib/auth-guard";

export default async function AdminAnnouncementsPage() {
  await requireAdministrator();
  return <AnnouncementsPage />;
}
