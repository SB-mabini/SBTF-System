"use client";

import { useState } from "react";
import { FileText, Loader2 } from "lucide-react";

import { Alert, Button } from "@/components/ui";
import { buildApplicationFormPdf } from "@/lib/application-form";
import { MUNICIPALITY, PROVINCE } from "@/lib/constants";
import type { FranchiseApplicationDetail } from "@/types/database";

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

function formatDate(value: string | null | undefined): string {
  if (!value) return "—";
  return new Date(value).toLocaleDateString("en-PH", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export function ApplicationFormActions({
  application,
  signatureUrl,
}: {
  application: FranchiseApplicationDetail;
  signatureUrl: string | null;
}) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  async function generate() {
    setBusy(true);
    setMessage(null);
    try {
      const signature = await dataUrlFromUrl(signatureUrl);
      const address = [application.operator_address_line, MUNICIPALITY, PROVINCE]
        .filter((part) => Boolean(part && String(part).trim()))
        .join(", ");

      const doc = buildApplicationFormPdf({
        applicationNumber: application.application_number,
        familyName: application.operator_last_name,
        givenName: application.operator_first_name,
        middleName: application.operator_middle_name,
        citizenship: application.operator_citizenship,
        address,
        appliedRoute: application.applied_route,
        make: application.vehicle_make,
        model: application.vehicle_model,
        motorNumber: application.engine_number,
        chassisNumber: application.chassis_number,
        plateNumber: application.plate_number,
        registeredOwner: application.registered_owner,
        ownershipType: application.ownership_type,
        ctcNumber: application.ctc_number,
        ctcIssuedAt: application.ctc_issued_at,
        ctcIssuedOn: application.ctc_issued_on ? formatDate(application.ctc_issued_on) : null,
        applicantName: [
          application.operator_first_name,
          application.operator_middle_name,
          application.operator_last_name,
        ]
          .filter(Boolean)
          .join(" "),
        signatureDataUrl: signature,
        printedAt: formatDate(new Date().toISOString()),
      });

      const url = doc.output("bloburl");
      window.open(String(url), "_blank", "noopener,noreferrer");
    } catch (error) {
      setMessage(
        `The application form could not be generated: ${
          error instanceof Error ? error.message : "unknown error"
        }`,
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-2">
      <Button variant="secondary" onClick={generate} loading={busy}>
        {busy ? <Loader2 className="h-4 w-4 animate-spin" /> : <FileText className="h-4 w-4" />}
        Print application form (PDF)
      </Button>
      {message ? <Alert tone="danger">{message}</Alert> : null}
    </div>
  );
}
