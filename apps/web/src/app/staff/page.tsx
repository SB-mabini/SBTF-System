import { ClipboardList, Sparkles } from "lucide-react";

import { DocumentComplianceChart, ProcessingTimeChart } from "@/components/charts";
import {
  ExpiringPanel,
  OverviewCards,
  PendingQueue,
  PrescriptivePanel,
} from "@/components/dashboard/panels";
import { Card, CardHeader, EmptyState, LinkButton, SectionTitle } from "@/components/ui";
import {
  getAnalyticsOverview,
  getDocumentCompliance,
  getExpiringFranchises,
  getPendingApplicationsForStaff,
  getPrescriptiveIndicators,
  getProcessingTime,
} from "@/lib/data";
import { formatDays, formatNumber, formatPercent } from "@/lib/format";
import { requireStaff } from "@/lib/auth-guard";

export const metadata = { title: "Staff dashboard — SBTF System" };

export default async function StaffDashboardPage() {
  await requireStaff();

  const [overview, pending, processing, compliance, expiring, indicators] = await Promise.all([
    getAnalyticsOverview(),
    getPendingApplicationsForStaff(8),
    getProcessingTime(12),
    getDocumentCompliance(),
    getExpiringFranchises(90),
    getPrescriptiveIndicators(),
  ]);

  if (!overview) {
    return (
      <EmptyState
        title="No operational data available yet"
        description="The queue and the analytics appear once applications are submitted."
      />
    );
  }

  return (
    <div className="space-y-5">
      <SectionTitle
        title="Processing desk"
        description="Everything submitted by tricycle drivers and operators, and what needs a decision today."
        action={
          overview.pending_applications > 0 ? (
            <LinkButton href="/staff/applications?status=pending">
              <ClipboardList className="h-4 w-4" />
              Open the queue
            </LinkButton>
          ) : undefined
        }
      />

      <OverviewCards overview={overview} />

      <div className="grid gap-4 xl:grid-cols-5">
        <div className="xl:col-span-3">
          <PendingQueue
            applications={pending}
            basePath="/staff"
            description="Oldest first. Open an application to verify documents and record the decision."
          />
        </div>

        <Card className="xl:col-span-2">
          <CardHeader
            title="Today's service level"
            description="Processing performance and documentary verification."
            icon={Sparkles}
          />
          <dl className="space-y-2.5 text-[0.8125rem]">
            <Row label="Average processing time" value={formatDays(overview.avg_processing_days)} />
            <Row label="Median processing time" value={formatDays(overview.median_processing_days)} />
            <Row label="Decided in the last 30 days" value={formatNumber(overview.decided_last_30_days)} />
            <Row label="Submitted in the last 30 days" value={formatNumber(overview.submitted_last_30_days)} />
            <Row
              label="Pending documents"
              value={formatNumber(overview.pending_documents)}
            />
            <Row
              label="Verification rate"
              value={formatPercent(
                overview.verified_documents + overview.pending_documents + overview.rejected_documents === 0
                  ? null
                  : (overview.verified_documents /
                      (overview.verified_documents +
                        overview.pending_documents +
                        overview.rejected_documents)) *
                      100,
              )}
            />
            <Row label="Franchises expiring within 30 days" value={formatNumber(overview.expiring_30)} />
            <Row label="Expired franchises" value={formatNumber(overview.expired_franchises)} />
          </dl>
        </Card>
      </div>

      <PrescriptivePanel indicators={indicators} />

      <div className="grid gap-4 xl:grid-cols-2">
        <Card>
          <CardHeader title="Processing time" description="Service target: five days from submission to decision." />
          {processing.length === 0 ? <EmptyState title="No decided applications yet" /> : <ProcessingTimeChart data={processing} />}
        </Card>
        <Card>
          <CardHeader title="Documentary compliance" description="Verification rate per requirement." />
          {compliance.length === 0 ? <EmptyState title="No documents uploaded yet" /> : <DocumentComplianceChart data={compliance} />}
        </Card>
      </div>

      <ExpiringPanel rows={expiring} basePath="/staff" />
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-muted">{label}</dt>
      <dd className="text-right font-medium text-ink">{value}</dd>
    </div>
  );
}
