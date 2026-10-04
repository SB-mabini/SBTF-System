import {
  APPLICATION_STATUS_LABELS,
  APPLICATION_TYPE_LABELS,
  DOCUMENT_LABELS,
  ROLE_LABELS,
} from "@/lib/constants";
import type {
  ActivityAction,
  ApplicationStatus,
  ApplicationType,
  DocumentType,
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
  });
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
