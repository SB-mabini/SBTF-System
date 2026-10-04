import { Suspense } from "react";

import { ActivityTable } from "@/components/activity/activity-table";
import { FilterBar } from "@/components/filters";
import { Card, CardHeader, EmptyState, SectionTitle, Spinner } from "@/components/ui";
import { listActivityLogs, listRecentActivity } from "@/lib/data";
import { actionLabel, formatDateTime } from "@/lib/format";
import { ACTIVITY_ACTIONS } from "@/lib/activity-actions";
import { requireAdministrator } from "@/lib/auth-guard";
import type { ActivityAction } from "@/types/database";

export const metadata = { title: "Activity logs — SBTF Administrator" };

function single(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value ?? undefined;
}

export default async function AdminActivityLogsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireAdministrator();
  const params = await searchParams;

  const page = Number(single(params.page) ?? "1") || 1;
  const search = single(params.q);
  const action = (single(params.action) as ActivityAction | undefined) ?? "all";
  const from = single(params.from);
  const to = single(params.to);

  const [result, recent] = await Promise.all([
    listActivityLogs({ search, action, from, to, page }),
    listRecentActivity(5),
  ]);

  function pageHref(nextPage: number) {
    const next = new URLSearchParams();
    if (search) next.set("q", search);
    if (action !== "all") next.set("action", action);
    if (from) next.set("from", from);
    if (to) next.set("to", to);
    next.set("page", String(nextPage));
    return `/admin/activity-logs?${next.toString()}`;
  }

  return (
    <div>
      <SectionTitle
        title="Activity logs"
        description="An append-only audit trail: no role can edit or delete an entry, and the service-role key is never used by the web application."
        action={
          <a
            className="inline-flex items-center rounded-lg bg-primary px-3.5 py-2 text-[0.8125rem] font-medium text-white hover:bg-primary-600"
            href={`/api/reports/export?dataset=activity${action !== "all" ? `&action=${action}` : ""}${
              from ? `&from=${from}` : ""
            }${to ? `&to=${to}` : ""}`}
          >
            Export CSV
          </a>
        }
      />

      <Suspense fallback={<Spinner label="Loading filters…" />}>
        <FilterBar
          showDateRange
          definitions={[
            {
              name: "action",
              label: "Action",
              type: "select",
              options: [
                { value: "all", label: "All actions" },
                ...ACTIVITY_ACTIONS.map((value) => ({ value, label: actionLabel(value) })),
              ],
            },
          ]}
        />
      </Suspense>

      <ActivityTable result={result} pageHref={pageHref} />

      <Card className="mt-4">
        <CardHeader
          title="What is recorded"
          description="The audit trail is designed for accountability, not surveillance of citizens: it records who did what inside the system and when."
        />
        <ul className="space-y-2 text-[0.8125rem] text-muted">
          <li>Sign-ins, submissions and renewals, document uploads and replacements, verifications, decisions, certificates and archives.</li>
          <li>Administrative changes: role assignment, account activation and suspension, and settings updates.</li>
          <li>AI advisories, including the model used, latency, token counts and hashes of the aggregated payload.</li>
        </ul>
        {recent.length > 0 ? (
          <p className="mt-3 rounded-md bg-page px-3 py-2 text-[0.75rem] text-muted">
            Latest entry: {actionLabel(recent[0]!.action)} at {formatDateTime(recent[0]!.timestamp)}.
          </p>
        ) : (
          <div className="mt-3">
            <EmptyState title="Nothing recorded yet" />
          </div>
        )}
      </Card>
    </div>
  );
}
