import type { ReactNode } from "react";

/**
 * Shared skeleton primitives for the administrator and staff consoles.
 *
 * The route-level `loading.tsx` files render these while the server streams the
 * next panel, so navigation gives immediate feedback without flashing an empty
 * page. Shapes follow the real cards, tables and forms closely enough that the
 * swap to live content does not shift the layout.
 */

function Skeleton({ className = "" }: { className?: string }) {
  return <div aria-hidden="true" className={`animate-pulse rounded-md bg-line ${className}`} />;
}

function SkeletonText({ lines = 2, className = "" }: { lines?: number; className?: string }) {
  return (
    <div aria-hidden="true" className={`space-y-2 ${className}`}>
      {Array.from({ length: lines }).map((_, index) => (
        <div
          key={index}
          className={`h-3 animate-pulse rounded bg-line ${
            index === lines - 1 && lines > 1 ? "w-2/3" : "w-full"
          }`}
        />
      ))}
    </div>
  );
}

function SkeletonCard({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <div className={`sbtf-card p-5 ${className}`}>{children}</div>;
}

function CardHeaderSkeleton() {
  return (
    <div className="mb-4 flex items-start gap-3">
      <Skeleton className="h-9 w-9 rounded-md" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-4 w-40 max-w-full" />
        <Skeleton className="h-3 w-64 max-w-full" />
      </div>
    </div>
  );
}

function PageHeaderSkeleton({ action = true }: { action?: boolean }) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-3">
      <div className="w-full max-w-xl space-y-2">
        <Skeleton className="h-7 w-64 max-w-full" />
        <Skeleton className="h-3.5 w-full" />
      </div>
      {action ? <Skeleton className="h-9 w-28 rounded-lg" /> : null}
    </div>
  );
}

function StatCardsSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
      {Array.from({ length: count }).map((_, index) => (
        <div key={index} className="sbtf-card p-4">
          <div className="flex items-start justify-between gap-3">
            <Skeleton className="h-3 w-24" />
            <Skeleton className="h-7 w-7 rounded-md" />
          </div>
          <Skeleton className="mt-3 h-7 w-20" />
          <Skeleton className="mt-2 h-3 w-32 max-w-full" />
        </div>
      ))}
    </div>
  );
}

function FiltersSkeleton() {
  return (
    <div className="mb-4 flex flex-wrap gap-2">
      <Skeleton className="h-9 w-full max-w-sm rounded-lg" />
      <Skeleton className="h-9 w-32 rounded-lg" />
      <Skeleton className="h-9 w-32 rounded-lg" />
      <Skeleton className="h-9 w-24 rounded-lg" />
    </div>
  );
}

function TableRowsSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="divide-y divide-line">
      {Array.from({ length: rows }).map((_, index) => (
        <div key={index} className="flex items-center gap-4 px-4 py-3">
          <Skeleton className="h-3 w-24 shrink-0" />
          <Skeleton className="h-3 flex-1" />
          <Skeleton className="hidden h-3 w-24 sm:block" />
          <Skeleton className="h-5 w-16 shrink-0 rounded-full" />
        </div>
      ))}
    </div>
  );
}

function TableCardSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div className="sbtf-card overflow-hidden">
      <div className="flex items-center gap-4 border-b border-line bg-[#fbfbfc] px-4 py-3">
        <Skeleton className="h-3 w-24" />
        <Skeleton className="h-3 flex-1" />
        <Skeleton className="hidden h-3 w-24 sm:block" />
        <Skeleton className="h-3 w-16" />
      </div>
      <TableRowsSkeleton rows={rows} />
      <div className="flex items-center justify-between border-t border-line px-4 py-3">
        <Skeleton className="h-3 w-32" />
        <Skeleton className="h-7 w-40 rounded-md" />
      </div>
    </div>
  );
}

export function DashboardSkeleton() {
  return (
    <div className="space-y-5" role="status" aria-label="Loading dashboard">
      <PageHeaderSkeleton />
      <StatCardsSkeleton />
      <div className="grid gap-4 xl:grid-cols-3">
        <SkeletonCard className="xl:col-span-2">
          <CardHeaderSkeleton />
          <Skeleton className="h-56 w-full" />
        </SkeletonCard>
        <SkeletonCard>
          <CardHeaderSkeleton />
          <Skeleton className="h-56 w-full" />
        </SkeletonCard>
      </div>
      <SkeletonCard>
        <CardHeaderSkeleton />
        <TableRowsSkeleton />
      </SkeletonCard>
      <span className="sr-only">Loading…</span>
    </div>
  );
}

export function AnalyticsSkeleton() {
  return (
    <div className="space-y-5" role="status" aria-label="Loading analytics">
      <PageHeaderSkeleton action={false} />
      <StatCardsSkeleton />
      <div className="grid gap-4 xl:grid-cols-2">
        <SkeletonCard>
          <CardHeaderSkeleton />
          <Skeleton className="h-56 w-full" />
        </SkeletonCard>
        <SkeletonCard>
          <CardHeaderSkeleton />
          <Skeleton className="h-56 w-full" />
        </SkeletonCard>
      </div>
      <SkeletonCard>
        <CardHeaderSkeleton />
        <div className="space-y-3">
          <Skeleton className="h-16 w-full rounded-lg" />
          <Skeleton className="h-16 w-full rounded-lg" />
        </div>
      </SkeletonCard>
      <span className="sr-only">Loading…</span>
    </div>
  );
}

