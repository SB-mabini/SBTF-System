import Link from "next/link";
import { CalendarClock } from "lucide-react";

import { Badge, Card, CardHeader, EmptyState, LinkButton } from "@/components/ui";
import { APPOINTMENT_KIND_LABELS, APPOINTMENT_STATUS_LABELS } from "@/lib/constants";
import { listAppointments } from "@/lib/data";
import { formatDateTime } from "@/lib/format";
import type { AppointmentStatus } from "@/types/database";

const STATUS_TONE: Record<AppointmentStatus, "info" | "success" | "warning" | "danger" | "neutral"> = {
  scheduled: "info",
  completed: "success",
  no_show: "danger",
  rescheduled: "warning",
  cancelled: "neutral",
};

/**
 * The next appointments on the processing desk, so a hearing or document
 * submission is not missed just because nobody opened the applications queue.
 */
export async function UpcomingAppointmentsPanel({ limit = 5 }: { limit?: number }) {
  const result = await listAppointments({ scope: "upcoming", pageSize: limit });

  return (
    <Card>
      <CardHeader
        title="Upcoming appointments"
        description="Evaluation, physical-document submission, hearings and release, in date order."
        icon={CalendarClock}
        action={
          <Link className="text-[0.8125rem] font-medium text-primary hover:underline" href="/staff/appointments">
            View all
          </Link>
        }
      />

      {result.rows.length === 0 ? (
        <EmptyState
          title="Nothing scheduled"
          description="Schedule an appointment from an application's handling panel."
        />
      ) : (
        <ul className="divide-y divide-line">
          {result.rows.map((appointment) => (
            <li key={appointment.id} className="flex flex-wrap items-start justify-between gap-3 py-3 first:pt-0 last:pb-0">
              <div className="min-w-0">
                <p className="text-[0.875rem] font-medium text-ink">
                  {APPOINTMENT_KIND_LABELS[appointment.kind]}
                </p>
                <p className="mt-0.5 text-[0.75rem] text-muted">
                  {formatDateTime(appointment.scheduled_at)} · {appointment.venue}
                </p>
                {appointment.application ? (
                  <Link
                    className="mt-1 inline-block text-[0.8125rem] font-medium text-primary hover:underline"
                    href={`/staff/applications/${appointment.application.id}`}
                  >
                    {appointment.application.application_number} ·{" "}
                    {appointment.application.operator_first_name}{" "}
                    {appointment.application.operator_last_name}
                  </Link>
                ) : null}
              </div>
              <Badge tone={STATUS_TONE[appointment.status]}>
                {APPOINTMENT_STATUS_LABELS[appointment.status]}
              </Badge>
            </li>
          ))}
        </ul>
      )}

      <div className="mt-4">
        <LinkButton href="/staff/appointments" variant="outline">
          Open the appointment list
        </LinkButton>
      </div>
    </Card>
  );
}
