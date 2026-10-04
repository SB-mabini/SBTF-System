import { beforeEach, describe, expect, it, vi } from "vitest";

// A real 4x4 PNG: jsPDF decodes the image it is handed, so the mock must return
// a valid file rather than a placeholder string.
const PNG_1X1 =
  "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAAAAACMmsGiAAAAC0lEQVR4nGNgwAQAABQAAX3+Hu4AAAAASUVORK5CYII=";

const toDataUrl = vi.fn<(text: string, options?: unknown) => Promise<string>>(async () => PNG_1X1);

vi.mock("qrcode", () => ({
  default: {
    toDataURL: (text: string, options?: unknown) => toDataUrl(text, options),
    toString: () => "",
  },
}));

import { buildCertificatePdf, certificateStoragePath } from "./certificate";
import { VERIFICATION_CODE_ALPHABET } from "./verification";

const CODE = "ABCDEFGHJKMN";

const INPUT = {
  franchiseNumber: "MAB-TR-2026-000001",
  verificationCode: CODE,
  operatorName: "Juan Dela Cruz",
  operatorAddress: "Barangay Poblacion, Mabini, Batangas",
  todaName: "TODA Poblacion",
  plateNumber: "ABC 1234",
  vehicleMake: "Honda",
  vehicleModel: "TMX 125",
  vehicleYear: 2024,
  vehicleColor: "Blue",
  engineNumber: "ENG-0001",
  chassisNumber: "CHS-0001",
  seatingCapacity: 5,
  issuedAt: "2026-01-05T00:00:00.000Z",
  expiresAt: "2027-01-04T00:00:00.000Z",
  signatoryName: "Hon. Mayor",
  signatoryPosition: "Municipal Mayor",
  officeName: "Sangguniang Bayan ng Mabini — Committee on Transportation",
  footerNote: "Verifiable through the QR code printed on this certificate.",
  verificationBaseUrl: "https://sbtf-mabini.example.gov.ph/verify",
};

describe("certificate QR payload", () => {
  beforeEach(() => toDataUrl.mockClear());

  it("encodes the verification URL and no personal data", async () => {
    await buildCertificatePdf(INPUT);

    expect(toDataUrl).toHaveBeenCalledTimes(1);
    const payload = toDataUrl.mock.calls[0]![0];

    expect(payload).toBe(`https://sbtf-mabini.example.gov.ph/verify?code=${CODE}`);
    // The whole point of the QR code: it must not leak the holder's details.
    for (const sensitive of ["Juan", "Dela", "ABC 1234", "ENG-0001", "CHS-0001", "Poblacion"]) {
      expect(payload).not.toContain(sensitive);
    }
  });

  it("uses only characters from the database alphabet", () => {
    for (const character of CODE) {
      expect(VERIFICATION_CODE_ALPHABET).toContain(character);
    }
  });
});

describe("buildCertificatePdf", () => {
  it("produces a printable A4 PDF", async () => {
    const doc = await buildCertificatePdf(INPUT);
    const output = doc.output("arraybuffer") as ArrayBuffer;

    expect(output.byteLength).toBeGreaterThan(1000);

    const head = new TextDecoder().decode(new Uint8Array(output).slice(0, 5));
    expect(head).toBe("%PDF-");
  });

  it("keeps the certificate to a single page", async () => {
    const doc = await buildCertificatePdf(INPUT);
    expect(doc.getNumberOfPages()).toBe(1);
  });
});

describe("certificateStoragePath", () => {
  it("follows the {profile_id}/{franchise_number}.pdf convention of the storage policy", () => {
    expect(certificateStoragePath("11111111-2222-3333-4444-555555555555", "MAB-TR-2026-000001")).toBe(
      "11111111-2222-3333-4444-555555555555/MAB-TR-2026-000001.pdf",
    );
  });
});
