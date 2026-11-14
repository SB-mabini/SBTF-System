import { Suspense } from "react";

import { ActivityTable } from "@/components/activity/activity-table";
import { FilterBar } from "@/components/filters";
import { SectionTitle, Spinner } from "@/components/ui";
import { listActivityLogs } from "@/lib/data";
import { actionLabel } from "@/lib/format";
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

  const result = await listActivityLogs({ search, action, from, to, page });

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
    </div>
  );
}
