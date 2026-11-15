import { describe, expect, it } from "vitest";

import {
  buildFormRequestLetterPdf,
  type FormRequestLetterInput,
} from "./form-request-letter";

// A real 4x4 PNG: jsPDF decodes the image it is handed, so the mock must return
// a valid file rather than a placeholder string.
const PNG_1X1 =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAAAAACMmsGiAAAAC0lEQVR4nGNgwAQAABQAAX3+Hu4AAAAASUVORK5CYII=";

const BASE: FormRequestLetterInput = {
  formNumber: "FR-2026-000012",
  applicationType: "New",
  applicantName: "Juan Dela Cruz",
  contactNumber: "09171234567",
  address: "Barangay San Jose, Mabini, Batangas",
  todaName: "San Jose TODA",
  ctcNumber: "12345678",
  vehicleMake: "Honda",
  vehicleModel: "TMX 125",
  engineNumber: "ENG123456",
  chassisNumber: "CHS123456",
  plateNumber: "AB 12345",
  crNumber: "CR-998877",
  requestedAt: "2026-11-15T10:00:00Z",
  addressee: "Hon. Presiding Officer and Hon. Members of the Sangguniang Bayan",
  municipality: "Municipality of Mabini",
  location: "Mabini, Batangas",
  body: "I am applying for the approval of my application for franchise.",
};

describe("buildFormRequestLetterPdf", () => {
  it("prints the applicant block on the signature side", () => {
    const doc = buildFormRequestLetterPdf({ ...BASE, signatureDataUrl: PNG_1X1 });

    expect(doc.getNumberOfPages()).toBe(1);
    expect(doc.output()).toContain("JUAN DELA CRUZ");
  });

  it("prints a typed signature on the signature line", () => {
    const doc = buildFormRequestLetterPdf({
      ...BASE,
      signatureName: "Juana Santos",
    });

    expect(doc.output()).toContain("Juana Santos");
  });

  it("moves the closing and signature block to a new page instead of over the footer", () => {
    // A long body pushes the table and closing down the page. Without the
    // page-break guard the signature printed on top of the footer.
    const doc = buildFormRequestLetterPdf({
      ...BASE,
      body: Array.from({ length: 40 }, () => "Additional statement of the applicant.").join(" "),
      signatureName: "Juana Santos",
    });

    expect(doc.getNumberOfPages()).toBeGreaterThan(1);
    expect(doc.output()).toContain("Juana Santos");
  });
});
