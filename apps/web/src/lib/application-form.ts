import jsPDF from "jspdf";

import { MUNICIPALITY, PROVINCE } from "@/lib/constants";

export interface ApplicationFormInput {
  applicationNumber: string;
  familyName: string;
  givenName: string;
  middleName?: string | null;
  citizenship?: string | null;
  address: string;
  appliedRoute?: string | null;
  make: string;
  model: string;
  motorNumber: string;
  chassisNumber: string;
  plateNumber: string;
  registeredOwner?: string | null;
  ownershipType?: string | null;
  ctcNumber?: string | null;
  ctcIssuedAt?: string | null;
  ctcIssuedOn?: string | null;
  applicantName: string;
  signatureDataUrl?: string | null;
  printedAt?: string | null;
}

const OWNERSHIP_LABELS: Record<string, string> = {
  single_proprietorship: "Single Proprietorship",
  cooperative: "Cooperative",
  corporation: "Corporation",
  not_applicable: "N/A",
};

/**
 * Official "Application for Franchise Tricycle Service" (Image 1) as a PDF.
 * Staff print this at intake; the same layout is shown in the mobile review.
 */
export function buildApplicationFormPdf(input: ApplicationFormInput): jsPDF {
  const doc = new jsPDF({ unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 18;
  const center = pageWidth / 2;
  const contentWidth = pageWidth - margin * 2;
  let cursor = 18;

  doc.setFont("times", "normal");
  doc.setFontSize(10);
  doc.text("Republic of the Philippines", center, cursor, { align: "center" });
  cursor += 5;
  doc.text(`Province of ${PROVINCE}`, center, cursor, { align: "center" });
  cursor += 5;
  doc.text(MUNICIPALITY, center, cursor, { align: "center" });
  cursor += 5;
  doc.setFont("times", "bold");
  doc.text("OFFICE OF THE SANGGUNIANG BAYAN", center, cursor, { align: "center" });

  cursor += 12;
  doc.setFontSize(15);
  doc.text("APPLICATION FOR FRANCHISE", center, cursor, { align: "center" });
  cursor += 6;
  doc.text("TRICYCLE SERVICE", center, cursor, { align: "center" });

  cursor += 12;
  doc.setFont("times", "normal");
  doc.setFontSize(10);

  const field = (label: string, value: string | null | undefined) => {
    doc.setFont("times", "bold");
    doc.text(`${label}:`, margin, cursor);
    doc.setFont("times", "normal");
    const lines = doc.splitTextToSize(value?.trim() || "—", contentWidth - 52);
    doc.text(lines, margin + 50, cursor);
    doc.setDrawColor(120, 120, 120);
    doc.setLineWidth(0.2);
    doc.line(margin + 50, cursor + 1.5, pageWidth - margin, cursor + 1.5);
    cursor += Math.max(7, lines.length * 4.6 + 2);
  };

  field("Family Name", input.familyName);
  field(
    "Given Name",
    [input.givenName, input.middleName].filter(Boolean).join(" "),
  );
  field("Citizenship", input.citizenship ?? "Filipino");
  field("Address", input.address);
  field("Applied Route / Service Area", input.appliedRoute);
  field("Number of Units Applied For", "ONE (1)");

  cursor += 3;
  doc.setFont("times", "bold");
  doc.text("MOTORCYCLE / TRICYCLE PARTICULARS", margin, cursor);
  cursor += 8;
  field("Make", input.make);
  field("Model", input.model);
  field("Motor No.", input.motorNumber);
  field("Chassis No.", input.chassisNumber);
  field("Plate No.", input.plateNumber);
  field("Registered Owner", input.registeredOwner || input.applicantName);
  field("Type of Ownership", OWNERSHIP_LABELS[input.ownershipType ?? ""] ?? "N/A");

  cursor += 4;
  doc.setFont("times", "normal");
  doc.setFontSize(9.5);
  const certification = doc.splitTextToSize(
    "I hereby certify that the above information are true and correct and that I am " +
      "applying for a franchise to operate the above-described tricycle for public service.",
    contentWidth,
  );
  doc.text(certification, margin, cursor, { align: "justify", maxWidth: contentWidth });
  cursor += certification.length * 4.4 + 8;

  doc.text(`${MUNICIPALITY === "Municipality of Mabini" ? "Mabini" : MUNICIPALITY}, ${PROVINCE}`, margin, cursor);
  cursor += 8;
  doc.setFontSize(9.5);
  doc.text(`CTC No.: ${input.ctcNumber || "—"}`, margin, cursor);
  cursor += 5;
  doc.text(`Issued at: ${input.ctcIssuedAt || `${MUNICIPALITY}, ${PROVINCE}`}`, margin, cursor);
  cursor += 5;
  doc.text(`Issued on: ${input.ctcIssuedOn || input.printedAt || "—"}`, margin, cursor);

  // Signature block (right side)
  const signatureY = cursor + 16;
  const signatureWidth = 65;
  const signatureX = pageWidth - margin - signatureWidth;

  if (input.signatureDataUrl) {
    try {
      doc.addImage(input.signatureDataUrl, "PNG", signatureX, signatureY - 14, 45, 13, undefined, "FAST");
    } catch {
      // A corrupt signature must never block the form.
    }
  }

  doc.setDrawColor(60, 60, 60);
  doc.setLineWidth(0.3);
  doc.line(signatureX, signatureY, pageWidth - margin, signatureY);
  doc.setFont("times", "bold");
  doc.setFontSize(9.5);
  doc.text(input.applicantName.toUpperCase(), signatureX + signatureWidth / 2, signatureY + 5, {
    align: "center",
  });
  doc.setFont("times", "normal");
  doc.setFontSize(8.5);
  doc.text("Applicant", signatureX + signatureWidth / 2, signatureY + 9.5, { align: "center" });

  doc.setFontSize(8);
  doc.setTextColor(110, 110, 110);
  doc.text(`Application No.: ${input.applicationNumber}`, margin, 285);

  return doc;
}
