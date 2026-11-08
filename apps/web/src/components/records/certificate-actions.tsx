"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Download, FileCheck2, Loader2, Printer, Stamp } from "lucide-react";

import { Alert, Button, Card, CardHeader } from "@/components/ui";
import { attachCertificateAction, logActivityAction } from "@/lib/actions/applications";
import { buildCertificatePdf, certificateStoragePath } from "@/lib/certificate";
import { MUNICIPALITY, PROVINCE } from "@/lib/constants";
import { getBrowserClient } from "@/lib/supabase/client";
import { isDemoMode } from "@/lib/env";
import { formatDate } from "@/lib/format";
import { resolveVerificationBaseUrl } from "@/lib/verification";
import type { FranchiseRecordDetail, SystemSetting } from "@/types/database";

interface CertificateActionsProps {
  record: FranchiseRecordDetail;
  certificateUrl: string | null;
  settings: SystemSetting[];
  readOnly?: boolean;
  signatureUrl?: string | null;
}

function settingValue(settings: SystemSetting[], key: string, fallback: string): string {
  const setting = settings.find((candidate) => candidate.key === key);
  if (!setting) return fallback;
  return typeof setting.value === "string" ? setting.value : String(setting.value ?? fallback);
}

async function dataUrlFromUrl(url: string | null | undefined): Promise<string | null> {
  if (!url) return null;
  try {
    const response = await fetch(url);
    if (!response.ok) return null;
    const blob = await response.blob();
    return await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(String(reader.result));
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  } catch {
    return null;
  }
}

