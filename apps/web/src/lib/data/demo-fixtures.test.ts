import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

import { demoApplications, demoBarangays, demoOverview, demoRecords, demoTodas } from "./demo-fixtures";

const REPO_ROOT = join(process.cwd(), "..", "..");

function read(relativePath: string): string {
  return readFileSync(join(REPO_ROOT, relativePath), "utf8");
}

/**
 * The preview dataset is meant to mirror the anonymised development dataset
 * produced by scripts/generate_seed.py. These checks keep the two in step, so a
 * reviewer looking at the deployed demonstration sees the same municipality that
 * the seed creates.
 */
describe("preview barangays", () => {
  it("lists the 34 barangays of Mabini with PSA codes", () => {
    expect(demoBarangays).toHaveLength(34);
    expect(new Set(demoBarangays.map((barangay) => barangay.name)).size).toBe(34);
    expect(new Set(demoBarangays.map((barangay) => barangay.code)).size).toBe(34);
    for (const barangay of demoBarangays) {
      expect(barangay.code).toMatch(/^041016\d{3}$/);
    }
  });

  it("matches the names and codes loaded by the reference-data migration", () => {
    const sql = read("supabase/migrations/20260101090100_phase0_reference_data.sql");
    const pairs = Array.from(
      sql.matchAll(/\(\s*'(\d{9})',\s*'([^']+)',\s*\d+\s*\)/g),
    ).map((match) => ({ code: match[1]!, name: match[2]! }));

    // Barangays are the first insert in that migration.
    const barangayPairs = pairs.slice(0, 34);

    expect(barangayPairs.map((pair) => pair.name)).toEqual(
      demoBarangays.map((barangay) => barangay.name),
    );
    expect(barangayPairs.map((pair) => pair.code)).toEqual(
      demoBarangays.map((barangay) => barangay.code),
    );
  });
});

describe("preview TODAs", () => {
  it("mirrors the 24 associations and the 817-member masterlist of the seed generator", () => {
    const generator = read("scripts/generate_seed.py");
    const block = generator.match(/TODAS: list\[tuple\[str, str, str, int\]\] = \[([\s\S]*?)\n\]/)?.[1];
    expect(block, "TODAS list not found in the generator").toBeDefined();

    const seeded = Array.from(
      block!.matchAll(/\("(TODA-\d{3})", "([^"]+)", "(\d{9})", (\d+)\)/g),
    ).map((match) => ({
      code: match[1]!,
      name: match[2]!,
      barangayCode: match[3]!,
      members: Number(match[4]),
    }));

    expect(seeded).toHaveLength(24);
    expect(seeded.reduce((sum, toda) => sum + toda.members, 0)).toBe(817);

    // The preview uses the same names and member counts, in the same order.
    expect(demoTodas.map((toda) => toda.name)).toEqual(seeded.map((toda) => toda.name));
    expect(demoTodas.map((toda) => toda.members_count)).toEqual(seeded.map((toda) => toda.members));
  });

  it("links every association to a real barangay", () => {
    const codes = new Set(demoBarangays.map((barangay) => barangay.code));
    for (const toda of demoTodas) {
      expect(toda.barangay_code).not.toBeNull();
      expect(codes.has(toda.barangay_code!)).toBe(true);
    }
  });
});

describe("preview applications and records", () => {
  it("keeps the statuses and totals internally consistent", () => {
    const pending = demoApplications.filter((application) => application.status === "pending").length;
    const approved = demoApplications.filter((application) => application.status === "approved").length;
    const rejected = demoApplications.filter((application) => application.status === "rejected").length;

    expect(pending + approved + rejected).toBe(demoApplications.length);
    expect(demoOverview.total_applications).toBe(demoApplications.length);
    expect(demoOverview.pending_applications).toBe(pending);
    expect(demoOverview.approved_applications).toBe(approved);
    expect(demoOverview.rejected_applications).toBe(rejected);
  });

  it("issues one franchise record per approved application", () => {
    const approved = demoApplications.filter((application) => application.status === "approved");
    expect(demoRecords).toHaveLength(approved.length);

    const codes = new Set(demoRecords.map((record) => record.verification_code));
    expect(codes.size).toBe(demoRecords.length);

    for (const record of demoRecords) {
      // 12 characters from the unambiguous database alphabet.
      expect(record.verification_code).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12}$/);
      expect(new Date(record.expires_at).getTime()).toBeGreaterThan(
        new Date(record.issued_at).getTime(),
      );
    }
  });

  it("never places personal data in the verification code", () => {
    for (const record of demoRecords) {
      expect(record.verification_code).not.toContain(record.franchise_number.slice(0, 4));
      expect(record.verification_code).toMatch(/^[A-Z2-9]+$/);
    }
  });
});
