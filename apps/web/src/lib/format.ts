import {
  ACCOUNT_STATUS_LABELS,
  APPLICATION_STATUS_LABELS,
  APPLICATION_TYPE_LABELS,
  APP_TIME_ZONE,
  APP_TIME_ZONE_OFFSET,
  DOCUMENT_LABELS,
  ROLE_LABELS,
} from "@/lib/constants";
import type {
  AccountStatus,
  ActivityAction,
  ApplicationStatus,
  ApplicationType,
  DocumentType,
  Notification,
  UserRole,
} from "@/types/database";

function parseDate(value: string | null | undefined): Date | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function formatDate(value: string | null | undefined): string {
  const date = parseDate(value);
  if (!date) return "—";
  return date.toLocaleDateString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    timeZone: APP_TIME_ZONE,
  });
}

export function formatDateTime(value: string | null | undefined): string {
  const date = parseDate(value);
  if (!date) return "—";
  return date.toLocaleString("en-PH", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: APP_TIME_ZONE,
  });
}

/**
 * Formats a stored instant (UTC ISO string) as a `datetime-local` field value
 * in the municipality's time zone. An `<input type="datetime-local">` has no
 * zone, so it must be shown as the local wall-clock time — otherwise a 9:00 AM
 * booking reads back as its 01:00 UTC equivalent and is saved 8 hours off.
 */
export function toDateTimeLocalValue(value: string | null | undefined): string {
  const date = parseDate(value);
  if (!date) return "";
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: APP_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  })
    .formatToParts(date)
    .reduce<Record<string, string>>((accumulator, part) => {
      accumulator[part.type] = part.value;
      return accumulator;
    }, {});
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
}

/**
 * Converts a `datetime-local` value into the UTC instant it represents in the
 * municipality's time zone. The field carries no zone, and server actions run
 * on the server, so the zone must be pinned here rather than inferred from the
 * host — a UTC production server would otherwise shift every booking by 8h.
 */
export function fromDateTimeLocalValue(value: string): string {
  const withSeconds = value.length === 16 ? `${value}:00` : value;
  return new Date(`${withSeconds}${APP_TIME_ZONE_OFFSET}`).toISOString();
}

export function formatNumber(value: number | null | undefined): string {
  if (value === null || value === undefined) return "—";
  return new Intl.NumberFormat("en-PH").format(value);
}

export function formatPercent(value: number | null | undefined, digits = 1): string {
  if (value === null || value === undefined) return "—";
  return `${Number(value).toFixed(digits)}%`;
}

export function formatDays(value: number | null | undefined): string {
  if (value === null || value === undefined) return "—";
  const days = Number(value);
  if (!Number.isFinite(days)) return "—";
  // Zero elapsed time is not "one hour": it is simply less than a day.
  if (days <= 0) return "Less than a day";
  if (days < 1) {
    const hours = Math.max(Math.round(days * 24), 1);
    return `${hours} hour${hours === 1 ? "" : "s"}`;
  }
  return `${days.toFixed(days % 1 === 0 ? 0 : 1)} day${days === 1 ? "" : "s"}`;
}

export function relativeTime(value: string | null | undefined): string {
  const parsed = parseDate(value);
  if (!parsed) return "—";
  const then = parsed.getTime();
  const diffMs = Date.now() - then;
  const minutes = Math.round(diffMs / 60000);

  if (Math.abs(minutes) < 1) return "just now";
  if (Math.abs(minutes) < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (Math.abs(hours) < 24) return `${hours} hr ago`;
  const days = Math.round(hours / 24);
  if (Math.abs(days) < 30) return `${days} day${Math.abs(days) === 1 ? "" : "s"} ago`;
  return formatDate(value);
}

export function roleLabel(role: UserRole | null | undefined): string {
  return role ? ROLE_LABELS[role] ?? role : "—";
}

export function accountStatusLabel(status: AccountStatus | null | undefined): string {
  return status ? ACCOUNT_STATUS_LABELS[status] ?? status : "—";
}

export function applicationStatusLabel(status: ApplicationStatus): string {
  return APPLICATION_STATUS_LABELS[status];
}

export function applicationTypeLabel(type: ApplicationType): string {
  return APPLICATION_TYPE_LABELS[type];
}

export function documentLabel(type: DocumentType): string {
  return DOCUMENT_LABELS[type] ?? type;
}

const ACTION_LABELS: Record<ActivityAction, string> = {
  login: "Signed in",
  logout: "Signed out",
  registration: "Registered an account",
  profile_update: "Updated profile",
  notification_preferences_update: "Updated notification preferences",
  application_submitted: "Submitted an application",
  application_renewal_submitted: "Submitted a renewal application",
  document_upload: "Uploaded a document",
  document_replaced: "Replaced a document",
  document_verification: "Verified a document",
  review_started: "Started reviewing an application",
  application_approved: "Approved an application",
  application_rejected: "Rejected an application",
  record_created: "Issued a franchise record",
  record_update: "Updated a franchise record",
  franchise_archived: "Archived a franchise record",
  certificate_generation: "Generated a certificate",
  role_change: "Changed a user role",
  user_activated: "Activated an account",
  user_deactivated: "Deactivated an account",
  user_created: "Created a user account",
  settings_update: "Updated system settings",
  ai_request: "Requested AI decision support",
  renewal_reminder_sent: "Sent a renewal reminder",
  security_event: "Security event",
  stage_changed: "Updated the application stage",
  appointment_scheduled: "Scheduled an appointment",
  appointment_updated: "Updated an appointment",
  form_request_created: "Submitted a form request",
  form_request_issued: "Issued a form request",
  endorsement_recorded: "Recorded an endorsement",
  decision_recorded: "Recorded a decision",
  document_released: "Released documents",
};

export function actionLabel(action: ActivityAction | string): string {
  return ACTION_LABELS[action as ActivityAction] ?? String(action).replace(/_/g, " ");
}

export function fileSize(bytes: number | null | undefined): string {
  if (!bytes) return "—";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function humanizeKey(key: string): string {
  return key
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

export function initials(fullName: string): string {
  return fullName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}

/**
 * Where a notification points inside the console. Staff-only destinations are
 * suppressed for administrators, who have a read-only view of the same data.
 * Returns null when the notification has no navigable target.
 */
export function notificationTarget(
  notification: Pick<Notification, "target_type" | "target_id">,
  basePath: "/admin" | "/staff",
): { href: string; label: string } | null {
  const { target_type: type, target_id: id } = notification;
  if (!id) return null;

  if (type === "franchise_application") {
    return { href: `${basePath}/applications/${id}`, label: "Open application" };
  }
  if (type === "franchise_record") {
    return { href: `${basePath}/franchises/${id}`, label: "Open franchise record" };
  }
  if (type === "form_request" && basePath === "/staff") {
    return { href: "/staff/form-requests", label: "Open form requests" };
  }
  if (type === "appointment" && basePath === "/staff") {
    return { href: "/staff/appointments", label: "Open appointments" };
  }
  return null;
}
