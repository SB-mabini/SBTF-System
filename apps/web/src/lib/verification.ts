import type { CertificateVerification } from "@/types/database";
import { SITE_URL, VERIFICATION_BASE_URL } from "@/lib/env";

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

const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "0.0.0.0", "::1", "[::1]"]);

function trimBaseUrl(value: string | null | undefined): string {
  return (value ?? "").trim().replace(/\/+$/, "");
}

/** True for a URL a phone on the same network cannot reach. */
export function isLoopbackBaseUrl(value: string): boolean {
  try {
    const host = new URL(value).hostname.toLowerCase();
    return LOOPBACK_HOSTS.has(host) || host.endsWith(".localhost");
  } catch {
    return false;
  }
}

/**
 * Chooses the base URL that goes into a QR code and the printed certificate.
 *
 * Order of precedence:
 *   1. NEXT_PUBLIC_VERIFICATION_BASE_URL — explicit public address;
 *   2. the administrator's certificate_verification_base_url setting, unless it
 *      is a loopback address (the shipped default is http://localhost:3000/verify);
 *   3. NEXT_PUBLIC_SITE_URL + /verify — the origin this build was deployed to.
 *
 * Step 2's loopback guard is the important one: scanning a certificate with a
 * phone must never open a page served only by the machine that printed it.
 */
export function resolveVerificationBaseUrl(
  configuredBaseUrl?: string | null,
  options: { explicit?: string | null; siteUrl?: string | null; requestOrigin?: string | null } = {},
): string {
  const explicit = trimBaseUrl(options.explicit ?? VERIFICATION_BASE_URL);
  if (explicit) return explicit;

  const configured = trimBaseUrl(configuredBaseUrl);
  if (configured && !isLoopbackBaseUrl(configured)) return configured;

  const site = trimBaseUrl(options.siteUrl ?? SITE_URL);
  if (site && !isLoopbackBaseUrl(site)) return `${site}/verify`;

  // Last resort for a deployment whose NEXT_PUBLIC_SITE_URL was never set: the
  // origin of the request that is rendering this page.
  const origin = trimBaseUrl(options.requestOrigin);
  if (origin && !isLoopbackBaseUrl(origin)) return `${origin}/verify`;

  return configured || `${site}/verify`;
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
