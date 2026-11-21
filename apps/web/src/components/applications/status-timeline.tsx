"use client";

import { useState } from "react";
import {
  Archive,
  CalendarCheck,
  CalendarClock,
  CalendarX,
  ChevronDown,
  ChevronUp,
  ClipboardCheck,
  Eye,
  FileCheck2,
  FileUp,
  Milestone,
  PackageCheck,
  RefreshCw,
  Send,
  ShieldCheck,
  Stamp,
} from "lucide-react";

import { formatDateTime } from "@/lib/format";
import type { ApplicationStatusHistory } from "@/types/database";

const EVENT_META: Record<
  ApplicationStatusHistory["event"],
  { label: string; icon: React.ComponentType<{ className?: string }>; tone: string }
> = {
  created: { label: "Application received", icon: FileUp, tone: "bg-primary-50 text-primary-700" },
  document_uploaded: { label: "Document uploaded", icon: FileUp, tone: "bg-primary-50 text-primary-700" },
  document_replaced: { label: "Document replaced", icon: RefreshCw, tone: "bg-accent-50 text-accent-700" },
  document_verified: { label: "Document verified", icon: FileCheck2, tone: "bg-success-50 text-success-600" },
  document_rejected: { label: "Document rejected", icon: CalendarX, tone: "bg-secondary-50 text-secondary-600" },
  review_started: { label: "Review started", icon: Eye, tone: "bg-accent-50 text-accent-700" },
  approved: { label: "Application approved", icon: CalendarCheck, tone: "bg-success-50 text-success-600" },
  rejected: { label: "Application rejected", icon: CalendarX, tone: "bg-secondary-50 text-secondary-600" },
  certificate_issued: { label: "Certificate issued", icon: Stamp, tone: "bg-primary-50 text-primary-700" },
  archived: { label: "Franchise archived", icon: Archive, tone: "bg-gray-100 text-gray-700" },
  stage_changed: { label: "Stage updated", icon: Milestone, tone: "bg-accent-50 text-accent-700" },
  appointment_scheduled: { label: "Appointment scheduled", icon: CalendarClock, tone: "bg-primary-50 text-primary-700" },
  appointment_completed: { label: "Appointment completed", icon: CalendarCheck, tone: "bg-success-50 text-success-600" },
  endorsement_recorded: { label: "Endorsed for approval", icon: Send, tone: "bg-accent-50 text-accent-700" },
  decision_recorded: { label: "Decision recorded", icon: ClipboardCheck, tone: "bg-success-50 text-success-600" },
  document_released: { label: "Documents released", icon: PackageCheck, tone: "bg-primary-50 text-primary-700" },
};

/**
 * How many of the newest events are shown before the history is expanded.
 *
 * An application collects dozens of entries over its lifetime, and rendering
 * all of them made this card much taller than the main column beside it,
 * leaving a large empty area under the processing panel. The newest entries
 * are what staff act on, so the rest sit behind a disclosure.
 */
const COLLAPSED_EVENT_COUNT = 5;

export function StatusTimeline({ events }: { events: ApplicationStatusHistory[] }) {
  const [expanded, setExpanded] = useState(false);

  if (events.length === 0) {
    return <p className="text-[0.8125rem] text-muted">No timeline entries yet.</p>;
  }

  const hiddenCount = Math.max(0, events.length - COLLAPSED_EVENT_COUNT);
  const visibleEvents =
    expanded || hiddenCount === 0 ? events : events.slice(-COLLAPSED_EVENT_COUNT);

  return (
    <div>
      {hiddenCount > 0 ? (
        <button
          type="button"
          className="mb-3 inline-flex items-center gap-1.5 rounded-md px-1.5 py-1 text-[0.75rem] font-medium text-primary hover:bg-primary-50 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
          onClick={() => setExpanded((current) => !current)}
          aria-expanded={expanded}
        >
          {expanded ? (
            <>
              <ChevronUp className="h-3.5 w-3.5" />
              Show only the {COLLAPSED_EVENT_COUNT} most recent events
            </>
          ) : (
            <>
              <ChevronDown className="h-3.5 w-3.5" />
              Show {hiddenCount} earlier {hiddenCount === 1 ? "event" : "events"}
            </>
          )}
        </button>
      ) : null}

      {!expanded && hiddenCount > 0 ? (
        <p className="mb-3 text-[0.75rem] text-muted">
          Showing the {COLLAPSED_EVENT_COUNT} most recent events.
        </p>
      ) : null}

      <div className="max-h-[380px] overflow-y-auto pr-2">
        <ol className="space-y-4">
          {visibleEvents.map((event, idx) => {
            const meta = EVENT_META[event.event] ?? {
              label: event.event,
              icon: ShieldCheck,
              tone: "bg-page text-muted",
            };
            const Icon = meta.icon;
            return (
              <li key={event.id} className="relative flex gap-3">
                {idx < visibleEvents.length - 1 ? (
                  <span
                    className="absolute left-3 top-6 -bottom-4 w-px bg-line"
                    aria-hidden="true"
                  />
                ) : null}
                <span
                  className={`relative z-10 flex h-6 w-6 shrink-0 items-center justify-center rounded-full ${meta.tone}`}
                >
                  <Icon className="h-3 w-3" />
                </span>
                <div className="min-w-0 flex-1 pt-0.5">
                  <p className="text-[0.8125rem] font-medium text-ink">{meta.label}</p>
                  <p className="text-[0.75rem] text-muted">{formatDateTime(event.created_at)}</p>
                  {event.note ? (
                    <p className="mt-1 rounded-md bg-page px-2.5 py-1.5 text-[0.75rem] text-ink">{event.note}</p>
                  ) : null}
                </div>
              </li>
            );
          })}
        </ol>
      </div>
    </div>
  );
}
