import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import QRCode from "qrcode";

import { MUNICIPALITY, PROVINCE } from "@/lib/constants";
import { buildVerificationUrl } from "@/lib/verification";

export interface CertificateInput {
  franchiseNumber: string;
  verificationCode: string;
  operatorName: string;
  operatorAddress: string;
  todaName: string;
  plateNumber: string;
  vehicleMake: string;
  vehicleModel: string;
  vehicleYear: number;
  vehicleColor: string;
  engineNumber: string;
  chassisNumber: string;
  seatingCapacity: number;
  issuedAt: string;
  expiresAt: string;
  signatoryName: string;
  signatoryPosition: string;
  officeName: string;
  footerNote: string;
  verificationBaseUrl: string;

  // Official Authority to Operate (Image 2) fields. Optional so older callers
  // and tests keep working; blank values print as empty lines.
  applicationNumber?: string;
  route?: string;
  registeredOwner?: string;
  ownershipType?: string;
  boardName?: string;
  officialReceiptNumber?: string | null;
  officialReceiptDate?: string | null;
  amountPaid?: number | null;
  fareFirstKm?: string;
  fareSucceedingKm?: string;
  supervisionFee?: string;
  supervisionDue?: string;
  conformeName?: string;
  conformeSignatureDataUrl?: string | null;
}

/**
 * The certification paragraph printed above the particulars table.
 *
 * `MUNICIPALITY` already reads "Municipality of Mabini", so the name must not
 * be prefixed with "the Municipality of" again — that produced
 * "Municipality of Municipality of Mabini" on the certificate.
 */
export function buildCertificateBody(
  input: Pick<CertificateInput, "operatorName" | "operatorAddress" | "todaName">,
): string {
  return (
    `This certifies that ${input.operatorName.toUpperCase()}, of ${input.operatorAddress}, ` +
    `and a member in good standing of ${input.todaName}, is hereby granted a franchise to ` +
    `operate a tricycle-for-hire unit within the territorial jurisdiction of ` +
    `${MUNICIPALITY}, ${PROVINCE}, described as follows:`
  );
}

const OWNERSHIP_LABELS: Record<string, string> = {
  single_proprietorship: "Single Proprietorship",
  cooperative: "Cooperative",
  corporation: "Corporation",
  not_applicable: "N/A",
};

function valueOrDash(value: string | null | undefined): string {
  const trimmed = (value ?? "").trim();
  return trimmed.length > 0 ? trimmed : "—";
}

