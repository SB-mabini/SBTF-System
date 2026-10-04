import { BarChart3, Clock, FileStack, Users } from "lucide-react";

import {
  DocumentComplianceChart,
  ProcessingTimeChart,
  TodaComparisonChart,
} from "@/components/charts";
import { OverviewCards, PrescriptivePanel } from "@/components/dashboard/panels";
import { Card, CardHeader, EmptyState, SectionTitle } from "@/components/ui";
import {
  getAnalyticsOverview,
  getApplicationTrends,
  getApplicationsByToda,
  getDocumentCompliance,
  getExpiringFranchises,
  getPrescriptiveIndicators,
  getProcessingTime,
} from "@/lib/data";
import { formatDate, formatDays, formatNumber, formatPercent } from "@/lib/format";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Analytics — SBTF Administrator" };

export default async function AdminAnalyticsPage() {
  await requireAdministrator();

  const [overview, trends, todaRows, processing, compliance, expiring, indicators] = await Promise.all([
    getAnalyticsOverview(),
    getApplicationTrends(12),
    getApplicationsByToda(),
    getProcessingTime(12),
    getDocumentCompliance(),
    getExpiringFranchises(90),
    getPrescriptiveIndicators(),
  ]);

  if (!overview) {
    return <EmptyState title="No analytics available yet" />;
  }

  const busiestMonth = [...trends].sort((a, b) => b.submitted - a.submitted)[0];
  const silentTodas = todaRows.filter((row) => row.applications < row.members_count * 0.5);

  return (
    <div className="space-y-5">
      <SectionTitle
        title="Descriptive and prescriptive analytics"
        description="Counts, rates and distributions computed in PostgreSQL from the live records, followed by rule-based recommendations for the franchising office."
      />

      <OverviewCards overview={overview} />

      <div className="grid gap-4 xl:grid-cols-2">
        <Card>
          <CardHeader
            title="Monthly service performance"
            description="Submission, decision and turnaround figures per month with the five-day target."
            icon={Clock}
          />
          {processing.length === 0 ? (
            <EmptyState title="No decided applications yet" />
          ) : (
            <ProcessingTimeChart data={processing} />
          )}
        </Card>

        <Card>
          <CardHeader
            title="Documentary compliance by requirement"
            description="Verification rate and the age of the oldest pending document."
            icon={FileStack}
          />
          {compliance.length === 0 ? (
            <EmptyState title="No documents uploaded yet" />
          ) : (
            <DocumentComplianceChart data={compliance} />
          )}
        </Card>
      </div>

      <Card>
        <CardHeader
          title="Franchise activity by association"
          description="Applications, members and active franchises for every TODA in the municipality."
          icon={BarChart3}
        />
        {todaRows.length === 0 ? (
          <EmptyState title="No TODA activity yet" />
        ) : (
          <>
            <TodaComparisonChart data={todaRows} />
            <div className="mt-4 overflow-x-auto">
              <table className="sbtf-table">
                <thead>
                  <tr>
                    <th>TODA</th>
                    <th className="text-right">Members</th>
                    <th className="text-right">Applications</th>
                    <th className="text-right">Approved</th>
                    <th className="text-right">Pending</th>
                    <th className="text-right">Rejected</th>
                    <th className="text-right">Active franchises</th>
                    <th className="text-right">Approval rate</th>
                    <th>Last submission</th>
                  </tr>
                </thead>
                <tbody>
                  {todaRows.map((row) => (
                    <tr key={row.toda_id}>
                      <td className="font-medium text-ink">{row.toda_name}</td>
                      <td className="text-right tabular-nums">{formatNumber(row.members_count)}</td>
                      <td className="text-right tabular-nums">{formatNumber(row.applications)}</td>
                      <td className="text-right tabular-nums">{formatNumber(row.approved)}</td>
                      <td className="text-right tabular-nums">{formatNumber(row.pending)}</td>
                      <td className="text-right tabular-nums">{formatNumber(row.rejected)}</td>
                      <td className="text-right tabular-nums">{formatNumber(row.active_franchises)}</td>
                      <td className="text-right tabular-nums">{formatPercent(row.approval_rate)}</td>
                      <td>{row.last_submission_at ? formatDate(row.last_submission_at) : "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </Card>

      <div className="grid gap-4 xl:grid-cols-3">
        <Card className="xl:col-span-1">
          <CardHeader title="Interpretation notes" icon={Users} />
          <ul className="space-y-3 text-[0.8125rem] text-muted">
            <li>
              <span className="font-medium text-ink">Approval rate</span> counts decided
              applications only (approved ÷ decided), so a large pending queue does not distort it.
            </li>
            <li>
              <span className="font-medium text-ink">Processing time</span> is measured from
              submission to decision and is reported as average, median and 90th percentile; the
              median resists the effect of a few slow cases.
            </li>
            <li>
              <span className="font-medium text-ink">Silent associations</span> are TODAs whose
              application volume is below half of their masterlist size — a registration-coverage
              signal, not a compliance finding.
            </li>
            <li>
              {busiestMonth ? (
                <>
                  <span className="font-medium text-ink">Busiest month</span>:{" "}
                  {busiestMonth.month_label} with {formatNumber(busiestMonth.submitted)} submission(s).
                </>
              ) : (
                "No monthly peak can be identified yet."
              )}
            </li>
            <li>
              <span className="font-medium text-ink">Expiring franchises</span> within 90 days:{" "}
              {formatNumber(overview.expiring_90)}; average processing time{" "}
              {formatDays(overview.avg_processing_days)}.
            </li>
          </ul>
        </Card>

        <div className="xl:col-span-2">
          <PrescriptivePanel indicators={indicators} />
        </div>
      </div>

      <Card>
        <CardHeader
          title="Renewal pipeline"
          description="Franchises grouped by remaining validity; nothing here changes a record."
          icon={Clock}
        />
        {["expired", "0-30 days", "31-60 days", "61-90 days", "91+ days"].map((bucket) => {
          const rows = expiring.filter((row) => row.bucket === bucket);
          if (rows.length === 0) return null;
          return (
            <div key={bucket} className="mb-4 last:mb-0">
              <p className="mb-2 text-[0.75rem] font-semibold uppercase tracking-wide text-muted">
                {bucket === "expired" ? "Expired" : `Expiring in ${bucket}`} — {rows.length}
              </p>
              <div className="overflow-x-auto">
                <table className="sbtf-table">
                  <thead>
                    <tr>
                      <th>Franchise</th>
                      <th>Operator</th>
                      <th>TODA</th>
                      <th>Expires</th>
                      <th className="text-right">Days remaining</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.slice(0, 10).map((row) => (
                      <tr key={row.record_id}>
                        <td className="font-mono text-[0.8125rem]">{row.franchise_number}</td>
                        <td>{row.operator_name}</td>
                        <td className="text-muted">{row.toda_name ?? "—"}</td>
                        <td>{formatDate(row.expires_at)}</td>
                        <td className="text-right tabular-nums">{row.days_remaining}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          );
        })}
        {expiring.length === 0 ? <EmptyState title="No franchise is near expiry" /> : null}
        {silentTodas.length > 0 ? (
          <p className="mt-3 rounded-md bg-page px-3 py-2 text-[0.75rem] text-muted">
            TODAs with low registration coverage: {silentTodas.map((row) => row.toda_name).join(", ")}.
          </p>
        ) : null}
      </Card>
    </div>
  );
}
