import Link from "next/link";

import { Badge, EmptyState, Pagination, StatusBadge } from "@/components/ui";
import { FileText } from "lucide-react";
import { applicationTypeLabel, formatDate, relativeTime } from "@/lib/format";
import type { FranchiseApplicationDetail } from "@/types/database";
import type { ListResultLike } from "@/types/ui";

export function ApplicationTable({
  result,
  basePath,
  pageHref,
  emptyTitle = "No applications match the filters",
}: {
  result: ListResultLike<FranchiseApplicationDetail>;
  basePath: "/admin" | "/staff";
  pageHref: (page: number) => string;
  emptyTitle?: string;
}) {
  if (result.rows.length === 0) {
    return (
      <div className="sbtf-card p-4">
        <EmptyState
          title={emptyTitle}
          description="Adjust the filters, or clear them to see the full register."
          icon={FileText}
        />
      </div>
    );
  }

  return (
    <div className="sbtf-card overflow-hidden">
      <div className="overflow-x-auto">
        <table className="sbtf-table">
          <thead>
            <tr>
              <th>Application</th>
              <th>Operator</th>
              <th>Plate</th>
              <th>TODA</th>
              <th>Type</th>
              <th>Submitted</th>
              <th>Documents</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {result.rows.map((application) => {
              const verified = (application.documents ?? []).filter(
                (document) => document.verification_status === "verified",
              ).length;
              const rejected = (application.documents ?? []).filter(
                (document) => document.verification_status === "rejected",
              ).length;

              return (
                <tr key={application.id}>
                  <td>
                    <Link
                      className="font-mono text-[0.8125rem] font-medium text-primary hover:underline"
                      href={`${basePath}/applications/${application.id}`}
                    >
                      {application.application_number}
                    </Link>
                  </td>
                  <td>
                    <span className="block text-[0.8125rem] text-ink">
                      {application.operator_last_name}, {application.operator_first_name}
                    </span>
                    <span className="block text-[0.75rem] text-muted">
                      {application.operator_contact_number}
                    </span>
                  </td>
                  <td className="font-mono text-[0.8125rem]">{application.plate_number}</td>
                  <td className="text-[0.8125rem] text-muted">{application.toda?.name ?? "—"}</td>
                  <td>
                    <Badge tone={application.application_type === "renewal" ? "info" : "neutral"}>
                      {applicationTypeLabel(application.application_type)}
                    </Badge>
                  </td>
                  <td>
                    <span className="block text-[0.8125rem] text-ink">
                      {formatDate(application.submitted_at)}
                    </span>
                    <span className="block text-[0.75rem] text-muted">
                      {relativeTime(application.submitted_at)}
                    </span>
                  </td>
                  <td>
                    {rejected > 0 ? (
                      <Badge tone="danger">{rejected} rejected</Badge>
                    ) : verified === 4 ? (
                      <Badge tone="success">4 of 4 verified</Badge>
                    ) : (
                      <Badge tone="pending">{verified} of 4 verified</Badge>
                    )}
                  </td>
                  <td>
                    <StatusBadge status={application.status} />
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <Pagination
        page={result.page}
        pageSize={result.pageSize}
        count={result.count}
        onPageHref={pageHref}
      />
    </div>
  );
}
