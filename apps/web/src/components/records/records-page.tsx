import { Suspense } from "react";

import { FilterBar } from "@/components/filters";
import { RecordTable } from "@/components/records/record-table";
import { EmptyState, SectionTitle, Spinner } from "@/components/ui";
import { listFranchiseRecords, listTodas } from "@/lib/data";
import type { SearchParamsRecord } from "@/components/applications/applications-page";

function single(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value ?? undefined;
}

const STATE_OPTIONS = [
  { value: "all", label: "All records" },
  { value: "active", label: "Active only" },
  { value: "expiring", label: "Expiring within 90 days" },
  { value: "expired", label: "Expired" },
  { value: "archived", label: "Archived" },
];

export async function RecordsPage({
  basePath,
  searchParams,
}: {
  basePath: "/admin" | "/staff";
  searchParams: SearchParamsRecord;
}) {
  const page = Number(single(searchParams.page) ?? "1") || 1;
  const search = single(searchParams.q);
  const state = (single(searchParams.state) as "active" | "expiring" | "expired" | "archived" | "all") ?? "all";
  const todaId = single(searchParams.toda);
  const from = single(searchParams.from);
  const to = single(searchParams.to);

  const [result, todas] = await Promise.all([
    listFranchiseRecords({ search, state, todaId, from, to, page }),
    listTodas(),
  ]);

  function pageHref(nextPage: number) {
    const params = new URLSearchParams();
    if (search) params.set("q", search);
    if (state !== "all") params.set("state", state);
    if (todaId) params.set("toda", todaId);
    if (from) params.set("from", from);
    if (to) params.set("to", to);
    params.set("page", String(nextPage));
    return `${basePath}/franchises?${params.toString()}`;
  }

  return (
    <div>
      <SectionTitle
        title="Franchise records"
        description="Issued franchises with their validity period, certificate status and renewal linkage. Records are never edited once issued."
      />

      <Suspense fallback={<Spinner label="Loading filters…" />}>
        <FilterBar
          todos={todas}
          showToda
          showDateRange
          definitions={[{ name: "state", label: "Record state", type: "select", options: STATE_OPTIONS }]}
        />
      </Suspense>

      {result.count === 0 && !search ? (
        <EmptyState
          title="No franchise records yet"
          description="A record is created automatically when an application is approved, with the franchise number and the validity dates."
        />
      ) : (
        <RecordTable
          result={result}
          basePath={basePath}
          pageHref={pageHref}
          emptyTitle="No franchise records match the current filters"
        />
      )}
    </div>
  );
}
