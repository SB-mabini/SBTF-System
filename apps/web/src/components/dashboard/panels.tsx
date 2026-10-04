import Link from "next/link";
import {
  AlertTriangle,
  ArrowRight,
  CalendarClock,
  CheckCircle2,
  Clock,
  FileCheck2,
  FileText,
  Gauge,
  Info,
  ShieldAlert,
  Sparkles,
  Stamp,
  TrendingUp,
  Users,
} from "lucide-react";

import {
  ApplicationTypeChart,
  DecisionMixChart,
  TodaComparisonChart,
  ApplicationTrendChart,
} from "@/components/charts";
import { Badge, Card, CardHeader, EmptyState, StatCard, StatusBadge } from "@/components/ui";
import {
  applicationTypeLabel,
  formatDate,
  formatDays,
  formatNumber,
  formatPercent,
  relativeTime,
} from "@/lib/format";
import type {
  AnalyticsOverview,
  ExpiringRecord,
  FranchiseApplicationDetail,
  PrescriptiveIndicator,
  TodaAnalytics,
  TrendPoint,
} from "@/types/database";

/* -------------------------------------------------------------------------- */
/* Summary cards                                                               */
/* -------------------------------------------------------------------------- */

export function OverviewCards({ overview }: { overview: AnalyticsOverview }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      <StatCard
        label="Total applications"
        value={formatNumber(overview.total_applications)}
        hint={`${formatNumber(overview.new_applications)} new · ${formatNumber(overview.renewal_applications)} renewal`}
        icon={FileText}
      />
      <StatCard
        label="Pending review"
        value={formatNumber(overview.pending_applications)}
        hint={`${formatNumber(overview.pending_documents)} document(s) awaiting verification`}
        tone="pending"
        icon={Clock}
      />
      <StatCard
        label="Approved"
        value={formatNumber(overview.approved_applications)}
        hint={`Approval rate ${formatPercent(overview.approval_rate)}`}
        tone="approved"
        icon={CheckCircle2}
      />
      <StatCard
        label="Rejected"
        value={formatNumber(overview.rejected_applications)}
        hint={`Rejection rate ${formatPercent(overview.rejection_rate)}`}
        tone="rejected"
        icon={AlertTriangle}
      />

      <StatCard
        label="Active franchises"
        value={formatNumber(overview.active_franchises)}
        hint={`${formatNumber(overview.expired_franchises)} expired · ${formatNumber(overview.expiring_30)} expiring within 30 days`}
        icon={Stamp}
      />
      <StatCard
        label="Registered drivers"
        value={formatNumber(overview.active_drivers)}
        hint={`${formatNumber(overview.total_todas)} TODAs · ${formatNumber(overview.total_toda_members)} masterlist members`}
        icon={Users}
      />
      <StatCard
        label="Average processing time"
        value={formatDays(overview.avg_processing_days)}
        hint={`Median ${formatDays(overview.median_processing_days)} from submission to decision`}
        icon={Gauge}
      />
      <StatCard
        label="Submitted in last 30 days"
        value={formatNumber(overview.submitted_last_30_days)}
        hint={`Previous 30 days: ${formatNumber(overview.submitted_previous_30_days)} · decided: ${formatNumber(overview.decided_last_30_days)}`}
        icon={TrendingUp}
      />
    </div>
  );
}

/* -------------------------------------------------------------------------- */
/* Charts                                                                      */
/* -------------------------------------------------------------------------- */

export function TrendsAndMix({
  trends,
  overview,
}: {
  trends: TrendPoint[];
  overview: AnalyticsOverview;
}) {
  return (
    <div className="grid gap-4 xl:grid-cols-3">
      <Card className="xl:col-span-2">
        <CardHeader
          title="Application volume"
          description="Submissions, approvals and rejections over the last 12 months."
          icon={TrendingUp}
        />
        {trends.length === 0 ? (
          <EmptyState title="No application data yet" description="Trends appear once applications are submitted." />
        ) : (
          <ApplicationTrendChart data={trends} />
        )}
      </Card>

      <Card>
        <CardHeader title="Decision mix" description="All applications by current status." icon={FileCheck2} />
        <DecisionMixChart
          approved={overview.approved_applications}
          pending={overview.pending_applications}
          rejected={overview.rejected_applications}
        />
        <dl className="mt-3 space-y-1.5 border-t border-line pt-3 text-[0.8125rem]">
          <div className="flex justify-between">
            <dt className="text-muted">Documentary requirements verified</dt>
            <dd className="font-medium text-ink">{formatNumber(overview.verified_documents)}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-muted">Waiting for verification</dt>
            <dd className="font-medium text-ink">{formatNumber(overview.pending_documents)}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-muted">Expiring within 60 days</dt>
            <dd className="font-medium text-ink">{formatNumber(overview.expiring_60)}</dd>
          </div>
        </dl>
      </Card>
    </div>
  );
}

