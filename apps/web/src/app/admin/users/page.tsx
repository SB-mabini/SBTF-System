import { Suspense } from "react";
import Link from "next/link";
import { ShieldCheck, Users } from "lucide-react";

import { UserActions } from "@/components/users/user-actions";
import { UsersToolbar } from "@/components/users/users-toolbar";
import { FilterBar } from "@/components/filters";
import {
  Badge,
  Card,
  CardHeader,
  EmptyState,
  Pagination,
  SectionTitle,
  Spinner,
} from "@/components/ui";
import { getUserCounts, listUsers } from "@/lib/data";
import { formatDateTime, roleLabel } from "@/lib/format";
import { requireAdministrator } from "@/lib/auth-guard";
import type { AccountStatus, UserRole } from "@/types/database";

export const metadata = { title: "Users — SBTF Administrator" };

function single(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) return value[0];
  return value ?? undefined;
}

export default async function AdminUsersPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const session = await requireAdministrator();
  const params = await searchParams;

  const tab = (single(params.tab) as "staff" | "operators" | undefined) ?? "staff";
  const page = Number(single(params.page) ?? "1") || 1;
  const search = single(params.q);
  const role = (single(params.role) as UserRole | undefined) ?? "all";
  const status = (single(params.status) as AccountStatus | undefined) ?? "all";

  const counts = await getUserCounts();

  const isStaffTab = tab === "staff";
  const activeRoles: UserRole[] = isStaffTab ? ["administrator", "staff"] : ["driver"];
  const filterRole = isStaffTab && role !== "all" ? role : undefined;

  const result = await listUsers({
    search,
    role: filterRole,
    roles: activeRoles,
    status,
    page,
  });

  function pageHref(nextPage: number) {
    const next = new URLSearchParams();
    next.set("tab", tab);
    if (search) next.set("q", search);
    if (isStaffTab && role !== "all") next.set("role", role);
    if (status !== "all") next.set("status", status);
    next.set("page", String(nextPage));
    return `/admin/users?${next.toString()}`;
  }

  return (
    <div>
      <SectionTitle
        title="Users and roles"
        description={
          isStaffTab
            ? "Municipal staff and administrator accounts. Administrators have full oversight; staff members manage records and applications."
            : "Registered tricycle drivers and operators from the mobile app and municipal franchise records."
        }
        action={
          isStaffTab ? (
            <UsersToolbar />
          ) : (
            <span className="inline-flex items-center gap-1.5 rounded-full border border-line bg-white px-3 py-1.5 text-xs text-muted shadow-sm">
              Registered via SBTF Mobile App
            </span>
          )
        }
      />

      {/* Navigation tabs separating Municipal Staff & Admins from Tricycle Operators */}
      <div className="mb-5 flex border-b border-line gap-2">
        <Link
          href="/admin/users?tab=staff"
          className={`flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors ${
            isStaffTab
              ? "border-primary text-primary"
              : "border-transparent text-muted hover:border-line hover:text-ink"
          }`}
        >
          <ShieldCheck className="h-4 w-4" />
          Staff & Administrators
          <Badge tone={isStaffTab ? "info" : "neutral"}>{counts.staff}</Badge>
        </Link>
        <Link
          href="/admin/users?tab=operators"
          className={`flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors ${
            !isStaffTab
              ? "border-primary text-primary"
              : "border-transparent text-muted hover:border-line hover:text-ink"
          }`}
        >
          <Users className="h-4 w-4" />
          Tricycle Drivers & Operators
          <Badge tone={!isStaffTab ? "approved" : "neutral"}>{counts.operators}</Badge>
        </Link>
      </div>

      <Suspense fallback={<Spinner label="Loading filters…" />}>
        <FilterBar
          searchPlaceholder={
            isStaffTab
              ? "Search staff or admin by name, email, contact…"
              : "Search operators by name, email, contact, TODA…"
          }
          showQuickFilters={false}
          definitions={
            isStaffTab
              ? [
                  {
                    name: "role",
                    label: "Role",
                    type: "select",
                    options: [
                      { value: "all", label: "All staff & admins" },
                      { value: "administrator", label: "Administrator" },
                      { value: "staff", label: "Staff" },
                    ],
                  },
                  {
                    name: "status",
                    label: "Account status",
                    type: "select",
                    options: [
                      { value: "all", label: "All statuses" },
                      { value: "active", label: "Active" },
                      { value: "inactive", label: "Inactive" },
                      { value: "suspended", label: "Suspended" },
                    ],
                  },
                ]
              : [
                  {
                    name: "status",
                    label: "Account status",
                    type: "select",
                    options: [
                      { value: "all", label: "All statuses" },
                      { value: "active", label: "Active" },
                      { value: "inactive", label: "Inactive" },
                      { value: "suspended", label: "Suspended" },
                    ],
                  },
                ]
          }
        />
      </Suspense>

      {result.rows.length === 0 ? (
        <EmptyState
          title={
            isStaffTab
              ? "No staff or administrator accounts match the filters"
              : "No driver or operator accounts match the filters"
          }
          description={
            isStaffTab
              ? "Municipal staff accounts can be created by clicking “Add staff account” above."
              : "Tricycle drivers and operators register themselves using the SBTF mobile application."
          }
        />
      ) : (
        <div className="space-y-3">
          {result.rows.map((profile) => (
            <Card key={profile.id}>
              <div className="grid gap-4 xl:grid-cols-3">
                <div className="xl:col-span-2">
                  <CardHeader
                    title={profile.full_name}
                    description={`${profile.email} · ${profile.contact_number ?? "no contact number recorded"}`}
                  />
                  <dl className="grid gap-x-6 gap-y-2 text-[0.8125rem] sm:grid-cols-3">
                    {isStaffTab ? (
                      <>
                        <Detail label="Assigned Role" value={roleLabel(profile.role)} />
                        <Detail label="Contact" value={profile.contact_number ?? "—"} />
                        <Detail label="Office/Unit" value="Municipality of Mabini" />
                      </>
                    ) : (
                      <>
                        <Detail label="Address" value={profile.address_line ?? "—"} />
                        <Detail label="Barangay code" value={profile.barangay_code ?? "—"} />
                        <Detail label="TODA" value={profile.toda_id ? profile.toda_id.slice(0, 8) : "—"} />
                      </>
                    )}
                    <Detail label="Registered" value={formatDateTime(profile.created_at)} />
                    <Detail
                      label="Last sign-in"
                      value={profile.last_login_at ? formatDateTime(profile.last_login_at) : "Never"}
                    />
                    <Detail
                      label="Status"
                      value={profile.status_reason ?? "—"}
                    />
                  </dl>
                </div>

                <div>
                  <UserActions profile={profile} currentProfileId={session.profile.id} />
                </div>
              </div>

              {profile.status_reason ? (
                <p className="mt-3 rounded-md bg-page px-3 py-2 text-[0.75rem] text-muted">
                  Status note: {profile.status_reason}
                </p>
              ) : null}
            </Card>
          ))}

          <div className="sbtf-card">
            <Pagination
              page={result.page}
              pageSize={result.pageSize}
              count={result.count}
              onPageHref={pageHref}
            />
          </div>
        </div>
      )}

      <Card className="mt-4">
        <CardHeader
          title="Role model"
          description="Three roles only. The mobile application registers drivers; administrators manage staff accounts from this screen."
        />
        <div className="flex flex-wrap gap-2">
          <Badge tone="approved">Administrator — full oversight, analytics, user management</Badge>
          <Badge tone="info">Staff — processing, verification, decisions, records</Badge>
          <Badge tone="neutral">Driver / Operator — mobile registration, status, certificate</Badge>
        </div>
        <p className="mt-3 text-[0.8125rem] text-muted">
          An administrator can never read another user&apos;s password: authentication is handled by
          Supabase Auth and no password material is stored in the application database.
        </p>
      </Card>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-[0.6875rem] uppercase tracking-wide text-muted">{label}</dt>
      <dd className="truncate text-ink">{value}</dd>
    </div>
  );
}