export function CertificateActions({ record, certificateUrl, settings, readOnly: externalReadOnly = false, signatureUrl }: CertificateActionsProps) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  const [busy, setBusy] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(certificateUrl);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  const generated = Boolean(record.certificate_storage_path) || Boolean(previewUrl);
  const readOnly = isDemoMode() || externalReadOnly;

  async function generate() {
    setBusy(true);
    setMessage(null);

    try {
      const application = record.application;
      const operatorName =
        record.operator?.full_name ??
        ([application?.operator_first_name, application?.operator_middle_name, application?.operator_last_name]
          .filter(Boolean)
          .join(" ") ||
          "Operator");
      const addressParts = [application?.operator_address_line, MUNICIPALITY, PROVINCE].filter(
        (part) => Boolean(part && String(part).trim()),
      );
      const conformeSignature = await dataUrlFromUrl(signatureUrl);

      const doc = await buildCertificatePdf({
        franchiseNumber: record.franchise_number,
        verificationCode: record.verification_code,
        operatorName,
        operatorAddress: addressParts.length ? addressParts.join(", ") : `${MUNICIPALITY}, ${PROVINCE}`,
        todaName: record.toda?.name ?? "TODA",
        plateNumber: application?.plate_number ?? "—",
        vehicleMake: application?.vehicle_make ?? "—",
        vehicleModel: application?.vehicle_model ?? "—",
        vehicleYear: application?.vehicle_year ?? new Date().getFullYear(),
        vehicleColor: application?.vehicle_color ?? "—",
        engineNumber: application?.engine_number ?? "—",
        chassisNumber: application?.chassis_number ?? "—",
        seatingCapacity: application?.seating_capacity ?? 1,
        issuedAt: record.issued_at,
        expiresAt: record.expires_at,
        signatoryName: settingValue(settings, "certificate_signatory_name", "Municipal Mayor"),
        signatoryPosition: settingValue(settings, "certificate_signatory_position", "Municipal Mayor"),
        officeName: settingValue(
          settings,
          "office_name",
          "Sangguniang Bayan ng Mabini — Committee on Transportation",
        ),
        footerNote: settingValue(
          settings,
          "certificate_footer_note",
          "This Authority is verifiable through the QR code printed on it.",
        ),
        verificationBaseUrl: resolveVerificationBaseUrl(
          settingValue(settings, "certificate_verification_base_url", ""),
          { requestOrigin: window.location.origin },
        ),
        applicationNumber: application?.application_number ?? undefined,
        route: application?.applied_route ?? undefined,
        registeredOwner: application?.registered_owner ?? undefined,
        ownershipType: application?.ownership_type ?? undefined,
        boardName: settingValue(
          settings,
          "certificate_board_name",
          "MABINI TRICYCLE FRANCHISING AND REGULATORY BOARD",
        ),
        officialReceiptNumber: record.official_receipt_number,
        officialReceiptDate: record.official_receipt_date,
        amountPaid: record.amount_paid,
        fareFirstKm: settingValue(settings, "certificate_fare_first_km", "8.00"),
        fareSucceedingKm: settingValue(settings, "certificate_fare_succeeding_km", "1.00"),
        supervisionFee: settingValue(settings, "certificate_supervision_fee", "120.00"),
        supervisionDue: settingValue(settings, "certificate_supervision_due", "September 30"),
        conformeName: operatorName,
        conformeSignatureDataUrl: conformeSignature,
      });

      const blob = doc.output("blob");
      const localUrl = URL.createObjectURL(blob);
      setPreviewUrl(localUrl);

      if (isDemoMode()) {
        setMessage({
          ok: true,
          text: "Preview mode: the PDF was generated in your browser but is not uploaded to Storage.",
        });
        setBusy(false);
        return;
      }

      const path = certificateStoragePath(record.operator_id, record.franchise_number);
      const supabase = getBrowserClient();
      const { error: uploadError } = await supabase.storage
        .from("certificates")
        .upload(path, blob, { contentType: "application/pdf", upsert: true });

      if (uploadError) {
        setMessage({ ok: false, text: `The certificate could not be uploaded: ${uploadError.message}` });
        setBusy(false);
        return;
      }

      const attached = await attachCertificateAction({ recordId: record.id, storagePath: path });
      await logActivityAction({ action: "certificate_generation", targetType: "franchise_record", targetId: record.id });

      setMessage({ ok: attached.ok, text: attached.message });
      setBusy(false);
      startTransition(() => router.refresh());
    } catch (error) {
      setBusy(false);
      setMessage({
        ok: false,
        text: `The certificate could not be generated: ${error instanceof Error ? error.message : "unknown error"}`,
      });
    }
  }

  return (
    <Card>
      <CardHeader
        title="Authority to Operate"
        description="Official Authority to Operate Motorized Tricycle Service. Generated in the browser and stored privately; retrieved only through short-lived signed links."
        icon={Stamp}
      />

      {message ? (
        <div className="mb-3">
          <Alert tone={message.ok ? "success" : "danger"}>{message.text}</Alert>
        </div>
      ) : null}

      <dl className="mb-4 grid gap-2 text-[0.8125rem] sm:grid-cols-2">
        <div>
          <dt className="text-muted">Certificate status</dt>
          <dd className="font-medium text-ink">
            {record.certificate_storage_path ? "Generated and stored" : generated ? "Generated in this session" : "Not generated"}
          </dd>
        </div>
        <div>
          <dt className="text-muted">Last generated</dt>
          <dd className="font-medium text-ink">
            {record.certificate_generated_at ? formatDate(record.certificate_generated_at) : "—"}
          </dd>
        </div>
        <div>
          <dt className="text-muted">Verification code</dt>
          <dd className="font-mono text-[0.8125rem] text-ink">{record.verification_code}</dd>
        </div>
        <div>
          <dt className="text-muted">Validity</dt>
          <dd className="font-medium text-ink">
            {formatDate(record.issued_at)} — {formatDate(record.expires_at)}
          </dd>
        </div>
      </dl>

      <div className="flex flex-wrap gap-2">
        {externalReadOnly ? null : (
          <Button
            onClick={generate}
            loading={busy}
            disabled={readOnly && generated}
            title={readOnly ? "Available without upload in preview mode" : undefined}
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <FileCheck2 className="h-4 w-4" />}
            {generated ? "Regenerate Authority" : "Generate Authority"}
          </Button>
        )}

        {previewUrl ? (
          <>
            <a
              className="inline-flex items-center gap-2 rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
              href={previewUrl}
              target="_blank"
              rel="noreferrer"
            >
              <Printer className="h-4 w-4" />
              Open / print
            </a>
            <a
              className="inline-flex items-center gap-2 rounded-lg border border-line-strong bg-white px-3.5 py-2 text-[0.8125rem] font-medium text-ink hover:bg-page"
              download={`${record.franchise_number}.pdf`}
              href={previewUrl}
            >
              <Download className="h-4 w-4" />
              Download PDF
            </a>
          </>
        ) : null}
      </div>

      <p className="mt-3 text-[0.75rem] text-muted">
        The QR code contains only the verification code. Printing a certificate from this page
        reproduces the same code, so the printed copy can be checked on the public verification
        page.
      </p>
    </Card>
  );
}