export function RenewalMixChart({ trends }: { trends: TrendPoint[] }) {
  if (trends.length === 0) return null;
  return (
    <Card>
      <CardHeader
        title="New versus renewal"
        description="Renewal load drives counter staffing; new applications drive registration work."
        icon={CalendarClock}
      />
      <ApplicationTypeChart data={trends} />
    </Card>
  );
}

export function TodaPanel({ rows, limit = 10 }: { rows: TodaAnalytics[]; limit?: number }) {
  return (
    <Card>
      <CardHeader
        title="Applications per TODA"
        description={`Top ${Math.min(limit, rows.length)} of ${rows.length} associations by application volume.`}
        icon={Users}
      />
      {rows.length === 0 ? (
        <EmptyState title="No TODA activity yet" />
      ) : (
        <TodaComparisonChart data={rows.slice(0, limit)} />
      )}
    </Card>
  );
}

/* -------------------------------------------------------------------------- */
/* Pending queue                                                               */
/* -------------------------------------------------------------------------- */

export function PendingQueue({
  applications,
  basePath,
  title = "Applications awaiting review",
  description,
  emptyDescription = "Every submitted application has been decided.",
}: {
  applications: FranchiseApplicationDetail[];
  basePath: "/admin" | "/staff";
  title?: string;
  description?: string;
  emptyDescription?: string;
}) {
  return (
    <Card>
      <CardHeader
        title={title}
        description={description ?? "Oldest first — the queue is ordered by submission time."}
        icon={Clock}
        action={
          <Link
            className="inline-flex items-center gap-1 text-[0.8125rem] font-medium text-primary hover:underline"
            href={`${basePath}/applications?status=pending`}
          >
            Open queue
            <ArrowRight className="h-3.5 w-3.5" />
          </Link>
        }
      />
      {applications.length === 0 ? (
        <EmptyState title="Nothing pending" description={emptyDescription} icon={CheckCircle2} />
      ) : (
        <ul className="divide-y divide-line">
          {applications.map((application) => (
            <li key={application.id} className="flex items-center justify-between gap-3 py-3">
              <div className="min-w-0">
                <Link
                  className="font-mono text-[0.8125rem] font-medium text-primary hover:underline"
                  href={`${basePath}/applications/${application.id}`}
                >
                  {application.application_number}
                </Link>
                <p className="mt-0.5 truncate text-[0.8125rem] text-ink">
                  {application.operator_first_name} {application.operator_last_name} ·{" "}
                  {application.plate_number}
                </p>
                <p className="text-[0.75rem] text-muted">
                  {application.toda?.name ?? "TODA not set"} ·{" "}
                  {applicationTypeLabel(application.application_type)} · submitted{" "}
                  {relativeTime(application.submitted_at)}
                </p>
              </div>
              <StatusBadge status={application.status} />
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

/* -------------------------------------------------------------------------- */
/* Prescriptive indicators                                                     */
/* -------------------------------------------------------------------------- */

const INDICATOR_ICONS: Record<string, React.ComponentType<{ className?: string }>> = {
  peak_period_staffing: TrendingUp,
  pending_backlog: Clock,
  document_verification_backlog: FileCheck2,
  approval_rate_movement: Gauge,
  renewal_pipeline: CalendarClock,
  expired_unrenewed: ShieldAlert,
  processing_time: Gauge,
  toda_outreach: Users,
};

export function PrescriptivePanel({
  indicators,
  compact = false,
}: {
  indicators: PrescriptiveIndicator[];
  compact?: boolean;
}) {
  return (
    <Card>
      <CardHeader
        title="Prescriptive decision support"
        description="Rule-based indicators computed from the same aggregates as the charts. Advisory only."
        icon={Sparkles}
      />

      <div className="mb-3 rounded-lg border border-amber-200 bg-warning-50 px-3 py-2 text-[0.75rem] font-medium text-warning-600">
        Advisory — For Decision Support Only. The system never approves, rejects or alters a record
        on the basis of these indicators.
      </div>

      {indicators.length === 0 ? (
        <EmptyState
          title="No indicator is outside its threshold"
          description="Volume, backlog, processing time and renewal coverage are all within the configured limits."
          icon={CheckCircle2}
        />
      ) : (
        <ul className="space-y-3">
          {indicators.map((indicator) => {
            const Icon = INDICATOR_ICONS[indicator.indicator_key] ?? Info;
            const critical = indicator.severity === "critical";
            return (
              <li
                key={indicator.indicator_key}
                className={`rounded-lg border p-3.5 ${
                  critical ? "border-secondary-100 bg-secondary-50/60" : "border-line bg-page/60"
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-start gap-2.5">
                    <span
                      className={`mt-0.5 rounded-md p-1.5 ${
                        critical ? "bg-secondary-100 text-secondary-700" : "bg-primary-50 text-primary-700"
                      }`}
                    >
                      <Icon className="h-3.5 w-3.5" />
                    </span>
                    <div>
                      <p className="text-[0.8125rem] font-semibold text-ink">{indicator.category}</p>
                      <p className="mt-1 text-[0.8125rem] text-ink">{indicator.finding}</p>
                    </div>
                  </div>
                  <Badge tone={critical ? "danger" : "warning"}>{critical ? "Critical" : "Attention"}</Badge>
                </div>

                <p className="mt-2.5 text-[0.8125rem] text-muted">
                  <span className="font-medium text-ink">Recommendation: </span>
                  {indicator.recommendation}
                </p>

                {!compact ? (
                  <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-[0.75rem] text-muted">
                    <span>Data basis: {indicator.data_basis}</span>
                    {indicator.metric_value !== null ? (
                      <span>
                        Measured: <span className="font-medium text-ink">{indicator.metric_value}</span>
                      </span>
                    ) : null}
                    {indicator.threshold_value !== null ? (
                      <span>
                        Threshold: <span className="font-medium text-ink">{indicator.threshold_value}</span>
                      </span>
                    ) : null}
                  </div>
                ) : null}
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}

/* -------------------------------------------------------------------------- */
/* Expiring franchises                                                         */
/* -------------------------------------------------------------------------- */

export function ExpiringPanel({
  rows,
  basePath,
  limit = 8,
}: {
  rows: ExpiringRecord[];
  basePath: "/admin" | "/staff";
  limit?: number;
}) {
  return (
    <Card>
      <CardHeader
        title="Franchises approaching expiry"
        description="Renewal reminders are raised automatically at 90, 60 and 30 days before expiry."
        icon={CalendarClock}
        action={
          <Link
            className="inline-flex items-center gap-1 text-[0.8125rem] font-medium text-primary hover:underline"
            href={`${basePath}/franchises?state=expiring`}
          >
            All records
            <ArrowRight className="h-3.5 w-3.5" />
          </Link>
        }
      />
      {rows.length === 0 ? (
        <EmptyState title="No franchise is close to expiry" icon={CheckCircle2} />
      ) : (
        <div className="overflow-x-auto">
          <table className="sbtf-table">
            <thead>
              <tr>
                <th>Franchise</th>
                <th>Operator</th>
                <th>TODA</th>
                <th>Expires</th>
                <th>Remaining</th>
              </tr>
            </thead>
            <tbody>
              {rows.slice(0, limit).map((row) => (
                <tr key={row.record_id}>
                  <td>
                    <Link
                      className="font-mono text-[0.8125rem] text-primary hover:underline"
                      href={`${basePath}/franchises/${row.record_id}`}
                    >
                      {row.franchise_number}
                    </Link>
                  </td>
                  <td>{row.operator_name}</td>
                  <td className="text-muted">{row.toda_name ?? "—"}</td>
                  <td>{formatDate(row.expires_at)}</td>
                  <td>
                    {row.days_remaining < 0 ? (
                      <Badge tone="danger">Expired {Math.abs(row.days_remaining)} days ago</Badge>
                    ) : row.days_remaining <= 30 ? (
                      <Badge tone="warning">{row.days_remaining} days</Badge>
                    ) : (
                      <Badge tone="neutral">{row.days_remaining} days</Badge>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
