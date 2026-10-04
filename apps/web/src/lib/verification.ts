import type { CertificateVerification } from "@/types/database";

/**
 * Certificate verification helpers.
 *
 * The alphabet mirrors public.fn_generate_verification_code() in the database
 * exactly: 32 characters, excluding I, O, 0 and 1 so that a person reading a
 * printed certificate cannot confuse two symbols.
 */
export const VERIFICATION_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const VERIFICATION_CODE_LENGTH = 12;

const CODE_PATTERN = new RegExp(`^[${VERIFICATION_CODE_ALPHABET}]{${VERIFICATION_CODE_LENGTH}}$`);

/**
 * Normalises user input: upper case, and every character that is not part of
 * the alphabet removed (spaces, dashes and the confusable I/O/0/1).
 */
export function normaliseVerificationCode(input: string): string {
  const upper = input.trim().toUpperCase();
  let result = "";
  for (const character of upper) {
    if (VERIFICATION_CODE_ALPHABET.includes(character)) result += character;
  }
  return result;
}

export function isWellFormedVerificationCode(code: string): boolean {
  return CODE_PATTERN.test(code);
}

/**
 * The complete QR payload. It contains the public verification address and the
 * opaque code — never a name, address, contact number, plate number or any
 * other personal data.
 */
export function buildVerificationUrl(baseUrl: string, code: string): string {
  const normalised = normaliseVerificationCode(code);
  const base = baseUrl.trim().replace(/\/+$/, "");
  return `${base}?code=${normalised}`;
}

/** Masked operator name exactly as the public verification function returns it. */
export function maskOperatorName(fullName: string | null | undefined): string | null {
  if (!fullName) return null;
  const first = fullName.trim().charAt(0);
  if (!first) return null;
  const parts = fullName.trim().split(/\s+/);
  const lastInitial = parts.length > 1 ? `${parts[parts.length - 1]!.charAt(0)}.` : "";
  return `${first}*** ${lastInitial}`.trim();
}

export function verificationStatusLabel(status: CertificateVerification["verification_status"]): string {
  switch (status) {
    case "valid":
      return "Valid franchise";
    case "expired":
      return "Expired franchise";
    case "archived":
      return "Archived franchise";
    default:
      return "Not found";
  }
}

export function verificationStatusTone(
  status: CertificateVerification["verification_status"],
): "success" | "warning" | "neutral" | "danger" {
  switch (status) {
    case "valid":
      return "success";
    case "expired":
      return "warning";
    case "archived":
      return "neutral";
    default:
      return "danger";
  }
}