function peso(value: number | null | undefined): string {
  if (value === null || value === undefined) return "";
  return `PHP ${value.toLocaleString("en-PH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

/**
 * Builds the official "Authority to Operate Motorized Tricycle Service" PDF.
 *
 * The layout follows the municipal reference form: letterhead, title, applicant
 * particulars, conditions, SO ORDERED block, signatory, conforme signature and
 * the O.R. payment details. The QR verification code is kept as a discreet
 * footer carrying only the opaque verification URL.
 */
export async function buildCertificatePdf(input: CertificateInput): Promise<jsPDF> {
  const doc = new jsPDF({ unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 16;
  const center = pageWidth / 2;
  const contentWidth = pageWidth - margin * 2;

  // ---- letterhead ---------------------------------------------------------
  doc.setFont("times", "normal");
  doc.setFontSize(10);
  doc.text("Republic of the Philippines", center, 15, { align: "center" });
  doc.text(`Province of ${PROVINCE}`, center, 20, { align: "center" });
  doc.text(MUNICIPALITY, center, 25, { align: "center" });
  doc.setFont("times", "bold");
  doc.setFontSize(11.5);
  doc.text(
    (input.boardName ?? input.officeName).toUpperCase(),
    center,
    31,
    { align: "center", maxWidth: contentWidth },
  );

  doc.setDrawColor(39, 21, 100);
  doc.setLineWidth(0.7);
  doc.line(margin, 35, pageWidth - margin, 35);

  // ---- title --------------------------------------------------------------
  doc.setFont("times", "bold");
  doc.setFontSize(15);
  doc.text("AUTHORITY TO OPERATE", center, 44, { align: "center" });
  doc.text("MOTORIZED TRICYCLE SERVICE", center, 50, { align: "center" });

  // ---- intro --------------------------------------------------------------
  doc.setFont("times", "normal");
  doc.setFontSize(10);
  const intro = doc.splitTextToSize(
    `This Authority is issued to ${input.operatorName.toUpperCase()}, of ` +
      `${input.operatorAddress}, authorizing the operation of ONE (1) tricycle ` +
      `unit for public service under the following particulars:`,
    contentWidth,
  );
  doc.text(intro, margin, 59, { align: "justify", maxWidth: contentWidth });

  const tableTop = 59 + intro.length * 4.7 + 3;

  autoTable(doc, {
    startY: tableTop,
    margin: { left: margin, right: margin },
    theme: "grid",
    styles: {
      font: "times",
      fontSize: 9,
      cellPadding: 1.8,
      textColor: [22, 18, 19],
      lineColor: [160, 160, 160],
      lineWidth: 0.2,
    },
    columnStyles: {
      0: { fontStyle: "bold", cellWidth: 36 },
      1: { cellWidth: 55 },
      2: { fontStyle: "bold", cellWidth: 32 },
      3: { cellWidth: "auto" },
    },
    body: [
      ["Applicant", valueOrDash(input.operatorName), "Application No.", valueOrDash(input.applicationNumber)],
      ["Address", valueOrDash(input.operatorAddress), "TODA / Assoc.", valueOrDash(input.todaName)],
      ["Route / Service Area", valueOrDash(input.route), "Units", "ONE (1)"],
      ["Make / Model", `${input.vehicleMake} ${input.vehicleModel}`.trim(), "Plate No.", valueOrDash(input.plateNumber)],
      ["Motor No.", valueOrDash(input.engineNumber), "Chassis No.", valueOrDash(input.chassisNumber)],
      ["Registered Owner", valueOrDash(input.registeredOwner || input.operatorName), "Type of Ownership", OWNERSHIP_LABELS[input.ownershipType ?? ""] ?? "N/A"],
      ["Franchise No.", valueOrDash(input.franchiseNumber), "Valid Until", formatLongDate(input.expiresAt)],
    ],
  });

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let cursor = ((doc as any).lastAutoTable?.finalY as number | undefined) ?? tableTop + 45;
  cursor += 7;

  // ---- conditions ---------------------------------------------------------
  const fareFirst = input.fareFirstKm ?? "8.00";
  const fareNext = input.fareSucceedingKm ?? "1.00";
  const supervision = input.supervisionFee ?? "120.00";
  const due = input.supervisionDue ?? "September 30";

  const conditions = [
    "That the operator shall operate the tricycle only within the authorized route or service area stated above;",
    `That the fare shall not exceed P${fareFirst} for the first kilometer and P${fareNext} for every succeeding kilometer;`,
    "That the unit shall be maintained in roadworthy condition and shall comply with all traffic laws and municipal ordinances;",
    "That the franchise shall not be sold, transferred or encumbered without the prior approval of the Board;",
    `That the operator shall pay an annual supervision fee of P${supervision} on or before ${due};`,
    "That the operator shall observe the rights and welfare of passengers and shall not refuse service without just cause;",
    "That this Authority may be revoked or suspended for violation of its conditions or of existing laws and regulations.",
  ];

  doc.setFont("times", "normal");
  doc.setFontSize(9);
  conditions.forEach((condition, index) => {
    const lines = doc.splitTextToSize(`${index + 1}. ${condition}`, contentWidth);
    doc.text(lines, margin, cursor, { align: "justify", maxWidth: contentWidth });
    cursor += lines.length * 4.2 + 1.1;
  });

  cursor += 5;
  doc.setFont("times", "bold");
  doc.setFontSize(10.5);
  doc.text("SO ORDERED.", margin, cursor);
  cursor += 6;
  doc.setFont("times", "normal");
  doc.setFontSize(9.5);
  doc.text(`Mabini, Batangas, ${formatLongDate(input.issuedAt)}.`, margin, cursor);

  // ---- signatures ---------------------------------------------------------
  const signatureY = cursor + 13;

  // Signatory (right)
  doc.setFont("times", "bold");
  doc.setFontSize(10);
  doc.text(input.signatoryName, pageWidth - margin, signatureY, { align: "right" });
  doc.setFont("times", "normal");
  doc.setFontSize(8.5);
  doc.text(input.signatoryPosition, pageWidth - margin, signatureY + 4, {
    align: "right",
    maxWidth: 80,
  });

  // Conforme (left)
  doc.setFontSize(9);
  doc.text("CONFORME:", margin, signatureY - 8);
  if (input.conformeSignatureDataUrl) {
    try {
      doc.addImage(
        input.conformeSignatureDataUrl,
        "PNG",
        margin,
        signatureY - 6,
        42,
        12,
        undefined,
        "FAST",
      );
    } catch {
      // A corrupt signature must never block the Authority.
    }
  }
  doc.setFont("times", "bold");
  doc.setFontSize(9.5);
  doc.text(
    (input.conformeName ?? input.operatorName).toUpperCase(),
    margin + 21,
    signatureY + 10,
    { align: "center", maxWidth: 60 },
  );
  doc.setDrawColor(60, 60, 60);
  doc.setLineWidth(0.2);
  doc.line(margin, signatureY + 11, margin + 42, signatureY + 11);
  doc.setFont("times", "normal");
  doc.setFontSize(8);
  doc.text("Applicant / Operator", margin + 21, signatureY + 14.5, { align: "center" });

  // ---- payment ------------------------------------------------------------
  const paymentY = signatureY + 23;
  doc.setDrawColor(39, 21, 100);
  doc.setLineWidth(0.4);
  doc.line(margin, paymentY, pageWidth - margin, paymentY);
  doc.setFont("times", "bold");
  doc.setFontSize(9);
  doc.text("PAID UNDER O.R. NO.", margin, paymentY + 5);
  doc.text(valueOrDash(input.officialReceiptNumber), margin + 40, paymentY + 5);

  doc.text("DATE", margin + 90, paymentY + 5);
  doc.setFont("times", "normal");
  doc.text(
    input.officialReceiptDate ? formatLongDate(input.officialReceiptDate) : "—",
    margin + 102,
    paymentY + 5,
  );

  doc.setFont("times", "bold");
  doc.text("AMOUNT PAID", margin + 138, paymentY + 5);
  doc.setFont("times", "normal");
  doc.text(peso(input.amountPaid) || "—", margin + 168, paymentY + 5);

  // ---- QR verification footer --------------------------------------------
  const verificationUrl = buildVerificationUrl(input.verificationBaseUrl, input.verificationCode);
  const qrDataUrl = await QRCode.toDataURL(verificationUrl, {
    errorCorrectionLevel: "M",
    margin: 1,
    width: 320,
    color: { dark: "#271564", light: "#FFFFFF" },
  });

  const qrSize = 18;
  const qrY = 262;
  doc.addImage(qrDataUrl, "PNG", margin, qrY, qrSize, qrSize, undefined, "FAST");
  doc.setFontSize(7.5);
  doc.setFont("helvetica", "bold");
  doc.text("Verify this Authority", margin + qrSize + 4, qrY + 4);
  doc.setFont("helvetica", "normal");
  doc.text(`Code: ${input.verificationCode}`, margin + qrSize + 4, qrY + 8);
  const footer = doc.splitTextToSize(input.footerNote, contentWidth - qrSize - 6);
  doc.text(footer, margin + qrSize + 4, qrY + 12);

  return doc;
}

export function formatLongDate(value: string): string {
  return new Date(value).toLocaleDateString("en-PH", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

/**
 * Storage path for the generated certificate.
 *
 * Must match the folder convention enforced by the storage policies and by
 * rpc_staff_attach_certificate(): `{operator profile id}/{franchise number}.pdf`.
 */
export function certificateStoragePath(operatorId: string, franchiseNumber: string): string {
  return `${operatorId}/${franchiseNumber}.pdf`;
}
