import Link from "next/link";
import { Stamp } from "lucide-react";

import { Badge, EmptyState, Pagination } from "@/components/ui";
import { formatDate } from "@/lib/format";
import type { FranchiseRecordDetail } from "@/types/database";
import type { ListResultLike } from "@/types/ui";

function validityBadge(record: FranchiseRecordDetail) {
  if (record.archived) return <Badge tone="neutral">Archived</Badge>;

  const days = Math.floor(
    (new Date(record.expires_at).getTime() - Date.now()) / (1000 * 60 * 60 * 24),
  );

  if (days < 0) return <Badge tone="danger">Expired</Badge>;
  if (days <= 90) return <Badge tone="warning">Expires in {days} days</Badge>;
  return <Badge tone="success">Active</Badge>;
}

export function RecordTable({
  result,
  basePath,
  pageHref,
  emptyTitle = "No franchise records match the filters",
}: {
  result: ListResultLike<FranchiseRecordDetail>;
  basePath: "/admin" | "/staff";
  pageHref: (page: number) => string;
  emptyTitle?: string;
}) {
  if (result.rows.length === 0) {
    return (
      <div className="sbtf-card p-4">
        <EmptyState
          title={emptyTitle}
          description="Issued franchises appear here as soon as an application is approved."
          icon={Stamp}
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
              <th>Franchise number</th>
              <th>Operator</th>
              <th>Plate</th>
              <th>TODA</th>
              <th>Issued</th>
              <th>Valid until</th>
              <th>Certificate</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {result.rows.map((record) => (
              <tr key={record.id}>
                <td>
                  <Link
                    className="font-mono text-[0.8125rem] font-medium text-primary hover:underline"
                    href={`${basePath}/franchises/${record.id}`}
                  >
                    {record.franchise_number}
                  </Link>
                </td>
                <td className="text-[0.8125rem]">{record.operator?.full_name ?? "—"}</td>
                <td className="font-mono text-[0.8125rem]">
                  {record.application?.plate_number ?? "—"}
                </td>
                <td className="text-[0.8125rem] text-muted">{record.toda?.name ?? "—"}</td>
                <td className="text-[0.8125rem]">{formatDate(record.issued_at)}</td>
                <td className="text-[0.8125rem]">{formatDate(record.expires_at)}</td>
                <td>
                  {record.certificate_storage_path ? (
                    <Badge tone="success">Generated</Badge>
                  ) : (
                    <Badge tone="pending">Not generated</Badge>
                  )}
                </td>
                <td>{validityBadge(record)}</td>
              </tr>
            ))}
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
