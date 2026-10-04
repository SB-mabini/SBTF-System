import Link from "next/link";
import type { ReactNode } from "react";
import {
  AlertTriangle,
  CheckCircle2,
  Info,
  Loader2,
  XCircle,
} from "lucide-react";

/* -------------------------------------------------------------------------- */
/* Surfaces                                                                    */
/* -------------------------------------------------------------------------- */

export function Card({
  children,
  className = "",
  padded = true,
}: {
  children: ReactNode;
  className?: string;
  padded?: boolean;
}) {
  return (
    <section className={`sbtf-card ${padded ? "p-5" : ""} ${className}`}>{children}</section>
  );
}

export function CardHeader({
  title,
  description,
  action,
  icon: Icon,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  icon?: React.ComponentType<{ className?: string }>;
}) {
  return (
    <div className="mb-4 flex items-start justify-between gap-4">
      <div className="flex items-start gap-3">
        {Icon ? (
          <span className="mt-0.5 rounded-md bg-primary-50 p-2 text-primary">
            <Icon className="h-4 w-4" />
          </span>
        ) : null}
        <div>
          <h2 className="text-[1.0625rem] font-semibold text-ink">{title}</h2>
          {description ? <p className="mt-0.5 text-[0.8125rem] text-muted">{description}</p> : null}
        </div>
      </div>
      {action}
    </div>
  );
}

