import { AnnouncementManager } from "@/components/announcements/announcement-manager";
import { SectionTitle } from "@/components/ui";
import { listAnnouncements, listDrivers, listTodas } from "@/lib/data";

export async function AnnouncementsPage() {
  const [announcements, todas, drivers] = await Promise.all([
    listAnnouncements(),
    listTodas(),
    listDrivers(),
  ]);

  return (
    <div>
      <SectionTitle
        title="Announcements"
        description="Broadcast office notices to all drivers, TODA members or selected drivers. Publishing delivers through the existing notification feed."
      />
      <AnnouncementManager announcements={announcements} todas={todas} drivers={drivers} />
    </div>
  );
}
