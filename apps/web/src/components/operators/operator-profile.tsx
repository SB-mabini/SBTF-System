import type { ReactNode } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import {
  BadgeCheck,
  FileText,
  Receipt,
  ShieldCheck,
  Stamp,
  UserRound,
  Users,
} from "lucide-react";

import { OperatorDetailsForm } from "@/components/operators/operator-details-form";
import { UserActions } from "@/components/users/user-actions";
import { Alert, Badge, Card, CardHeader, LinkButton, SectionTitle } from "@/components/ui";
import {
  accountStatusLabel,
  applicationStatusLabel,
  applicationTypeLabel,
  formatDate,
  formatDateTime,
  roleLabel,
} from "@/lib/format";
import { isDemoMode } from "@/lib/env";
import type { AccountStatus, ApplicationStatus, Barangay } from "@/types/database";
import type { OperatorProfileBundle } from "@/lib/data";

const STATUS_TONE: Record<AccountStatus, "success" | "pending" | "neutral" | "rejected"> = {
  active: "success",
  pending: "pending",
  inactive: "neutral",
  suspended: "rejected",
};

const APPLICATION_TONE: Record<ApplicationStatus, "success" | "pending" | "rejected"> = {
  approved: "success",
  pending: "pending",
  rejected: "rejected",
};

const PESO = new Intl.NumberFormat("en-PH", {
  style: "currency",
  currency: "PHP",
  minimumFractionDigits: 2,
});

/**
 * The tricycle operator profile module.
 *
 * One screen shows the four things an operator is judged by: who they are, the
 * TODA they belong to, every application they filed and every franchise fee
 * recorded against them. Administrators may correct the descriptive contact
 * details; staff see the same page read-only. Everything else is deliberately
 * immutable here — the TODA and membership come from registration, the account
 * status from the audited administrator workflow, and the financial and
 * documentary history from the staff approval workflow.
 */
