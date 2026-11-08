import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";

/**
 * The printable vehicle/franchise request letter.
 *
 * The letterhead (addressee, municipality, location and opening sentence) is
 * administrator-configurable through the `forms` settings category. The letter
 * carries the vehicle identity and the CTC number captured by the driver, which
 * the application reuses after staff approve the request.
 */
export interface FormRequestLetterInput {
  formNumber: string;
  applicationType: string;
  applicantName: string;
  contactNumber: string | null;
  address: string;
  todaName: string;
  ctcNumber: string | null;
  vehicleMake: string | null;
  vehicleModel: string | null;
  engineNumber: string | null;
  chassisNumber: string | null;
  plateNumber: string | null;
  crNumber: string | null;
  requestedAt: string;
  addressee: string;
  municipality: string;
  location: string;
  body: string;
  /** Optional data URL of the drawn signature PNG. */
  signatureDataUrl?: string | null;
  signatureName?: string | null;
}

export const FORM_REQUEST_LETTER_DEFAULTS = {
  addressee: "Hon. Presiding Officer and Hon. Members of the Sangguniang Bayan",
  municipality: "Municipality of Mabini",
  location: "Mabini, Batangas",
  body:
    "I am applying for the approval of my application for franchise of that tricycle, more particularly described as follows:",
};

export function buildFormRequestLetterPdf(input: FormRequestLetterInput): jsPDF {
  const doc = new jsPDF({ unit: "mm", format: "a4" });
  const pageWidth = doc.internal.pageSize.getWidth();
  const margin = 20;
  const center = pageWidth / 2;
  const contentWidth = pageWidth - margin * 2;

  // ---- letterhead ---------------------------------------------------------
  doc.setFont("times", "normal");
  doc.setFontSize(11);
  doc.text("Republic of the Philippines", center, 20, { align: "center" });
  doc.setFontSize(13);
  doc.setFont("times", "bold");
  doc.text(input.municipality.toUpperCase(), center, 27, { align: "center" });
  doc.setFontSize(11);
  doc.setFont("times", "normal");
  doc.text(input.location, center, 33, { align: "center" });
  doc.setFontSize(10);
  doc.text("OFFICE OF THE SANGGUNIANG BAYAN", center, 39, { align: "center" });

  doc.setDrawColor(39, 21, 100);
  doc.setLineWidth(0.7);
  doc.line(margin, 44, pageWidth - margin, 44);

  // ---- addressee and date -------------------------------------------------
  doc.setFontSize(11);
  doc.text(input.addressee, margin, 56);
  doc.text(input.municipality, margin, 62);
  doc.text(input.location, margin, 68);

  doc.text(formatLongDate(input.requestedAt), pageWidth - margin, 56, { align: "right" });

  // ---- title --------------------------------------------------------------
  doc.setFont("times", "bold");
  doc.setFontSize(14);
  doc.text("REQUEST FOR APPROVAL OF FRANCHISE", center, 82, { align: "center" });
  doc.setFontSize(10);
  doc.setFont("times", "normal");
  doc.text(`Request No. ${input.formNumber}`, center, 88, { align: "center" });

  // ---- salutation and body ------------------------------------------------
  doc.setFontSize(11);
  doc.text("Dear Sir/Madam:", margin, 99);

  let cursor = 108;
  const paragraph = doc.splitTextToSize(input.body, contentWidth);
  doc.text(paragraph, margin, cursor, { align: "justify", maxWidth: contentWidth });
  cursor += paragraph.length * 5.6 + 3;

  autoTable(doc, {
    startY: cursor,
    margin: { left: margin, right: margin },
    theme: "grid",
    styles: { font: "times", fontSize: 10, cellPadding: 2.4, textColor: [22, 18, 19] },
    headStyles: { fillColor: [39, 21, 100], textColor: [255, 255, 255], fontStyle: "bold" },
    head: [["Particulars", "Details", "Particulars", "Details"]],
    body: [
      ["Plate No.", input.plateNumber ?? "", "Make / Model", `${input.vehicleMake ?? ""} ${input.vehicleModel ?? ""}`.trim()],
      ["Engine No.", input.engineNumber ?? "", "Chassis No.", input.chassisNumber ?? ""],
      ["CR No.", input.crNumber ?? "", "CTC / Cedula No.", input.ctcNumber ?? ""],
      ["Association / TODA", input.todaName, "Application type", input.applicationType],
    ],
  });

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  cursor = ((doc as any).lastAutoTable?.finalY as number | undefined) ?? cursor + 40;
  cursor += 8;

  doc.setFont("times", "normal");
  const closing = doc.splitTextToSize(
    "I am executing this request in good faith and certify that the information and documents " +
      "submitted are true and correct.",
    contentWidth,
  );
  doc.text(closing, margin, cursor, { align: "justify", maxWidth: contentWidth });
  cursor += closing.length * 5.6 + 12;

  doc.text("Respectfully yours,", margin, cursor);
  cursor += 18;

  // ---- signature ----------------------------------------------------------
  if (input.signatureDataUrl) {
    try {
      doc.addImage(input.signatureDataUrl, "PNG", margin, cursor - 14, 55, 18, undefined, "FAST");
    } catch {
      // A corrupt image must not stop the letter from being printed.
    }
  }

  doc.setFont("times", "bold");
  doc.text(input.applicantName.toUpperCase(), margin, cursor + 8);
  doc.setFont("times", "normal");
  doc.setFontSize(10);
  doc.text("Applicant / Operator", margin, cursor + 13);
  if (input.contactNumber) doc.text(input.contactNumber, margin, cursor + 18);
  if (input.address) doc.text(input.address, margin, cursor + 23);

  // ---- footer -------------------------------------------------------------
  doc.setDrawColor(209, 213, 219);
  doc.setLineWidth(0.3);
  doc.line(margin, 276, pageWidth - margin, 276);
  doc.setFontSize(7.5);
  doc.setTextColor(107, 114, 128);
  doc.text(
    `Generated by the ${input.municipality} franchising system on ${formatLongDate(new Date().toISOString())}.`,
    center,
    281,
    { align: "center" },
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
