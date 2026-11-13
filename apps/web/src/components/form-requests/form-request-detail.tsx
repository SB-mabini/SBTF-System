"use client";

import { useMemo, useState } from "react";
import { Download, FileText, Printer } from "lucide-react";

import { FormRequestActions } from "@/components/form-requests/form-request-actions";
import { Alert, Badge, Button, Card, CardHeader } from "@/components/ui";
import { APPLICATION_TYPE_LABELS, FORM_REQUEST_STATUS_LABELS } from "@/lib/constants";
import {
  buildFormRequestLetterPdf,
  FORM_REQUEST_LETTER_DEFAULTS,
  type FormRequestLetterInput,
} from "@/lib/form-request-letter";
import { formatDateTime, isPast } from "@/lib/format";
import type { FormRequestDetail } from "@/lib/data";
import type { FormRequestStatus } from "@/types/database";

const STATUS_TONE: Record<FormRequestStatus, "info" | "warning" | "success" | "danger" | "neutral"> = {
  requested: "warning",
  issued: "info",
  rejected: "danger",
  converted: "success",
  cancelled: "neutral",
};

function Row({ label, value }: { label: string; value: string | null | undefined }) {
  return (
    <div>
      <dt className="text-[0.75rem] font-medium uppercase tracking-wide text-muted">{label}</dt>
      <dd className="mt-0.5 text-[0.875rem] text-ink">{value && value.trim() ? value : "—"}</dd>
    </div>
  );
}