export function SectionTitle({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-ink">{title}</h1>
        {description ? <p className="mt-1 text-sm text-muted">{description}</p> : null}
      </div>
      {action}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* Buttons and links                                                           */
/* -------------------------------------------------------------------------- */

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger" | "outline";

const BUTTON_STYLES: Record<ButtonVariant, string> = {
  primary:
    "bg-primary text-white hover:bg-primary-600 disabled:bg-primary-300 focus-visible:outline-primary",
  secondary:
    "bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-100 disabled:opacity-60",
  outline:
    "bg-white text-ink border border-line-strong hover:bg-page disabled:opacity-60",
  ghost: "bg-transparent text-muted hover:bg-page hover:text-ink",
  danger: "bg-secondary-600 text-white hover:bg-secondary-700 disabled:opacity-60",
};

export function Button({
  children,
  variant = "primary",
  type = "button",
  disabled,
  loading,
  onClick,
  className = "",
  title,
}: {
  children: ReactNode;
  variant?: ButtonVariant;
  type?: "button" | "submit";
  disabled?: boolean;
  loading?: boolean;
  onClick?: () => void;
  className?: string;
  title?: string;
}) {
  return (
    <button
      type={type}
      title={title}
      disabled={disabled || loading}
      onClick={onClick}
      className={`inline-flex items-center justify-center gap-2 rounded-lg px-3.5 py-2 text-[0.8125rem] font-medium transition-colors disabled:cursor-not-allowed ${BUTTON_STYLES[variant]} ${className}`}
    >
      {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : null}
      {children}
    </button>
  );
}

export function LinkButton({
  href,
  children,
  variant = "primary",
  className = "",
}: {
  href: string;
  children: ReactNode;
  variant?: ButtonVariant;
  className?: string;
}) {
  return (
    <Link
      href={href}
      className={`inline-flex items-center justify-center gap-2 rounded-lg px-3.5 py-2 text-[0.8125rem] font-medium transition-colors ${BUTTON_STYLES[variant]} ${className}`}
    >
      {children}
    </Link>
  );
}

/* -------------------------------------------------------------------------- */
/* Badges                                                                      */
/* -------------------------------------------------------------------------- */

type BadgeTone =
  | "neutral"
  | "pending"
  | "approved"
  | "rejected"
  | "info"
  | "success"
  | "warning"
  | "danger";

const BADGE_STYLES: Record<BadgeTone, string> = {
  neutral: "bg-gray-100 text-gray-700 border-gray-200",
  pending: "bg-accent-50 text-accent-700 border-accent-100",
  approved: "bg-primary-50 text-primary-700 border-primary-100",
  rejected: "bg-secondary-50 text-secondary-700 border-secondary-100",
  info: "bg-info-50 text-info-600 border-indigo-100",
  success: "bg-success-50 text-success-600 border-emerald-100",
  warning: "bg-warning-50 text-warning-600 border-amber-100",
  danger: "bg-danger-50 text-danger-600 border-secondary-100",
};

export function Badge({
  children,
  tone = "neutral",
  className = "",
}: {
  children: ReactNode;
  tone?: BadgeTone;
  className?: string;
}) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[0.6875rem] font-medium ${BADGE_STYLES[tone]} ${className}`}
    >
      {children}
    </span>
  );
}

export function StatusBadge({ status }: { status: "pending" | "approved" | "rejected" }) {
  const tone: BadgeTone = status;
  const label =
    status === "pending" ? "Pending" : status === "approved" ? "Approved" : "Rejected";
  return (
    <Badge tone={tone}>
      <span
        className={`h-1.5 w-1.5 rounded-full ${
          status === "pending"
            ? "bg-accent-500"
            : status === "approved"
              ? "bg-primary-500"
              : "bg-secondary-500"
        }`}
      />
      {label}
    </Badge>
  );
}

export function DocumentStatusBadge({
  status,
}: {
  status: "pending" | "verified" | "rejected";
}) {
  if (status === "verified") {
    return (
      <Badge tone="success">
        <CheckCircle2 className="h-3 w-3" /> Verified
      </Badge>
    );
  }
  if (status === "rejected") {
    return (
      <Badge tone="rejected">
        <XCircle className="h-3 w-3" /> Rejected
      </Badge>
    );
  }
  return (
    <Badge tone="pending">
      <Info className="h-3 w-3" /> Pending
    </Badge>
  );
}

/* -------------------------------------------------------------------------- */
/* Dashboard primitives                                                        */
/* -------------------------------------------------------------------------- */

export function StatCard({
  label,
  value,
  hint,
  tone = "default",
  icon: Icon,
}: {
  label: string;
  value: ReactNode;
  hint?: string;
  tone?: "default" | "pending" | "approved" | "rejected" | "brand";
  icon?: React.ComponentType<{ className?: string }>;
}) {
  const accent =
    tone === "pending"
      ? "text-accent-700 bg-accent-50"
      : tone === "approved"
        ? "text-primary-700 bg-primary-50"
        : tone === "rejected"
          ? "text-secondary-600 bg-secondary-50"
          : tone === "brand"
            ? "text-white bg-primary"
            : "text-primary-700 bg-primary-50";

  return (
    <div className="sbtf-card p-4">
      <div className="flex items-start justify-between gap-3">
        <p className="text-[0.75rem] font-medium uppercase tracking-wide text-muted">{label}</p>
        {Icon ? (
          <span className={`rounded-md p-1.5 ${accent}`}>
            <Icon className="h-4 w-4" />
          </span>
        ) : null}
      </div>
      <p className="mt-2 text-2xl font-semibold tabular-nums text-ink">{value}</p>
      {hint ? <p className="mt-1 text-[0.75rem] text-muted">{hint}</p> : null}
    </div>
  );
}

export function EmptyState({
  title,
  description,
  action,
  icon: Icon = Info,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
  icon?: React.ComponentType<{ className?: string }>;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-line-strong bg-white px-6 py-12 text-center">
      <span className="rounded-full bg-page p-3 text-muted">
        <Icon className="h-5 w-5" />
      </span>
      <p className="mt-3 text-sm font-medium text-ink">{title}</p>
      {description ? <p className="mt-1 max-w-md text-[0.8125rem] text-muted">{description}</p> : null}
      {action ? <div className="mt-4">{action}</div> : null}
    </div>
  );
}

export function Alert({
  tone = "info",
  title,
  children,
}: {
  tone?: "info" | "success" | "warning" | "danger";
  title?: string;
  children?: ReactNode;
}) {
  const styles = {
    info: "border-primary-100 bg-primary-50 text-primary-800",
    success: "border-emerald-200 bg-success-50 text-success-600",
    warning: "border-amber-200 bg-warning-50 text-warning-600",
    danger: "border-secondary-100 bg-secondary-50 text-secondary-700",
  }[tone];

  const Icon =
    tone === "success" ? CheckCircle2 : tone === "danger" || tone === "warning" ? AlertTriangle : Info;

  return (
    <div className={`flex gap-2.5 rounded-lg border px-3.5 py-3 text-[0.8125rem] ${styles}`} role="status">
      <Icon className="mt-0.5 h-4 w-4 shrink-0" />
      <div>
        {title ? <p className="font-medium">{title}</p> : null}
        {children ? <div className={title ? "mt-0.5" : ""}>{children}</div> : null}
      </div>
    </div>
  );
}

export function AdvisoryBanner({ children }: { children?: ReactNode }) {
  return (
    <div className="rounded-lg border border-amber-200 bg-warning-50 px-3.5 py-2.5 text-[0.8125rem] font-medium text-warning-600">
      {children ?? "Advisory — For Decision Support Only"}
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* Form primitives                                                             */
/* -------------------------------------------------------------------------- */

export function Field({
  label,
  htmlFor,
  hint,
  error,
  children,
}: {
  label: string;
  htmlFor?: string;
  hint?: string;
  error?: string;
  children: ReactNode;
}) {
  return (
    <div>
      <label className="sbtf-label" htmlFor={htmlFor}>
        {label}
      </label>
      {children}
      {hint && !error ? <p className="sbtf-hint mt-1">{hint}</p> : null}
      {error ? <p className="mt-1 text-[0.75rem] text-secondary-600">{error}</p> : null}
    </div>
  );
}

export function Pagination({
  page,
  pageSize,
  count,
  onPageHref,
}: {
  page: number;
  pageSize: number;
  count: number;
  onPageHref: (page: number) => string;
}) {
  const totalPages = Math.max(Math.ceil(count / pageSize), 1);
  if (count === 0) return null;

  const from = (page - 1) * pageSize + 1;
  const to = Math.min(page * pageSize, count);

  return (
    <div className="flex items-center justify-between border-t border-line px-4 py-3 text-[0.8125rem] text-muted">
      <span>
        Showing <span className="font-medium text-ink">{from}</span>–
        <span className="font-medium text-ink">{to}</span> of{" "}
        <span className="font-medium text-ink">{count}</span>
      </span>
      <div className="flex items-center gap-2">
        <Link
          aria-disabled={page <= 1}
          className={`rounded-md border px-2.5 py-1 ${
            page <= 1
              ? "pointer-events-none border-line text-line-strong"
              : "border-line-strong text-ink hover:bg-page"
          }`}
          href={onPageHref(Math.max(page - 1, 1))}
        >
          Previous
        </Link>
        <span className="tabular-nums">
          Page {page} of {totalPages}
        </span>
        <Link
          aria-disabled={page >= totalPages}
          className={`rounded-md border px-2.5 py-1 ${
            page >= totalPages
              ? "pointer-events-none border-line text-line-strong"
              : "border-line-strong text-ink hover:bg-page"
          }`}
          href={onPageHref(Math.min(page + 1, totalPages))}
        >
          Next
        </Link>
      </div>
    </div>
  );
}

export function TableWrap({ children }: { children: ReactNode }) {
  return <div className="overflow-x-auto">{children}</div>;
}

export function Spinner({ label }: { label?: string }) {
  return (
    <span className="inline-flex items-center gap-2 text-[0.8125rem] text-muted">
      <Loader2 className="h-4 w-4 animate-spin" />
      {label ?? "Loading…"}
    </span>
  );
}