export async function OperatorProfile({
  bundle,
  barangays,
  basePath,
  canEdit,
  currentProfileId,
}: {
  bundle: OperatorProfileBundle;
  barangays: Barangay[];
  basePath: "/admin" | "/staff";
  canEdit: boolean;
  currentProfileId: string;
}) {
  const { profile, membership, applications, records } = bundle;
  if (profile.role !== "driver") notFound();

  const toda = profile.toda ?? null;
  const barangayName =
    profile.barangay?.name ??
    toda?.barangay?.name ??
    barangays.find((barangay) => barangay.code === profile.barangay_code)?.name ??
    null;

  const totalPaid = records.reduce((sum, record) => sum + (record.amount_paid ?? 0), 0);
  const receipts = records.filter((record) => record.official_receipt_number).length;
  const approved = applications.filter((application) => application.status === "approved").length;

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <SectionTitle
          title={profile.full_name}
          description={`${profile.email} · ${roleLabel(profile.role)} account`}
          action={
            <div className="flex flex-wrap gap-2">
              <Badge tone={STATUS_TONE[profile.account_status]}>
                {accountStatusLabel(profile.account_status)}
              </Badge>
              {membership ? <Badge tone="info">TODA member</Badge> : null}
            </div>
          }
        />
        <div className="flex flex-wrap gap-2">
          <LinkButton
            variant="outline"
            href={basePath === "/admin" ? "/admin/users?tab=operators" : "/staff/applications"}
          >
            <Users className="h-4 w-4" />
            {basePath === "/admin" ? "All operators" : "Applications"}
          </LinkButton>
        </div>
      </div>

      {isDemoMode() ? (
        <Alert tone="warning" title="Preview mode">
          These records are synthetic. Changes are disabled in preview mode.
        </Alert>
      ) : null}

      <div className="grid gap-4 xl:grid-cols-3">
        <div className="space-y-4 xl:col-span-2">
          <Card>
            <CardHeader
              title="Personal details"
              description={
                canEdit
                  ? "Correct the operator's contact details here. Name, e-mail and TODA are read-only."
                  : "Contact details recorded when the operator registered. Staff can view but not change them."
              }
              icon={UserRound}
            />

            <div className="mb-4 grid gap-x-6 gap-y-3 sm:grid-cols-3">
              <Detail label="First name" value={profile.first_name} />
              <Detail label="Middle name" value={profile.middle_name ?? "—"} />
              <Detail label="Last name" value={profile.last_name} />
              <Detail label="E-mail" value={profile.email} />
              <Detail label="Account status" value={accountStatusLabel(profile.account_status)} />
              <Detail label="Registered" value={formatDateTime(profile.created_at)} />
            </div>

            {canEdit ? (
              <OperatorDetailsForm profile={profile} barangays={barangays} />
            ) : (
              <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
                <Detail label="Contact number" value={profile.contact_number ?? "—"} />
                <Detail label="Barangay" value={barangayName ?? "Not provided"} />
                <Detail label="Address" value={profile.address_line ?? "Not provided"} />
                <Detail
                  label="Last sign-in"
                  value={profile.last_login_at ? formatDateTime(profile.last_login_at) : "Never"}
                />
              </dl>
            )}
          </Card>

          <Card>
            <CardHeader
              title="TODA membership"
              description="The association and roster entry the operator belongs to."
              icon={ShieldCheck}
            />
            {toda || membership ? (
              <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-3">
                <Detail
                  label="TODA"
                  value={toda ? `${toda.name} (${toda.code})` : "Unknown association"}
                />
                <Detail label="TODA barangay" value={toda?.barangay?.name ?? "—"} />
                <Detail label="Member reference" value={membership?.member_ref ?? "—"} mono />
                <Detail
                  label="Year joined"
                  value={membership?.year_joined ? String(membership.year_joined) : "—"}
                />
                <Detail
                  label="Roster status"
                  value={
                    membership ? (
                      <Badge tone={membership.is_active ? "success" : "neutral"}>
                        {membership.is_active ? "Active member" : "Inactive member"}
                      </Badge>
                    ) : (
                      "Not on the roster"
                    )
                  }
                />
                <Detail
                  label="Registered account"
                  value={membership?.profile_id ? "Linked" : "No roster entry claimed"}
                />
              </dl>
            ) : (
              <p className="text-[0.8125rem] text-muted">
                This operator has not been linked to a TODA or a membership roster entry yet.
              </p>
            )}
            <p className="mt-3 text-[0.75rem] text-muted">
              TODA assignment and roster details are fixed at registration. They are shown here
              for reference and cannot be edited from the profile module.
            </p>
          </Card>

          <Card>
            <CardHeader
              title="Application history"
              description={`${applications.length} application${applications.length === 1 ? "" : "s"} · ${approved} approved`}
              icon={FileText}
            />
            {applications.length === 0 ? (
              <p className="text-[0.8125rem] text-muted">
                No franchise application has been filed by this operator.
              </p>
            ) : (
              <div className="space-y-2">
                {applications.map((application) => (
                  <Link
                    key={application.id}
                    href={`${basePath}/applications/${application.id}`}
                    className="flex flex-wrap items-center justify-between gap-3 rounded-md border border-line px-3 py-2.5 transition-colors hover:bg-page"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-[0.8125rem] font-medium text-ink">
                        {application.application_number} ·{" "}
                        {applicationTypeLabel(application.application_type)}
                      </p>
                      <p className="truncate text-[0.75rem] text-muted">
                        {application.plate_number ?? "No plate recorded"} ·{" "}
                        {application.vehicle_make ?? "—"} {application.vehicle_model ?? ""} ·
                        submitted {formatDate(application.submitted_at)}
                      </p>
                    </div>
                    <Badge tone={APPLICATION_TONE[application.status]}>
                      {applicationStatusLabel(application.status)}
                    </Badge>
                  </Link>
                ))}
              </div>
            )}
          </Card>

          <Card>
            <CardHeader
              title="Payments and fees"
              description={`${records.length} franchise record${records.length === 1 ? "" : "s"} · ${receipts} official receipt${receipts === 1 ? "" : "s"} on file`}
              icon={Receipt}
            />
            {records.length === 0 ? (
              <p className="text-[0.8125rem] text-muted">
                No franchise record has been issued to this operator, so no fee has been recorded.
              </p>
            ) : (
              <div className="space-y-2">
                {records.map((record) => (
                  <Link
                    key={record.id}
                    href={`${basePath}/franchises/${record.id}`}
                    className="block rounded-md border border-line px-3 py-2.5 transition-colors hover:bg-page"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-3">
                      <div className="min-w-0">
                        <p className="truncate text-[0.8125rem] font-medium text-ink">
                          {record.franchise_number}
                        </p>
                        <p className="truncate text-[0.75rem] text-muted">
                          Issued {formatDate(record.issued_at)} · expires{" "}
                          {formatDate(record.expires_at)}
                          {record.archived ? " · archived" : ""}
                        </p>
                      </div>
                      <div className="text-right">
                        <p className="text-[0.875rem] font-semibold text-ink">
                          {record.amount_paid === null ? "No fee recorded" : PESO.format(record.amount_paid)}
                        </p>
                        <p className="text-[0.75rem] text-muted">
                          {record.official_receipt_number
                            ? `OR ${record.official_receipt_number}${
                                record.official_receipt_date
                                  ? ` · ${formatDate(record.official_receipt_date)}`
                                  : ""
                              }`
                            : "No official receipt"}
                        </p>
                      </div>
                    </div>
                  </Link>
                ))}
                <div className="flex items-center justify-between rounded-md bg-page px-3 py-2.5 text-[0.8125rem]">
                  <span className="font-medium text-ink">Total fees recorded</span>
                  <span className="font-semibold text-ink">{PESO.format(totalPaid)}</span>
                </div>
              </div>
            )}
          </Card>
        </div>

        <div className="space-y-4">
          <Card>
            <CardHeader title="Account summary" icon={BadgeCheck} />
            <dl className="space-y-2.5 text-[0.8125rem]">
              <Row label="Role" value={roleLabel(profile.role)} />
              <Row label="Status" value={accountStatusLabel(profile.account_status)} />
              <Row label="TODA" value={toda?.code ?? "Not assigned"} />
              <Row label="Applications" value={String(applications.length)} />
              <Row label="Franchise records" value={String(records.length)} />
              <Row label="Registered" value={formatDate(profile.created_at)} />
              <Row
                label="Last sign-in"
                value={profile.last_login_at ? formatDateTime(profile.last_login_at) : "Never"}
              />
            </dl>
            {profile.status_reason ? (
              <p className="mt-3 rounded-md bg-page px-3 py-2 text-[0.75rem] text-muted">
                Status note: {profile.status_reason}
              </p>
            ) : null}
          </Card>

          {canEdit ? (
            <Card>
              <CardHeader
                title="Account administration"
                description="Suspend, reactivate or delete the operator account. Each action is audited."
                icon={Stamp}
              />
              <UserActions profile={profile} currentProfileId={currentProfileId} />
            </Card>
          ) : (
            <Card>
              <CardHeader title="Account administration" />
              <p className="text-[0.8125rem] text-muted">
                Account status and deletion are handled by an administrator. Staff can review this
                profile but cannot change the account.
              </p>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

function Detail({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: ReactNode;
  mono?: boolean;
}) {
  return (
    <div>
      <dt className="text-[0.6875rem] uppercase tracking-wide text-muted">{label}</dt>
      <dd className={`text-[0.875rem] text-ink ${mono ? "font-mono" : ""}`}>{value}</dd>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-3">
      <dt className="text-muted">{label}</dt>
      <dd className="text-right font-medium text-ink">{value}</dd>
    </div>
  );
}
