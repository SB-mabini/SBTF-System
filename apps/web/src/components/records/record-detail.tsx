import Link from "next/link";
import { notFound } from "next/navigation";
import { Archive, CalendarCheck, FileText, Link2, ShieldCheck, Stamp } from "lucide-react";

import { CertificateActions } from "@/components/records/certificate-actions";
import { ArchiveActions } from "@/components/records/archive-actions";
import { VerificationQr } from "@/components/records/verification-qr";
import { Alert, Card, CardHeader, LinkButton, SectionTitle } from "@/components/ui";
import { getCertificateSignedUrl, getFranchiseRecord, listSettings } from "@/lib/data";
import { formatDate, formatDateTime, humanizeKey } from "@/lib/format";
import { buildVerificationUrl } from "@/lib/verification";
import { isDemoMode } from "@/lib/env";
import type { SystemSetting } from "@/types/database";

function settingValue(settings: SystemSetting[], key: string, fallback: string): string {
  const setting = settings.find((candidate) => candidate.key === key);
  if (!setting) return fallback;
  return typeof setting.value === "string" ? setting.value : String(setting.value ?? fallback);
}

export async function RecordDetail({
  recordId,
  basePath,
}: {
  recordId: string;
  basePath: "/admin" | "/staff";
}) {
  const record = await getFranchiseRecord(recordId);
  if (!record) notFound();

  const [certificateUrl, settings] = await Promise.all([
    getCertificateSignedUrl(recordId),
    listSettings(),
  ]);

  const verificationBaseUrl = settingValue(
    settings,
    "certificate_verification_base_url",
    "https://sbtf-mabini.example.gov.ph/verify",
  );

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <SectionTitle
          title={record.franchise_number}
          description={`Issued ${formatDate(record.issued_at)} · valid until ${formatDate(record.expires_at)} · ${
            record.archived ? "archived" : "active"
          }`}
        />
        <div className="flex flex-wrap gap-2">
          <LinkButton variant="outline" href={`${basePath}/franchises`}>
            Back to records
          </LinkButton>
          <LinkButton variant="outline" href={`${basePath}/applications/${record.application_id}`}>
            <FileText className="h-4 w-4" />
            Source application
          </LinkButton>
        </div>
      </div>

      {record.archived ? (
        <Alert tone="warning" title="Archived franchise">
          Archived {formatDateTime(record.archived_at)}.
          {record.archive_reason ? ` Reason: ${record.archive_reason}` : ""} Archiving does not
          change the franchise number, the validity dates or the verification code.
        </Alert>
      ) : null}

      {isDemoMode() ? (
        <Alert tone="warning" title="Preview mode">
          Certificate generation runs entirely in the browser, so it works here too — but nothing is
          uploaded to Storage and the archive actions are disabled.
        </Alert>
      ) : null}

      <div className="grid gap-4 xl:grid-cols-3">
        <div className="space-y-4 xl:col-span-2">
          <Card>
            <CardHeader title="Franchise particulars" icon={Stamp} />
            <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-2">
              <Field label="Franchise number" value={record.franchise_number} mono />
              <Field label="Verification code" value={record.verification_code} mono />
              <Field label="Issued" value={formatDate(record.issued_at)} />
              <Field label="Valid until" value={formatDate(record.expires_at)} />
              <Field label="Operator" value={record.operator?.full_name ?? "—"} />
              <Field label="Operator contact" value={record.operator?.contact_number ?? "—"} />
              <Field label="TODA" value={record.toda?.name ?? "—"} />
              <Field
                label="Application"
                value={record.application?.application_number ?? "—"}
                mono
              />
              <Field label="Plate number" value={record.application?.plate_number ?? "—"} mono />
              <Field
                label="Make and model"
                value={
                  record.application
                    ? `${record.application.vehicle_make} ${record.application.vehicle_model} (${record.application.vehicle_year})`
                    : "—"
                }
              />
              <Field
                label="Certificate stored"
                value={record.certificate_storage_path ? "Yes" : "No"}
              />
              <Field
                label="Certificate generated"
                value={
                  record.certificate_generated_at ? formatDateTime(record.certificate_generated_at) : "Not generated"
                }
              />
            </dl>
          </Card>

          <CertificateActions record={record} certificateUrl={certificateUrl} settings={settings} />

          <Card>
            <CardHeader title="Archive" description="Operational status only — the documentary record is preserved." icon={Archive} />
            <ArchiveActions recordId={record.id} archived={record.archived} />
          </Card>
        </div>

        <div className="space-y-4">
          <Card>
            <CardHeader title="Public verification" icon={ShieldCheck} />
            <VerificationQr code={record.verification_code} baseUrl={verificationBaseUrl} />
            <p className="mt-3 text-[0.75rem] text-muted">
              Anyone can check this franchise on the public page, which returns only the validity
              status, the franchise number, a masked operator name and the association. The QR code
              never contains the operator&apos;s identity or contact details.
            </p>
            <a
              className="mt-3 inline-flex items-center gap-1.5 text-[0.8125rem] font-medium text-primary hover:underline"
              href={buildVerificationUrl(verificationBaseUrl, record.verification_code)}
              rel="noreferrer"
              target="_blank"
            >
              Open the public verification page
              <Link2 className="h-3.5 w-3.5" />
            </a>
          </Card>

          <Card>
            <CardHeader title="Renewal chain" icon={CalendarCheck} />
            {record.renewed_by_record_id ? (
              <>
                <p className="text-[0.8125rem] text-muted">
                  This franchise has been renewed. The successor record continues the validity
                  period; this record is retained unchanged for the audit trail.
                </p>
                <Link
                  className="mt-2 inline-flex items-center gap-1.5 text-[0.8125rem] font-medium text-primary hover:underline"
                  href={`${basePath}/franchises/${record.renewed_by_record_id}`}
                >
                  Open the renewal record
                </Link>
              </>
            ) : (
              <p className="text-[0.8125rem] text-muted">
                No renewal has been linked to this franchise yet. A renewal submitted from the mobile
                application references this record and, once approved, is linked back to it.
              </p>
            )}
          </Card>

          <Card>
            <CardHeader title="Record metadata" />
            <dl className="space-y-2 text-[0.8125rem]">
              <Row label="Created" value={formatDateTime(record.created_at)} />
              <Row label="Last updated" value={formatDateTime(record.updated_at)} />
              <Row label="Archived" value={record.archived ? "Yes" : "No"} />
              <Row label="Issued by" value={record.archived_by ? record.archived_by.slice(0, 8) : "—"} />
            </dl>
            <p className="mt-3 text-[0.75rem] text-muted">
              Franchise records are append-oriented: the certificate attaches to the record but never
              rewrites the issued number or dates. Corrections are made through the
              archive-and-reissue workflow so the history stays readable.
            </p>
          </Card>

          <Card>
            <CardHeader title="Field reference" />
            <dl className="space-y-1.5 text-[0.75rem] text-muted">
              {Object.entries({
                franchise_number: "Municipal franchise identifier, format MAB-TR-YYYY-NNNNNN.",
                verification_code: "Twelve-character public identifier used by the QR code.",
                expires_at: "End of the validity period; renewal reminders run at 90, 60 and 30 days.",
                renewed_by_record_id: "Successor record created by an approved renewal.",
              }).map(([key, note]) => (
                <div key={key}>
                  <dt className="font-medium text-ink">{humanizeKey(key)}</dt>
                  <dd>{note}</dd>
                </div>
              ))}
            </dl>
          </Card>
        </div>
      </div>
    </div>
  );
}

function Field({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) {
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
