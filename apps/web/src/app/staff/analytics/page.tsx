import { FileBarChart, Stamp } from "lucide-react";

import { DocumentComplianceChart, ProcessingTimeChart, TodaComparisonChart } from "@/components/charts";
import { OverviewCards, PrescriptivePanel } from "@/components/dashboard/panels";
import { Card, CardHeader, EmptyState, SectionTitle } from "@/components/ui";
import {
  getAnalyticsOverview,
  getApplicationsByToda,
  getDocumentCompliance,
  getExpiringFranchises,
  getPrescriptiveIndicators,
  getProcessingTime,
} from "@/lib/data";
import { formatDate, formatDays, formatNumber, formatPercent } from "@/lib/format";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Analytics — SBTF Staff" };

export default async function StaffAnalyticsPage() {
  await requireStaff();

  const [overview, processing, compliance, todaRows, expiring, indicators] = await Promise.all([
    getAnalyticsOverview(),
    getProcessingTime(12),
    getDocumentCompliance(),
    getApplicationsByToda(),
    getExpiringFranchises(90),
    getPrescriptiveIndicators(),
  ]);

  if (!overview) return <EmptyState title="No analytics available yet" />;

  return (
    <div className="space-y-5">
      <SectionTitle
        title="Operational analytics"
        description="How the processing desk is performing, which requirements cause delays, and where the workload is concentrated."
      />

      <OverviewCards overview={overview} />

      <div className="grid gap-4 xl:grid-cols-2">
        <Card>
          <CardHeader
            title="Processing time"
            description={`Service target: five days. Current average ${formatDays(overview.avg_processing_days)}.`}
            icon={FileBarChart}
          />
          {processing.length === 0 ? (
            <EmptyState title="No decided applications yet" />
          ) : (
            <ProcessingTimeChart data={processing} />
          )}
        </Card>

        <Card>
          <CardHeader
            title="Document verification"
            description="Verification rate per requirement; the oldest pending document shows where the queue is stuck."
            icon={Stamp}
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
          title="Workload by association"
          description="Where the submissions come from, and which associations are renewing on time."
        />
        {todaRows.length === 0 ? (
          <EmptyState title="No TODA activity yet" />
        ) : (
          <TodaComparisonChart data={todaRows} />
        )}
      </Card>

      <PrescriptivePanel indicators={indicators} />

      <Card>
        <CardHeader
          title="Renewal follow-up list"
          description="Franchises expiring within 90 days, most urgent first. Reminders are sent automatically at 90, 60 and 30 days."
        />
        {expiring.length === 0 ? (
          <EmptyState title="No franchise is close to expiry" />
        ) : (
          <div className="overflow-x-auto">
            <table className="sbtf-table">
              <thead>
                <tr>
                  <th>Franchise</th>
                  <th>Operator</th>
                  <th>TODA</th>
                  <th>Expires</th>
                  <th className="text-right">Days remaining</th>
                  <th>Bucket</th>
                </tr>
              </thead>
              <tbody>
                {expiring.map((row) => (
                  <tr key={row.record_id}>
                    <td className="font-mono text-[0.8125rem]">{row.franchise_number}</td>
                    <td>{row.operator_name}</td>
                    <td className="text-muted">{row.toda_name ?? "—"}</td>
                    <td>{formatDate(row.expires_at)}</td>
                    <td className="text-right tabular-nums">{row.days_remaining}</td>
                    <td>{row.bucket}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Card>
        <CardHeader title="Reading the numbers" />
        <ul className="space-y-2 text-[0.8125rem] text-muted">
          <li>
            Approval rate is calculated over decided applications:{" "}
            <span className="font-medium text-ink">{formatPercent(overview.approval_rate)}</span>.
          </li>
          <li>
            {formatNumber(overview.pending_documents)} document(s) are still waiting for verification
            and {formatNumber(overview.pending_applications)} application(s) are pending overall.
          </li>
          <li>
            {formatNumber(overview.expiring_30)} franchise(s) expire within 30 days and{" "}
            {formatNumber(overview.expired_franchises)} have already lapsed.
          </li>
        </ul>
      </Card>
    </div>
  );
}
