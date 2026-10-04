import Link from "next/link";
import { Activity, Database, FileBarChart, HardDrive, Sparkles, Users } from "lucide-react";

import { DocumentComplianceChart, ProcessingTimeChart } from "@/components/charts";
import {
  ExpiringPanel,
  OverviewCards,
  PrescriptivePanel,
  RenewalMixChart,
  TodaPanel,
  TrendsAndMix,
} from "@/components/dashboard/panels";
import { Badge, Card, CardHeader, EmptyState, LinkButton, SectionTitle } from "@/components/ui";
import {
  getAnalyticsOverview,
  getApplicationTrends,
  getApplicationsByToda,
  getDocumentCompliance,
  getExpiringFranchises,
  getPrescriptiveIndicators,
  getProcessingTime,
  getRecentDecisions,
  getSystemHealth,
} from "@/lib/data";
import { formatDateTime, formatNumber, formatPercent, relativeTime } from "@/lib/format";
import { requireAdministrator } from "@/lib/auth-guard";

export const metadata = { title: "Administrator dashboard — SBTF System" };

export default async function AdminDashboardPage() {
  await requireAdministrator();

  const [
    overview,
    trends,
    todaRows,
    processing,
    compliance,
    expiring,
    indicators,
    health,
    recent,
  ] = await Promise.all([
    getAnalyticsOverview(),
    getApplicationTrends(12),
    getApplicationsByToda(),
    getProcessingTime(12),
    getDocumentCompliance(),
    getExpiringFranchises(90),
    getPrescriptiveIndicators(),
    getSystemHealth(),
    getRecentDecisions(6),
  ]);

  if (!overview) {
    return (
      <EmptyState
        title="No analytics available yet"
        description="Descriptive analytics appear once the first applications are submitted."
      />
    );
  }

  return (
    <div className="space-y-5">
      <SectionTitle
        title="Municipal franchise overview"
        description="Descriptive statistics, prescriptive indicators and system health for the Mabini tricycle franchising office."
        action={
          <div className="flex gap-2">
            <LinkButton href="/admin/reports" variant="outline">
              <FileBarChart className="h-4 w-4" />
              Reports
            </LinkButton>
            <LinkButton href="/admin/ai-support">
              <Sparkles className="h-4 w-4" />
              AI decision support
            </LinkButton>
          </div>
        }
      />

      <OverviewCards overview={overview} />

      <TrendsAndMix trends={trends} overview={overview} />

      <div className="grid gap-4 xl:grid-cols-2">
        <RenewalMixChart trends={trends} />
        <TodaPanel rows={todaRows} />
      </div>

      <PrescriptivePanel indicators={indicators} />

      <div className="grid gap-4 xl:grid-cols-2">
        <Card>
          <CardHeader
            title="Processing time"
            description="Days from submission to decision; the service target is five days."
            icon={Activity}
          />
          {processing.length === 0 ? (
            <EmptyState title="No decided applications yet" />
          ) : (
            <ProcessingTimeChart data={processing} />
          )}
        </Card>

        <Card>
          <CardHeader
            title="Documentary compliance"
            description="Share of uploaded requirements that pass verification."
            icon={Database}
          />
          {compliance.length === 0 ? (
            <EmptyState title="No documents uploaded yet" />
          ) : (
            <DocumentComplianceChart data={compliance} />
          )}
        </Card>
      </div>

      <ExpiringPanel rows={expiring} basePath="/admin" />

      <div className="grid gap-4 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader
            title="Recent decisions"
            description="The latest approvals and rejections across the municipality."
            icon={FileBarChart}
          />
          {recent.length === 0 ? (
            <EmptyState title="No decisions recorded yet" />
          ) : (
            <ul className="divide-y divide-line">
              {recent.map((application) => (
                <li key={application.id} className="flex items-center justify-between gap-3 py-3">
                  <div className="min-w-0">
                    <Link
                      className="font-mono text-[0.8125rem] font-medium text-primary hover:underline"
                      href={`/admin/applications/${application.id}`}
                    >
                      {application.application_number}
                    </Link>
                    <p className="truncate text-[0.8125rem] text-ink">
                      {application.operator_first_name} {application.operator_last_name} ·{" "}
                      {application.plate_number}
                    </p>
                    <p className="text-[0.75rem] text-muted">
                      {application.toda?.name ?? "—"} · decided {relativeTime(application.reviewed_at)}
                      {application.reviewer?.full_name ? ` by ${application.reviewer.full_name}` : ""}
                    </p>
                  </div>
                  <Badge tone={application.status === "approved" ? "approved" : "rejected"}>
                    {application.status === "approved" ? "Approved" : "Rejected"}
                  </Badge>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card>
          <CardHeader title="System health" description="Accounts, audit volume and storage." icon={HardDrive} />
          {!health ? (
            <EmptyState title="Health data is unavailable" description="Administrator access is required." />
          ) : (
            <dl className="space-y-2.5 text-[0.8125rem]">
              <Health label="Accounts" value={formatNumber(health.users_total)} />
              <Health
                label="Administrators"
                value={`${formatNumber(health.users_administrators)} (${formatPercent(
                  (health.users_administrators / Math.max(health.users_total, 1)) * 100,
                )})`}
              />
              <Health label="Staff" value={formatNumber(health.users_staff)} />
              <Health label="Drivers and operators" value={formatNumber(health.users_drivers)} />
              <Health label="Inactive or suspended" value={formatNumber(health.users_inactive)} />
              <Health label="Audit entries (7 days)" value={formatNumber(health.activity_logs_7d)} />
              <Health
                label="AI requests (30 days)"
                value={`${formatNumber(health.ai_requests_30d)} · ${formatNumber(health.ai_requests_failed_30d)} failed`}
              />
              <Health label="Certificates issued" value={formatNumber(health.certificates_issued)} />
              <Health
                label="Stored files"
                value={`${formatNumber(health.document_objects)} documents · ${formatNumber(
                  health.certificate_objects,
                )} certificates`}
              />
              <Health label="Last activity" value={formatDateTime(health.last_activity_at)} />
            </dl>
          )}

          <div className="mt-4 border-t border-line pt-3">
            <Link
              className="inline-flex items-center gap-1.5 text-[0.8125rem] font-medium text-primary hover:underline"
              href="/admin/users"
            >
              <Users className="h-3.5 w-3.5" />
              Manage users and roles
            </Link>
          </div>
        </Card>
      </div>
    </div>
  );
}

function Health({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <dt className="text-muted">{label}</dt>
      <dd className="text-right font-medium text-ink">{value}</dd>
    </div>
  );
}