export function FormRequestDetailView({
  request,
  settings,
  signatureDataUrl,
  orCrUrl,
}: {
  request: FormRequestDetail;
  settings: Record<string, string>;
  signatureDataUrl?: string | null;
  orCrUrl?: string | null;
}) {
  const [error, setError] = useState<string | null>(null);
  const [printing, setPrinting] = useState(false);

  const overdue =
    request.status === "requested" && isPast(request.review_due_at);

  const letterInput = useMemo<FormRequestLetterInput>(
    () => ({
      formNumber: request.form_number,
      applicationType: APPLICATION_TYPE_LABELS[request.application_type],
      applicantName:
        request.applicant?.full_name ?? request.applicant_name ?? "Applicant",
      contactNumber: request.contact_number ?? request.applicant?.contact_number ?? null,
      address: "",
      todaName: request.toda?.name ?? "—",
      ctcNumber: request.ctc_number,
      vehicleMake: request.vehicle_make,
      vehicleModel: request.vehicle_model,
      engineNumber: request.engine_number,
      chassisNumber: request.chassis_number,
      plateNumber: request.plate_number,
      crNumber: request.cr_number,
      requestedAt: request.requested_at,
      addressee: settings.form_request_addressee ?? FORM_REQUEST_LETTER_DEFAULTS.addressee,
      municipality: settings.form_request_municipality ?? FORM_REQUEST_LETTER_DEFAULTS.municipality,
      location: settings.form_request_location ?? FORM_REQUEST_LETTER_DEFAULTS.location,
      body: settings.form_request_body ?? FORM_REQUEST_LETTER_DEFAULTS.body,
      signatureDataUrl: signatureDataUrl ?? null,
      signatureName: request.signature_typed_name,
    }),
    [request, settings, signatureDataUrl],
  );

  function handlePrint() {
    setPrinting(true);
    setError(null);
    try {
      const pdf = buildFormRequestLetterPdf(letterInput);
      pdf.save(`${request.form_number}.pdf`);
    } catch (printError) {
      setError(
        printError instanceof Error
          ? printError.message
          : "Could not build the printable letter.",
      );
    } finally {
      setPrinting(false);
    }
  }

  return (
    <div className="space-y-5">
      <Card>
        <CardHeader
          title={request.form_number}
          description={`${APPLICATION_TYPE_LABELS[request.application_type]} request`}
          icon={FileText}
          action={
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={STATUS_TONE[request.status]}>
                {FORM_REQUEST_STATUS_LABELS[request.status]}
              </Badge>
              {request.printed_at ? <Badge tone="success">Printed</Badge> : null}
              {overdue ? <Badge tone="danger">Review overdue</Badge> : null}
            </div>
          }
        />

        <div className="space-y-4">
          {error ? <Alert tone="danger">{error}</Alert> : null}

          <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <Row
              label="Applicant"
              value={request.applicant?.full_name ?? request.applicant_name}
            />
            <Row
              label="Contact number"
              value={request.contact_number ?? request.applicant?.contact_number}
            />
            <Row label="TODA" value={request.toda?.name} />
            <Row label="CTC / Cedula number" value={request.ctc_number} />
            <Row label="Requested" value={formatDateTime(request.requested_at)} />
            <Row
              label="Staff review deadline"
              value={
                request.review_due_at
                  ? `${formatDateTime(request.review_due_at)}${overdue ? " (overdue)" : ""}`
                  : null
              }
            />
            <Row label="Reviewed" value={request.reviewed_at ? formatDateTime(request.reviewed_at) : null} />
            <Row label="Issued" value={request.issued_at ? formatDateTime(request.issued_at) : null} />
            <Row label="Printed" value={request.printed_at ? formatDateTime(request.printed_at) : null} />
          </dl>

          {request.purpose ? (
            <div>
              <p className="text-[0.75rem] font-medium uppercase tracking-wide text-muted">Purpose</p>
              <p className="mt-0.5 text-[0.875rem] text-ink">{request.purpose}</p>
            </div>
          ) : null}

          {request.rejection_reason ? (
            <Alert tone="danger" title="Returned to the driver">
              {request.rejection_reason}
            </Alert>
          ) : null}

          {request.converted_application_id ? (
            <Alert tone="success" title="Converted">
              This request was consumed by application{" "}
              <span className="font-mono">{request.converted_application_id}</span>.
            </Alert>
          ) : null}

          <div className="flex flex-wrap gap-2">
            <Button variant="secondary" loading={printing} onClick={handlePrint}>
              <Printer className="h-4 w-4" />
              Print letter (PDF)
            </Button>
            {request.or_cr_storage_path ? (
              <Badge tone="success">OR/CR on file</Badge>
            ) : (
              <Badge tone="warning">No OR/CR on file (legacy request)</Badge>
            )}
          </div>

          <FormRequestActions
            formRequestId={request.id}
            status={request.status}
            printed={Boolean(request.printed_at)}
            convertedApplicationId={request.converted_application_id}
          />
        </div>
      </Card>

      {request.or_cr_storage_path ? (
        <Card>
          <CardHeader
            title="OR/CR on file"
            description={request.or_cr_file_name ?? "Attached to this request and reused by the application."}
          />
          {orCrUrl ? (
            <div className="space-y-3">
              {request.or_cr_mime_type?.startsWith("image/") ? (
                <a href={orCrUrl} target="_blank" rel="noreferrer" className="block">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={orCrUrl}
                    alt={`OR/CR for ${request.form_number}`}
                    className="max-h-[32rem] w-auto rounded-lg border border-line"
                  />
                </a>
              ) : request.or_cr_mime_type === "application/pdf" ? (
                <iframe
                  src={orCrUrl}
                  title={`OR/CR for ${request.form_number}`}
                  className="h-[32rem] w-full rounded-lg border border-line"
                />
              ) : null}
              <a
                href={orCrUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 text-[0.8125rem] font-medium text-primary hover:underline"
              >
                <Download className="h-4 w-4" />
                Open / download OR/CR
              </a>
            </div>
          ) : (
            <p className="text-[0.875rem] text-muted">
              The file could not be previewed. Reload the page or open the request again.
            </p>
          )}
        </Card>
      ) : null}

      <Card>
        <CardHeader
          title="Vehicle identity"
          description="These values are copied into the application when the driver submits it."
        />
        <dl className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Row label="Plate number" value={request.plate_number} />
          <Row label="Make" value={request.vehicle_make} />
          <Row label="Model" value={request.vehicle_model} />
          <Row label="Engine number" value={request.engine_number} />
          <Row label="Chassis number" value={request.chassis_number} />
          <Row label="CR number" value={request.cr_number} />
        </dl>
      </Card>

      <Card>
        <CardHeader title="Signature" description="Drawn in the mobile app, or typed when drawing is not possible." />
        {request.signature_storage_path ? (
          <p className="text-[0.875rem] text-ink">
            A drawn signature is on file. It is included in the printed letter.
          </p>
        ) : (
          <p className="text-[0.875rem] text-ink">
            Typed signature: {request.signature_typed_name ?? "—"}
          </p>
        )}
      </Card>
    </div>
  );
}
