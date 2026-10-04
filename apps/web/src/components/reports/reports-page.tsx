import { BarChart3, FileDown, FileText, History, Stamp, Users } from "lucide-react";

import { Badge, Card, CardHeader, SectionTitle } from "@/components/ui";
import {
  getAnalyticsOverview,
  getDocumentCompliance,
  getExpiringFranchises,
  getProcessingTime,
  listApplications,
  listFranchiseRecords,
} from "@/lib/data";
import { formatDate, formatDays, formatNumber, formatPercent } from "@/lib/format";
import type { SessionContext } from "@/lib/data";

interface ReportDefinition {
  dataset: string;
  title: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  adminOnly?: boolean;
  columns: string[];
}

const REPORTS: ReportDefinition[] = [
  {
    dataset: "applications",
    title: "Franchise application register",
    description:
      "Every new and renewal application with the declared operator, vehicle, TODA, decision and document counts.",
    icon: FileText,
    columns: ["application_number", "status", "submitted_at", "operator", "plate", "toda"],
  },
  {
    dataset: "records",
    title: "Franchise record registry",
    description:
      "Issued franchises with validity dates, archive status, certificate status and the renewal linkage.",
    icon: Stamp,
    columns: ["franchise_number", "operator", "issued", "expires", "archived"],
  },
  {
    dataset: "expiring",
    title: "Renewal watchlist",
    description:
      "Franchises expiring within 180 days, grouped by remaining validity, for the counter's follow-up calls.",
    icon: FileDown,
    columns: ["franchise_number", "operator", "expires", "days_remaining", "bucket"],
  },
  {
    dataset: "compliance",
    title: "Documentary compliance",
    description: "Verification rate per requirement and the age of the oldest pending document.",
    icon: FileDown,
    columns: ["document_type", "total", "verified", "pending", "verified_rate"],
  },
  {
    dataset: "processing",
    title: "Processing performance",
    description: "Monthly average, median and 90th-percentile processing time against the five-day target.",
    icon: BarChart3,
    columns: ["month", "decided", "average_days", "median_days"],
  },
  {
    dataset: "trends",
    title: "Monthly application trends",
    description: "Submissions split into new and renewal, with approvals and rejections per month.",
    icon: BarChart3,
    columns: ["month", "submitted", "new", "renewals", "approved", "rejected"],
  },
  {
    dataset: "toda",
    title: "TODA summary",
    description: "Applications, active franchises and masterlist size per association.",
    icon: Users,
    columns: ["toda", "members", "applications", "approved", "active_franchises"],
  },
  {
    dataset: "activity",
    title: "Audit trail",
    description: "Append-only log of sign-ins, submissions, verifications, decisions and administrative changes.",
    icon: History,
    columns: ["timestamp", "actor", "action", "target"],
  },
  {
    dataset: "users",
    title: "User directory",
    description: "All accounts with role and status. Administrator only.",
    icon: Users,
    adminOnly: true,
    columns: ["full_name", "email", "role", "account_status"],
  },
];

export async function ReportsPage({ session }: { session: SessionContext }) {
  const [overview, applications, records, compliance, expiring, processing] = await Promise.all([
    getAnalyticsOverview(),
    listApplications({ page: 1, pageSize: 1 }),
    listFranchiseRecords({ page: 1, pageSize: 1 }),
    getDocumentCompliance(),
    getExpiringFranchises(180),
    getProcessingTime(12),
  ]);

  const available = REPORTS.filter((report) => !report.adminOnly || session.role === "administrator");
  const latestProcessing = processing.at(-1) ?? null;
  const complianceRate =
    compliance.length === 0
      ? null
      : (compliance.reduce((sum, row) => sum + row.verified, 0) /
          Math.max(
            compliance.reduce((sum, row) => sum + row.total, 0),
            1,
          )) *
        100;

  return (
    <div>
      <SectionTitle
        title="Reports and exports"
        description="Exports are generated on the server with your own session, so they contain exactly the rows your role may read — nothing more."
      />

      <div className="grid gap-4 xl:grid-cols-3">
        <Card className="xl:col-span-2">
          <CardHeader title="Registry at a glance" icon={BarChart3} />
          <dl className="grid gap-3 text-[0.8125rem] sm:grid-cols-2">
            <Row label="Applications on file" value={formatNumber(applications.count)} />
            <Row label="Franchise records issued" value={formatNumber(records.count)} />
            <Row
              label="Decided (approval rate)"
              value={
                <span>
                  {formatNumber(
                    (overview?.approved_applications ?? 0) + (overview?.rejected_applications ?? 0),
                  )}{" "}
                  ({formatPercent(overview?.approval_rate ?? null)})
                </span>
              }
            />
            <Row label="Average processing time" value={formatDays(overview?.avg_processing_days ?? null)} />
            <Row
              label="Document verification rate"
              value={formatPercent(complianceRate)}
            />
            <Row
              label="Franchises expiring within 90 days"
              value={formatNumber(overview?.expiring_90 ?? null)}
            />
            <Row label="Expired franchises" value={formatNumber(overview?.expired_franchises ?? null)} />
            <Row label="Renewal watchlist entries" value={formatNumber(expiring.length)} />
            <Row
              label="Latest month's volume"
              value={latestProcessing ? `${latestProcessing.month_label} · ${formatNumber(latestProcessing.decided)} decided` : "—"}
            />
            <Row
              label="Data as of"
              value={formatDate(new Date().toISOString())}
            />
          </dl>
        </Card>

        <Card>
          <CardHeader title="How to use the exports" />
          <ul className="space-y-2.5 text-[0.8125rem] text-muted">
            <li>
              Every file opens in a spreadsheet: the first row is the header and text is quoted
              correctly, so operator names with commas or &quot;ñ&quot; are preserved.
            </li>
            <li>
              Exports contain personal data already held in the municipal record. Handle the files under
              the office&apos;s data-privacy rules and delete copies that are no longer needed.
            </li>
            <li>
              The audit trail export is not editable by any role: entries can only be appended by the
              system.
            </li>
          </ul>
        </Card>
      </div>

      <h2 className="mt-6 mb-3 text-[1.0625rem] font-semibold text-ink">Available exports</h2>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {available.map((report) => {
          const Icon = report.icon;
          const params = new URLSearchParams({ dataset: report.dataset });
          return (
            <Card key={report.dataset}>
              <CardHeader title={report.title} description={report.description} icon={Icon} />
              <ul className="mb-4 flex flex-wrap gap-1.5">
                {report.columns.map((column) => (
                  <li key={column}>
                    <Badge tone="neutral">{column}</Badge>
                  </li>
                ))}
              </ul>
              <a
                className="inline-flex items-center gap-2 rounded-lg bg-primary px-3.5 py-2 text-[0.8125rem] font-medium text-white hover:bg-primary-600"
                href={`/api/reports/export?${params.toString()}`}
              >
                <FileDown className="h-4 w-4" />
                Download CSV
              </a>
            </Card>
          );
        })}
      </div>

      <Card className="mt-4">
        <CardHeader
          title="Not included on purpose"
          description="The system deliberately does not produce these: they are outside the scope of the franchising office."
        />
        <p className="text-[0.8125rem] text-muted">
          Revenue or collection reports, vehicle inspection results, trip or GPS records, and any
          predictive model output. The analytics available here are descriptive and prescriptive
          only, and the AI briefings are advisory.
        </p>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex justify-between gap-3 border-b border-line pb-2">
      <dt className="text-muted">{label}</dt>
      <dd className="text-right font-medium text-ink">{value}</dd>
    </div>
  );
}
