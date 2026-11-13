import { AnnouncementsPage } from "@/components/announcements/announcements-page";
import { requireStaff } from "@/lib/auth-guard";

export default async function StaffAnnouncementsPage() {
  await requireStaff();
  return <AnnouncementsPage />;
}