export function TablePageSkeleton({ rows = 7 }: { rows?: number }) {
  return (
    <div role="status" aria-label="Loading page">
      <PageHeaderSkeleton />
      <FiltersSkeleton />
      <TableCardSkeleton rows={rows} />
      <span className="sr-only">Loading…</span>
    </div>
  );
}

export function DetailPageSkeleton() {
  return (
    <div className="space-y-5" role="status" aria-label="Loading details">
      <PageHeaderSkeleton />
      <div className="grid gap-4 xl:grid-cols-3">
        <div className="space-y-4 xl:col-span-2">
          <SkeletonCard>
            <CardHeaderSkeleton />
            <div className="grid gap-x-6 gap-y-4 sm:grid-cols-2">
              {Array.from({ length: 8 }).map((_, index) => (
                <div key={index} className="space-y-1.5">
                  <Skeleton className="h-3 w-20" />
                  <Skeleton className="h-3.5 w-3/4" />
                </div>
              ))}
            </div>
          </SkeletonCard>
          <SkeletonCard>
            <CardHeaderSkeleton />
            <TableRowsSkeleton rows={4} />
          </SkeletonCard>
        </div>
        <div className="space-y-4">
          <SkeletonCard>
            <CardHeaderSkeleton />
            <SkeletonText lines={5} />
          </SkeletonCard>
          <SkeletonCard>
            <CardHeaderSkeleton />
            <SkeletonText lines={4} />
          </SkeletonCard>
        </div>
      </div>
      <span className="sr-only">Loading…</span>
    </div>
  );
}

export function FormPageSkeleton() {
  return (
    <div role="status" aria-label="Loading form">
      <PageHeaderSkeleton action={false} />
      <SkeletonCard>
        <CardHeaderSkeleton />
        <div className="grid gap-4 sm:grid-cols-2">
          {Array.from({ length: 8 }).map((_, index) => (
            <div key={index} className="space-y-2">
              <Skeleton className="h-3 w-24" />
              <Skeleton className="h-9 w-full rounded-lg" />
            </div>
          ))}
        </div>
        <div className="mt-5 flex justify-end gap-2 border-t border-line pt-4">
          <Skeleton className="h-9 w-24 rounded-lg" />
          <Skeleton className="h-9 w-28 rounded-lg" />
        </div>
      </SkeletonCard>
      <SkeletonCard className="mt-4">
        <CardHeaderSkeleton />
        <SkeletonText lines={4} />
      </SkeletonCard>
      <span className="sr-only">Loading…</span>
    </div>
  );
}

export function ListPageSkeleton() {
  return (
    <div role="status" aria-label="Loading list">
      <PageHeaderSkeleton action={false} />
      <SkeletonCard>
        <CardHeaderSkeleton />
        <div className="divide-y divide-line">
          {Array.from({ length: 6 }).map((_, index) => (
            <div key={index} className="flex items-start gap-3 py-3">
              <Skeleton className="mt-1.5 h-2 w-2 shrink-0 rounded-full" />
              <div className="flex-1 space-y-2">
                <Skeleton className="h-3.5 w-48 max-w-full" />
                <Skeleton className="h-3 w-full" />
                <Skeleton className="h-3 w-24" />
              </div>
              <Skeleton className="h-5 w-16 shrink-0 rounded-full" />
            </div>
          ))}
        </div>
      </SkeletonCard>
      <SkeletonCard className="mt-4">
        <CardHeaderSkeleton />
        <SkeletonText lines={4} />
      </SkeletonCard>
      <span className="sr-only">Loading…</span>
    </div>
  );
}

export function ReportsSkeleton() {
  return (
    <div role="status" aria-label="Loading reports">
      <PageHeaderSkeleton action={false} />
      <StatCardsSkeleton />
      <div className="mt-4 grid gap-4 xl:grid-cols-2">
        {Array.from({ length: 4 }).map((_, index) => (
          <SkeletonCard key={index}>
            <CardHeaderSkeleton />
            <SkeletonText lines={3} />
            <div className="mt-4 flex gap-2">
              <Skeleton className="h-8 w-24 rounded-lg" />
              <Skeleton className="h-8 w-24 rounded-lg" />
            </div>
          </SkeletonCard>
        ))}
      </div>
      <span className="sr-only">Loading…</span>
    </div>
  );
}

export function AiSupportSkeleton() {
  return (
    <div role="status" aria-label="Loading AI decision support">
      <PageHeaderSkeleton action={false} />
      <div className="grid gap-4 xl:grid-cols-3">
        <SkeletonCard className="xl:col-span-2">
          <CardHeaderSkeleton />
          <Skeleton className="h-40 w-full" />
          <SkeletonText className="mt-4" lines={4} />
        </SkeletonCard>
        <SkeletonCard>
          <CardHeaderSkeleton />
          <SkeletonText lines={6} />
        </SkeletonCard>
      </div>
      <span className="sr-only">Loading…</span>
    </div>
  );
}
