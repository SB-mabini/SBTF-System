import {
  Archive,
  CalendarCheck,
  CalendarX,
  Eye,
  FileCheck2,
  FileUp,
  RefreshCw,
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
};

export function StatusTimeline({ events }: { events: ApplicationStatusHistory[] }) {
  if (events.length === 0) {
    return <p className="text-[0.8125rem] text-muted">No timeline entries yet.</p>;
  }

  return (
    <ol className="relative space-y-4 border-l border-line pl-5">
      {events.map((event) => {
        const meta = EVENT_META[event.event] ?? {
          label: event.event,
          icon: ShieldCheck,
          tone: "bg-page text-muted",
        };
        const Icon = meta.icon;
        return (
          <li key={event.id} className="relative">
            <span className={`absolute -left-[1.9rem] rounded-full p-1.5 ${meta.tone}`}>
              <Icon className="h-3 w-3" />
            </span>
            <p className="text-[0.8125rem] font-medium text-ink">{meta.label}</p>
            <p className="text-[0.75rem] text-muted">{formatDateTime(event.created_at)}</p>
            {event.note ? (
              <p className="mt-1 rounded-md bg-page px-2.5 py-1.5 text-[0.75rem] text-ink">{event.note}</p>
            ) : null}
          </li>
        );
      })}
    </ol>
  );
}
