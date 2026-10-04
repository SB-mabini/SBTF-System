"use client";

import { useRouter, useSearchParams, usePathname } from "next/navigation";
import { useCallback, useMemo, useState, useTransition } from "react";
import { Filter, X } from "lucide-react";

import { Button } from "@/components/ui";
import { APPLICATION_STATUS_LABELS, APPLICATION_TYPE_LABELS } from "@/lib/constants";
import type { Toda } from "@/types/database";

export interface FilterDefinition {
  name: string;
  label: string;
  type: "text" | "select" | "date";
  options?: Array<{ value: string; label: string }>;
  placeholder?: string;
}

/**
 * URL-driven filter bar: every change is reflected in the query string so that
 * filtered views are shareable and survive refresh.
 */
export function FilterBar({
  definitions,
  searchKey = "q",
  todos,
  showToda = false,
  showDateRange = false,
}: {
  definitions?: FilterDefinition[];
  searchKey?: string;
  todos?: Toda[];
  showToda?: boolean;
  showDateRange?: boolean;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [pending, startTransition] = useTransition();

  const [search, setSearch] = useState(searchParams.get(searchKey) ?? "");

  const activeCount = useMemo(
    () =>
      Array.from(searchParams.keys()).filter(
        (key) => !["page", "pageSize"].includes(key) && searchParams.get(key),
      ).length,
    [searchParams],
  );

  const update = useCallback(
    (changes: Record<string, string | null>) => {
      const params = new URLSearchParams(searchParams.toString());
      Object.entries(changes).forEach(([key, value]) => {
        if (!value || value === "all") params.delete(key);
        else params.set(key, value);
      });
      params.delete("page");
      startTransition(() => {
        router.push(`${pathname}?${params.toString()}`);
      });
    },
    [pathname, router, searchParams],
  );

  const statusOptions = [
    { value: "all", label: "All statuses" },
    ...Object.entries(APPLICATION_STATUS_LABELS).map(([value, label]) => ({ value, label })),
  ];

  const typeOptions = [
    { value: "all", label: "All types" },
    ...Object.entries(APPLICATION_TYPE_LABELS).map(([value, label]) => ({ value, label })),
  ];

  return (
    <div className="sbtf-card mb-4 p-4">
      <div className="flex flex-wrap items-end gap-3">
        <form
          className="min-w-[220px] flex-1"
          onSubmit={(event) => {
            event.preventDefault();
            update({ [searchKey]: search });
          }}
        >
          <label className="sbtf-label" htmlFor="filter-search">
            Search
          </label>
          <div className="flex gap-2">
            <input
              id="filter-search"
              className="sbtf-input"
              placeholder="Application number, plate number, operator…"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />
            <Button type="submit" variant="outline" loading={pending}>
              Search
            </Button>
          </div>
        </form>

        {definitions?.map((definition) => {
          if (definition.type === "text") return null;
          const value = searchParams.get(definition.name) ?? "all";
          return (
            <div key={definition.name} className="min-w-[160px]">
              <label className="sbtf-label" htmlFor={`filter-${definition.name}`}>
                {definition.label}
              </label>
              {definition.type === "date" ? (
                <input
                  id={`filter-${definition.name}`}
                  type="date"
                  className="sbtf-input"
                  value={searchParams.get(definition.name) ?? ""}
                  onChange={(event) => update({ [definition.name]: event.target.value })}
                />
              ) : (
                <select
                  id={`filter-${definition.name}`}
                  className="sbtf-input"
                  value={value}
                  onChange={(event) => update({ [definition.name]: event.target.value })}
                >
                  {definition.options?.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              )}
            </div>
          );
        })}

        {showToda && todos ? (
          <div className="min-w-[200px]">
            <label className="sbtf-label" htmlFor="filter-toda">
              TODA
            </label>
            <select
              id="filter-toda"
              className="sbtf-input"
              value={searchParams.get("toda") ?? "all"}
              onChange={(event) => update({ toda: event.target.value })}
            >
              <option value="all">All TODAs</option>
              {todos.map((toda) => (
                <option key={toda.id} value={toda.id}>
                  {toda.name}
                </option>
              ))}
            </select>
          </div>
        ) : null}

        {showDateRange ? (
          <>
            <div>
              <label className="sbtf-label" htmlFor="filter-from">
                From
              </label>
              <input
                id="filter-from"
                type="date"
                className="sbtf-input"
                value={searchParams.get("from") ?? ""}
                onChange={(event) => update({ from: event.target.value })}
              />
            </div>
            <div>
              <label className="sbtf-label" htmlFor="filter-to">
                To
              </label>
              <input
                id="filter-to"
                type="date"
                className="sbtf-input"
                value={searchParams.get("to") ?? ""}
                onChange={(event) => update({ to: event.target.value })}
              />
            </div>
          </>
        ) : null}

        <div className="flex items-center gap-2">
          <span className="inline-flex items-center gap-1.5 text-[0.75rem] text-muted">
            <Filter className="h-3.5 w-3.5" />
            {activeCount} filter{activeCount === 1 ? "" : "s"}
          </span>
          {activeCount > 0 ? (
            <Button variant="ghost" onClick={() => update(Object.fromEntries(Array.from(searchParams.keys()).map((key) => [key, null])))}>
              <X className="h-3.5 w-3.5" />
              Clear
            </Button>
          ) : null}
        </div>
      </div>

      {/* Status and type shortcuts keep the common cases one click away. */}
      <div className="mt-3 flex flex-wrap items-center gap-2 border-t border-line pt-3">
        <span className="text-[0.75rem] text-muted">Quick filters:</span>
        {statusOptions.slice(1).map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => update({ status: option.value })}
            className={`rounded-full border px-2.5 py-0.5 text-[0.75rem] ${
              searchParams.get("status") === option.value
                ? "border-primary-200 bg-primary-50 text-primary-700"
                : "border-line text-muted hover:bg-page"
            }`}
          >
            {option.label}
          </button>
        ))}
        {typeOptions.slice(1).map((option) => (
          <button
            key={option.value}
            type="button"
            onClick={() => update({ type: option.value })}
            className={`rounded-full border px-2.5 py-0.5 text-[0.75rem] ${
              searchParams.get("type") === option.value
                ? "border-primary-200 bg-primary-50 text-primary-700"
                : "border-line text-muted hover:bg-page"
            }`}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}
