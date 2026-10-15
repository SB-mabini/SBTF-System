import Link from "next/link";
import { CalendarClock, MapPin } from "lucide-react";

import { Badge, Card, CardHeader, EmptyState, SectionTitle } from "@/components/ui";
import { APPOINTMENT_KIND_LABELS, APPOINTMENT_STATUS_LABELS } from "@/lib/constants";
import { listAppointments } from "@/lib/data";
import { formatDateTime } from "@/lib/format";
import type { AppointmentKind, AppointmentStatus } from "@/types/database";

const SCOPE_TABS: Array<{ value: "upcoming" | "past" | "all"; label: string }> = [
  { value: "upcoming", label: "Upcoming" },
  { value: "past", label: "Past" },
  { value: "all", label: "All" },
];

const KIND_TABS: Array<{ value: AppointmentKind | "all"; label: string }> = [
  { value: "all", label: "All types" },
  { value: "evaluation", label: "Evaluation" },
  { value: "physical_documents", label: "Physical documents" },
  { value: "hearing", label: "Hearing" },
  { value: "release", label: "Release" },
  { value: "other", label: "Other" },
];

const STATUS_TONE: Record<AppointmentStatus, "info" | "success" | "warning" | "danger" | "neutral"> = {
  scheduled: "info",
  completed: "success",
  no_show: "danger",
  rescheduled: "warning",
  cancelled: "neutral",
};

function buildHref(params: {
  scope: string;
  kind: string;
}): string {
  const query = new URLSearchParams();
  if (params.scope !== "upcoming") query.set("scope", params.scope);
  if (params.kind !== "all") query.set("kind", params.kind);
  const suffix = query.toString();
  return suffix ? `/staff/appointments?${suffix}` : "/staff/appointments";
}

export async function AppointmentsPage({
  searchParams,
}: {
  searchParams: Record<string, string | string[] | undefined>;
}) {
  const scopeParam = typeof searchParams.scope === "string" ? searchParams.scope : "upcoming";
  const scope = SCOPE_TABS.some((tab) => tab.value === scopeParam)
    ? (scopeParam as "upcoming" | "past" | "all")
    : "upcoming";
  const kindParam = typeof searchParams.kind === "string" ? searchParams.kind : "all";
  const kind = KIND_TABS.some((tab) => tab.value === kindParam)
    ? (kindParam as AppointmentKind | "all")
    : "all";

  const result = await listAppointments({ scope, kind, pageSize: 50 });

  return (
    <div className="space-y-5">
      <SectionTitle
        title="Appointments"
        description="Evaluation, physical-document submission, hearing and release appointments across every application."
      />

      <div className="space-y-2">
        <div className="flex flex-wrap gap-2">
          {SCOPE_TABS.map((tab) => {
            const active = tab.value === scope;
            return (
              <Link
                key={tab.value}
                href={buildHref({ scope: tab.value, kind })}
                className={`rounded-lg border px-3 py-1.5 text-[0.8125rem] font-medium transition-colors ${
                  active
                    ? "border-primary-100 bg-primary-50 text-primary-700"
                    : "border-line-strong bg-white text-muted hover:bg-page hover:text-ink"
                }`}
              >
                {tab.label}
              </Link>
            );
          })}
        </div>

        <div className="flex flex-wrap gap-2">
          {KIND_TABS.map((tab) => {
            const active = tab.value === kind;
            return (
              <Link
                key={tab.value}
                href={buildHref({ scope, kind: tab.value })}
                className={`rounded-full border px-3 py-1 text-[0.75rem] font-medium transition-colors ${
                  active
                    ? "border-primary-100 bg-primary-50 text-primary-700"
                    : "border-line bg-white text-muted hover:bg-page hover:text-ink"
                }`}
              >
                {tab.label}
              </Link>
            );
          })}
        </div>
      </div>

      <Card>
        <CardHeader
          title={`${result.count} appointment${result.count === 1 ? "" : "s"}`}
          description={scope === "all" ? "Every appointment" : scope === "past" ? "Past appointments" : "Scheduled ahead"}
          icon={CalendarClock}
        />

        {result.rows.length === 0 ? (
          <EmptyState
            title="No appointments"
            description="Schedule an appointment from an application's handling panel and it will appear here."
          />
        ) : (
          <ul className="space-y-3">
            {result.rows.map((appointment) => (
              <li key={appointment.id} className="rounded-lg border border-line p-3.5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-[0.875rem] font-semibold text-ink">
                      {APPOINTMENT_KIND_LABELS[appointment.kind]} ·{" "}
                      {formatDateTime(appointment.scheduled_at)}
                    </p>
                    <p className="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[0.75rem] text-muted">
                      <span className="inline-flex items-center gap-1">
                        <MapPin className="h-3.5 w-3.5" />
                        {appointment.venue}
                      </span>
                      {appointment.application ? (
                        <span>
                          ·{" "}
                          <span className="font-mono">{appointment.application.application_number}</span> ·{" "}
                          {appointment.application.operator_first_name}{" "}
                          {appointment.application.operator_last_name}
                        </span>
                      ) : null}
                    </p>
                    {appointment.outcome ? (
                      <p className="mt-1 text-[0.8125rem] text-ink">{appointment.outcome}</p>
                    ) : null}
                    {appointment.notes ? (
                      <p className="mt-1 text-[0.75rem] text-muted">{appointment.notes}</p>
                    ) : null}
                  </div>
                  <Badge tone={STATUS_TONE[appointment.status]}>
                    {APPOINTMENT_STATUS_LABELS[appointment.status]}
                  </Badge>
                </div>

                {appointment.application ? (
                  <div className="mt-3">
                    <Link
                      className="text-[0.8125rem] font-medium text-primary hover:underline"
                      href={`/staff/applications/${appointment.application.id}`}
                    >
                      Open application
                    </Link>
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
