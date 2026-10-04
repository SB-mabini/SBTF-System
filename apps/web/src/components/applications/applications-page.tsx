import { Suspense } from "react";

import { ApplicationTable } from "@/components/applications/application-table";
import { FilterBar } from "@/components/filters";
import { EmptyState, SectionTitle, Spinner } from "@/components/ui";
import { listApplications, listTodas } from "@/lib/data";
import { isDemoMode } from "@/lib/env";
import type { ApplicationStatus, ApplicationType } from "@/types/database";

export type SearchParamsRecord = Record<string, string | string[] | undefined>;

function single(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value ?? undefined;
}

/**
 * Shared register of franchise applications, used by both consoles. The
 * administrator sees exactly what the staff sees; the difference between the two
 * roles in the database concerns user management, not the register.
 */
export async function ApplicationsPage({
  basePath,
  searchParams,
}: {
  basePath: "/admin" | "/staff";
  searchParams: SearchParamsRecord;
}) {
  const page = Number(single(searchParams.page) ?? "1") || 1;
  const search = single(searchParams.q);
  const status = (single(searchParams.status) as ApplicationStatus | undefined) ?? "all";
  const type = (single(searchParams.type) as ApplicationType | undefined) ?? "all";
  const todaId = single(searchParams.toda);
  const from = single(searchParams.from);
  const to = single(searchParams.to);

  const [result, todas] = await Promise.all([
    listApplications({ search, status, type, todaId, from, to, page }),
    listTodas(),
  ]);

  function pageHref(nextPage: number) {
    const params = new URLSearchParams();
    if (search) params.set("q", search);
    if (status !== "all") params.set("status", status);
    if (type !== "all") params.set("type", type);
    if (todaId) params.set("toda", todaId);
    if (from) params.set("from", from);
    if (to) params.set("to", to);
    params.set("page", String(nextPage));
    return `${basePath}/applications?${params.toString()}`;
  }

  return (
    <div>
      <SectionTitle
        title="Franchise applications"
        description={
          isDemoMode()
            ? "Preview mode: filters and pagination work over the bundled sample register."
            : "Every new and renewal application, newest first. Records are filtered by your role in PostgreSQL."
        }
      />

      <Suspense fallback={<Spinner label="Loading filters…" />}>
        <FilterBar
          todos={todas}
          showToda
          showDateRange
          definitions={[
            {
              name: "status",
              label: "Status",
              type: "select",
              options: [
                { value: "all", label: "All statuses" },
                { value: "pending", label: "Pending" },
                { value: "approved", label: "Approved" },
                { value: "rejected", label: "Rejected" },
              ],
            },
            {
              name: "type",
              label: "Application type",
              type: "select",
              options: [
                { value: "all", label: "All types" },
                { value: "new", label: "New franchise" },
                { value: "renewal", label: "Renewal" },
              ],
            },
          ]}
        />
      </Suspense>

      {result.rows.length === 0 && result.count === 0 && !search && status === "all" && type === "all" ? (
        <EmptyState
          title="No applications have been submitted yet"
          description="Drivers and operators submit applications from the SBTF mobile app. They appear here immediately."
        />
      ) : (
        <ApplicationTable
          result={result}
          basePath={basePath}
          pageHref={pageHref}
          emptyTitle="No applications match the current filters"
        />
      )}
    </div>
  );
}
