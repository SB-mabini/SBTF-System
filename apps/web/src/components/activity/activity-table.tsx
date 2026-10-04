import { Badge, EmptyState, Pagination } from "@/components/ui";
import { History } from "lucide-react";
import { actionLabel, formatDateTime, humanizeKey, roleLabel } from "@/lib/format";
import type { ActivityLog } from "@/types/database";
import type { ListResultLike } from "@/types/ui";

const ACTION_TONE: Record<string, "neutral" | "info" | "success" | "warning" | "danger" | "approved" | "rejected"> = {
  login: "neutral",
  logout: "neutral",
  application_submitted: "info",
  application_renewal_submitted: "info",
  review_started: "warning",
  document_verification: "info",
  application_approved: "approved",
  application_rejected: "rejected",
  certificate_generation: "approved",
  role_change: "warning",
  user_activated: "success",
  user_deactivated: "danger",
  settings_update: "warning",
  security_event: "danger",
  ai_request: "info",
};

export function ActivityTable({
  result,
  pageHref,
}: {
  result: ListResultLike<ActivityLog>;
  pageHref: (page: number) => string;
}) {
  if (result.rows.length === 0) {
    return (
      <div className="sbtf-card p-4">
        <EmptyState
          title="No audit entries match the filters"
          description="Every sign-in, submission, verification, decision, certificate and administrative change is recorded here."
          icon={History}
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
              <th>When</th>
              <th>Actor</th>
              <th>Action</th>
              <th>Target</th>
              <th>Details</th>
            </tr>
          </thead>
          <tbody>
            {result.rows.map((log) => (
              <tr key={log.id}>
                <td className="whitespace-nowrap text-[0.8125rem] text-muted">
                  {formatDateTime(log.timestamp)}
                </td>
                <td>
                  <span className="block text-[0.8125rem] text-ink">
                    {log.actor?.full_name ?? "System"}
                  </span>
                  <span className="block text-[0.75rem] text-muted">
                    {log.actor ? roleLabel(log.actor.role) : "scheduled job"}
                  </span>
                </td>
                <td>
                  <Badge tone={ACTION_TONE[log.action] ?? "neutral"}>{actionLabel(log.action)}</Badge>
                </td>
                <td className="text-[0.8125rem] text-muted">
                  {log.target_type ? humanizeKey(log.target_type) : "—"}
                  {log.target_id ? (
                    <span className="ml-1 font-mono text-[0.6875rem]">{log.target_id.slice(0, 8)}</span>
                  ) : null}
                </td>
                <td className="max-w-[26rem] text-[0.75rem] text-muted">
                  {summariseMetadata(log.metadata)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <Pagination page={result.page} pageSize={result.pageSize} count={result.count} onPageHref={pageHref} />
    </div>
  );
}

function summariseMetadata(metadata: Record<string, unknown> | null | undefined): string {
  if (!metadata) return "—";
  const entries = Object.entries(metadata).filter(([, value]) => value !== null && value !== undefined);
  if (entries.length === 0) return "—";

  return entries
    .slice(0, 3)
    .map(([key, value]) => {
      const rendered =
        typeof value === "object" ? JSON.stringify(value).slice(0, 60) : String(value).slice(0, 60);
      return `${humanizeKey(key)}: ${rendered}`;
    })
    .join(" · ");
}
