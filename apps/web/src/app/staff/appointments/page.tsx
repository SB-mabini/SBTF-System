import { AppointmentsPage } from "@/components/appointments/appointments-page";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Appointments — MTOP Staff" };

export default async function StaffAppointmentsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireStaff();
  return <AppointmentsPage searchParams={await searchParams} />;
}
