import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

import {
  VERIFICATION_CODE_ALPHABET,
  VERIFICATION_CODE_LENGTH,
  buildVerificationUrl,
  isWellFormedVerificationCode,
  maskOperatorName,
  normaliseVerificationCode,
  verificationStatusLabel,
} from "./verification";

const MIGRATION = join(
  process.cwd(),
  "..",
  "..",
  "supabase",
  "migrations",
  "20260101090500_phase0_helpers.sql",
);

describe("verification code alphabet", () => {
  it("is exactly 32 unambiguous characters", () => {
    expect(VERIFICATION_CODE_ALPHABET).toHaveLength(32);
    expect(new Set(VERIFICATION_CODE_ALPHABET).size).toBe(32);
    expect(VERIFICATION_CODE_ALPHABET).not.toMatch(/[IO01]/);
  });

  it("matches the alphabet used by public.fn_generate_verification_code()", () => {
    // The database and the web application must agree, otherwise a printed code
    // could be rejected by the verification page.
    const sql = readFileSync(MIGRATION, "utf8");
    const match = sql.match(/v_alphabet text := '([^']+)'/);
    expect(match, "alphabet not found in the helpers migration").not.toBeNull();
    expect(match![1]).toBe(VERIFICATION_CODE_ALPHABET);

    // 256 is an exact multiple of the alphabet length: the byte-to-character
    // mapping is uniform and substr() can address the final character.
    expect(256 % match![1].length).toBe(0);
    expect(match![1]![match![1]!.length - 1]).toBe(VERIFICATION_CODE_ALPHABET.slice(-1));
  });
});

describe("normaliseVerificationCode", () => {
  it("upper-cases, strips separators and drops confusable characters", () => {
    expect(normaliseVerificationCode(" abcd-efgh jkmn ")).toBe("ABCDEFGHJKMN");
    expect(normaliseVerificationCode("IO01")).toBe("");
  });

  it("keeps every alphabet character", () => {
    expect(normaliseVerificationCode(VERIFICATION_CODE_ALPHABET)).toBe(VERIFICATION_CODE_ALPHABET);
  });
});

describe("isWellFormedVerificationCode", () => {
  it("accepts only a full-length code from the alphabet", () => {
    expect(isWellFormedVerificationCode("ABCDEFGHJKMN")).toBe(true);
    expect(isWellFormedVerificationCode("ABCDEFGHJKM")).toBe(false);
    expect(isWellFormedVerificationCode("ABCDEFGHJKMN2")).toBe(false);
    expect(isWellFormedVerificationCode("ABCDEFGHJKM0")).toBe(false);
    expect(isWellFormedVerificationCode("abcdefghjkmn")).toBe(false);
    expect(VERIFICATION_CODE_LENGTH).toBe(12);
  });
});

describe("buildVerificationUrl", () => {
  it("contains the code and nothing else", () => {
    const url = buildVerificationUrl("https://example.gov.ph/verify", "ABCDEFGHJKMN");
    expect(url).toBe("https://example.gov.ph/verify?code=ABCDEFGHJKMN");
    expect(url).not.toMatch(/name|plate|address|contact|phone/i);
  });

  it("tolerates a trailing slash and already-centred codes", () => {
    expect(buildVerificationUrl("https://example.gov.ph/verify/", "abcdefghjkmn")).toBe(
      "https://example.gov.ph/verify?code=ABCDEFGHJKMN",
    );
  });
});

describe("maskOperatorName", () => {
  it("returns an initial and a last initial only", () => {
    expect(maskOperatorName("Juan Dela Cruz")).toBe("J*** C.");
    expect(maskOperatorName("Maria")).toBe("M***");
    expect(maskOperatorName(null)).toBeNull();
    expect(maskOperatorName("   ")).toBeNull();
  });
});

describe("verificationStatusLabel", () => {
  it("maps every database status to a human label", () => {
    expect(verificationStatusLabel("valid")).toBe("Valid franchise");
    expect(verificationStatusLabel("expired")).toBe("Expired franchise");
    expect(verificationStatusLabel("archived")).toBe("Archived franchise");
    expect(verificationStatusLabel("not_found")).toBe("Not found");
  });
});
