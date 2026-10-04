import Link from "next/link";
import { notFound } from "next/navigation";
import { Building2, Car, FileText, History, Stamp, User } from "lucide-react";

import { ApplicationSummaryCard, ReviewPanel } from "@/components/applications/review-panel";
import { StatusTimeline } from "@/components/applications/status-timeline";
import { Alert, Badge, Card, CardHeader, LinkButton, SectionTitle } from "@/components/ui";
import { getApplication, getApplicationDocumentsWithUrls } from "@/lib/data";
import { applicationTypeLabel, documentLabel, formatDate, relativeTime } from "@/lib/format";
import { isDemoMode } from "@/lib/env";

export async function ApplicationDetail({
  applicationId,
  basePath,
}: {
  applicationId: string;
  basePath: "/admin" | "/staff";
}) {
  const application = await getApplication(applicationId);
  if (!application) notFound();

  const documents = await getApplicationDocumentsWithUrls(applicationId);

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <SectionTitle
          title={`Application ${application.application_number}`}
          description={`${applicationTypeLabel(application.application_type)} · ${
            application.toda?.name ?? "TODA not set"
          } · submitted ${relativeTime(application.submitted_at)}`}
        />
        <div className="flex gap-2">
          <LinkButton variant="outline" href={`${basePath}/applications`}>
            Back to register
          </LinkButton>
          {application.record ? (
            <LinkButton href={`${basePath}/franchises/${application.record.id}`}>
              <Stamp className="h-4 w-4" />
              {application.record.franchise_number}
            </LinkButton>
          ) : null}
        </div>
      </div>

      {isDemoMode() ? (
        <Alert tone="warning" title="Preview mode">
          Every action below is disabled and no document file exists. The layout, the workflow rules
          and the validation messages are the ones the live system uses.
        </Alert>
      ) : null}

      <div className="grid gap-4 xl:grid-cols-3">
        <div className="space-y-4 xl:col-span-2">
          <Card>
            <CardHeader title="Operator and vehicle as declared" icon={Car} />
            <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
              <Field label="Operator" value={operatorName(application)} />
              <Field label="Contact number" value={application.operator_contact_number} />
              <Field label="Address" value={application.operator_address_line} />
              <Field label="Barangay" value={application.operator_barangay_code ?? "—"} />
              <Field label="E-mail" value={application.operator_email ?? "—"} />
              <Field label="TODA" value={application.toda?.name ?? "—"} />
              <Field
                label="Plate number"
                value={application.plate_number}
                mono
              />
              <Field
                label="Make and model"
                value={`${application.vehicle_make} ${application.vehicle_model}`}
              />
              <Field label="Year model" value={String(application.vehicle_year)} />
              <Field label="Color" value={application.vehicle_color} />
              <Field label="Engine number" value={application.engine_number} mono />
              <Field label="Chassis number" value={application.chassis_number} mono />
              <Field label="Seating capacity" value={String(application.seating_capacity)} />
              <Field label="MTOP number" value={application.mtop_number ?? "—"} />
              <Field label="Body number" value={application.body_number ?? "—"} />
              {application.renewal_of_record_id ? (
                <Field
                  label="Renewal of"
                  value={application.renewal_of_record_id}
                  mono
                  hint="The predecessor franchise record; it is not modified by the renewal."
                />
              ) : null}
            </dl>
          </Card>

          <ReviewPanel application={application} documents={documents} />
        </div>

        <div className="space-y-4">
          <ApplicationSummaryCard application={application} />

          <Card>
            <CardHeader title="Applicant account" icon={User} />
            <dl className="space-y-2 text-[0.8125rem]">
              <Row label="Name" value={application.applicant?.full_name ?? "—"} />
              <Row label="E-mail" value={application.applicant?.email ?? "—"} />
              <Row label="Contact" value={application.applicant?.contact_number ?? "—"} />
              <Row
                label="Account status"
                value={application.applicant?.account_status ?? "—"}
                badge={
                  application.applicant?.account_status === "active" ? "success" : "warning"
                }
              />
            </dl>
            <p className="mt-3 text-[0.75rem] text-muted">
              Operator details above are the values declared on the application; the account links
              the submission to a verified mobile login.
            </p>
          </Card>

          <Card>
            <CardHeader title="Documents" description="Files open through short-lived signed links." icon={FileText} />
            <ul className="space-y-2 text-[0.8125rem]">
              {documents.map((document) => (
                <li key={document.id} className="flex items-center justify-between gap-3">
                  <span className="text-muted">{documentLabel(document.document_type)}</span>
                  <Badge
                    tone={
                      document.verification_status === "verified"
                        ? "success"
                        : document.verification_status === "rejected"
                          ? "rejected"
                          : "pending"
                    }
                  >
                    {document.verification_status}
                  </Badge>
                </li>
              ))}
              {documents.length === 0 ? <li className="text-muted">No documents uploaded.</li> : null}
            </ul>
          </Card>

          <Card>
            <CardHeader title="Status timeline" icon={History} />
            <StatusTimeline events={application.timeline ?? []} />
          </Card>

          <Card>
            <CardHeader title="Record linkage" icon={Building2} />
            {application.record ? (
              <div className="space-y-2 text-[0.8125rem]">
                <Row label="Franchise number" value={application.record.franchise_number} mono />
                <Row label="Issued" value={formatDate(application.record.issued_at)} />
                <Row label="Valid until" value={formatDate(application.record.expires_at)} />
                <Row label="Archived" value={application.record.archived ? "Yes" : "No"} />
                <Link
                  className="inline-flex items-center gap-1 pt-1 font-medium text-primary hover:underline"
                  href={`${basePath}/franchises/${application.record.id}`}
                >
                  Open franchise record
                </Link>
              </div>
            ) : (
              <p className="text-[0.8125rem] text-muted">
                No franchise has been issued for this application
                {application.status === "rejected"
                  ? " because it was rejected."
                  : ". Approval creates the record automatically."}
              </p>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}

function operatorName(application: { operator_first_name: string; operator_last_name: string }): string {
  return `${application.operator_last_name}, ${application.operator_first_name}`;
}

function Field({
  label,
  value,
  mono = false,
  hint,
}: {
  label: string;
  value: string;
  mono?: boolean;
  hint?: string;
}) {
  return (
    <div>
      <dt className="text-[0.6875rem] uppercase tracking-wide text-muted">{label}</dt>
      <dd className={`text-[0.875rem] text-ink ${mono ? "font-mono" : ""}`}>{value}</dd>
      {hint ? <p className="mt-0.5 text-[0.6875rem] text-muted">{hint}</p> : null}
    </div>
  );
}

function Row({
  label,
  value,
  mono = false,
  badge,
}: {
  label: string;
  value: string;
  mono?: boolean;
  badge?: "success" | "warning";
}) {
  return (
    <div className="flex items-center justify-between gap-3">
      <dt className="text-muted">{label}</dt>
      <dd className={`text-right font-medium text-ink ${mono ? "font-mono" : ""}`}>
        {badge ? <Badge tone={badge}>{value}</Badge> : value}
      </dd>
    </div>
  );
}
