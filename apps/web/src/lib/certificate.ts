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
}

/**
 * Builds the franchise certificate PDF in the browser.
 *
 * The QR code carries a single value: the verification URL with the opaque
 * 12-character code. No name, address, contact number, plate number or other
 * personal data is encoded in the QR code — exactly as required by the data
 * privacy design of the system.
 */
export async function buildCertificatePdf(input: CertificateInput): Promise<jsPDF> {
  const doc = new jsPDF({ unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 18;
  const center = pageWidth / 2;

  // ---- letterhead ---------------------------------------------------------
  doc.setFont("times", "normal");
  doc.setFontSize(11);
  doc.text("Republic of the Philippines", center, 20, { align: "center" });
  doc.setFontSize(13);
  doc.setFont("times", "bold");
  doc.text(MUNICIPALITY.toUpperCase(), center, 27, { align: "center" });
  doc.setFontSize(11);
  doc.setFont("times", "normal");
  doc.text(`Province of ${PROVINCE}`, center, 33, { align: "center" });
  doc.setFontSize(9);
  doc.text(input.officeName, center, 39, { align: "center", maxWidth: pageWidth - margin * 2 });

  doc.setDrawColor(39, 21, 100);
  doc.setLineWidth(0.8);
  doc.line(margin, 44, pageWidth - margin, 44);

  // ---- title --------------------------------------------------------------
  doc.setFont("times", "bold");
  doc.setFontSize(17);
  doc.text("TRICYCLE FRANCHISE CERTIFICATE", center, 57, { align: "center" });

  doc.setFontSize(10);
  doc.setFont("times", "normal");
  doc.text(`Franchise No. ${input.franchiseNumber}`, center, 65, { align: "center" });

  // ---- body ---------------------------------------------------------------
  const bodyStart = 78;
  doc.setFontSize(11);
  const paragraph = doc.splitTextToSize(
    `This certifies that ${input.operatorName.toUpperCase()}, of ${input.operatorAddress}, ` +
      `and a member in good standing of ${input.todaName}, is hereby granted a franchise to ` +
      `operate a tricycle-for-hire unit within the territorial jurisdiction of the Municipality ` +
      `of ${MUNICIPALITY}, ${PROVINCE}, described as follows:`,
    pageWidth - margin * 2,
  );
  doc.text(paragraph, margin, bodyStart, { align: "justify" });

  const tableTop = bodyStart + paragraph.length * 5.4 + 4;

  autoTable(doc, {
    startY: tableTop,
    margin: { left: margin, right: margin },
    theme: "grid",
    styles: { font: "times", fontSize: 10, cellPadding: 2.4, textColor: [22, 18, 19] },
    headStyles: { fillColor: [39, 21, 100], textColor: [255, 255, 255], fontStyle: "bold" },
    head: [["Particulars", "Details", "Particulars", "Details"]],
    body: [
      ["Plate No.", input.plateNumber, "Make / Model", `${input.vehicleMake} ${input.vehicleModel}`],
      ["Year Model", String(input.vehicleYear), "Color", input.vehicleColor],
      ["Engine No.", input.engineNumber, "Chassis No.", input.chassisNumber],
      ["Seating Capacity", String(input.seatingCapacity), "Assoc. / TODA", input.todaName],
    ],
  });

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let cursor = ((doc as any).lastAutoTable?.finalY as number | undefined) ?? tableTop + 30;
  cursor += 8;

  doc.setFont("times", "bold");
  doc.setFontSize(11);
  doc.text(
    `Issued on ${formatLongDate(input.issuedAt)} at ${MUNICIPALITY}, ${PROVINCE}.`,
    margin,
    cursor,
  );

  cursor += 7;
  doc.text(`Valid until ${formatLongDate(input.expiresAt)}.`, margin, cursor);

  cursor += 6;
  doc.setFont("times", "normal");
  doc.setFontSize(10);
  const validityNote = doc.splitTextToSize(
    "This franchise is valid for the period stated above and is subject to existing municipal " +
      "ordinances, national laws and the rules on tricycles-for-hire. It is not transferable " +
      "without the approval of the Sangguniang Bayan.",
    pageWidth - margin * 2,
  );
  doc.text(validityNote, margin, cursor);

  // ---- signature ----------------------------------------------------------
  const signatureY = Math.min(cursor + validityNote.length * 4.6 + 26, 235);
  doc.setFont("times", "bold");
  doc.setFontSize(11);
  doc.text(input.signatoryName, pageWidth - margin, signatureY, { align: "right" });
  doc.setFont("times", "normal");
  doc.setFontSize(10);
  doc.text(input.signatoryPosition, pageWidth - margin, signatureY + 5, { align: "right" });

  // ---- QR code ------------------------------------------------------------
  const verificationUrl = buildVerificationUrl(input.verificationBaseUrl, input.verificationCode);
  const qrDataUrl = await QRCode.toDataURL(verificationUrl, {
    errorCorrectionLevel: "M",
    margin: 1,
    width: 320,
    color: { dark: "#271564", light: "#FFFFFF" },
  });

  const qrSize = 34;
  const qrX = margin;
  const qrY = 232;
  doc.addImage(qrDataUrl, "PNG", qrX, qrY, qrSize, qrSize, undefined, "FAST");

  doc.setFontSize(8.5);
  doc.setFont("helvetica", "bold");
  doc.text("Verify this certificate", qrX + qrSize + 5, qrY + 6);
  doc.setFont("helvetica", "normal");
  doc.setFontSize(8);
  doc.text(`Code: ${input.verificationCode}`, qrX + qrSize + 5, qrY + 11);
  const verifyText = doc.splitTextToSize(
    `Scan the QR code or enter the code at ${input.verificationBaseUrl.replace(/^https?:\/\//, "")}. ` +
      "The code identifies this franchise only; it contains no personal information.",
    pageWidth - margin * 2 - qrSize - 8,
  );
  doc.text(verifyText, qrX + qrSize + 5, qrY + 16);

  // ---- footer -------------------------------------------------------------
  doc.setDrawColor(209, 213, 219);
  doc.setLineWidth(0.3);
  doc.line(margin, 276, pageWidth - margin, 276);
  doc.setFontSize(7.5);
  doc.setTextColor(107, 114, 128);
  const footer = doc.splitTextToSize(input.footerNote, pageWidth - margin * 2);
  doc.text(footer, center, 281, { align: "center" });
  doc.text(
    `Generated by the SBTF System on ${formatLongDate(new Date().toISOString())}. This document is valid without a handwritten signature when verified through the municipal registry.`,
    center,
    288,
    { align: "center", maxWidth: pageWidth - margin * 2 },
  );

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
