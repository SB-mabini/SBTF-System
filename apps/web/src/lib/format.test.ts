import { describe, expect, it } from "vitest";

import {
  actionLabel,
  applicationStatusLabel,
  applicationTypeLabel,
  documentLabel,
  fileSize,
  formatDate,
  formatDateTime,
  formatDays,
  formatNumber,
  formatPercent,
  humanizeKey,
  initials,
  relativeTime,
  roleLabel,
} from "./format";

describe("number and date formatting", () => {
  it("renders counts with thousands separators and empties as an em dash", () => {
    expect(formatNumber(1234)).toBe("1,234");
    expect(formatNumber(0)).toBe("0");
    expect(formatNumber(null)).toBe("—");
    expect(formatNumber(undefined)).toBe("—");
  });

  it("renders rates to one decimal place and refuses to invent one", () => {
    expect(formatPercent(87.456)).toBe("87.5%");
    expect(formatPercent(0)).toBe("0.0%");
    expect(formatPercent(null)).toBe("—");
    expect(formatPercent(undefined)).toBe("—");
  });

  it("renders day counts, singular and plural, and unknown durations", () => {
    expect(formatDays(0)).toBe("Less than a day");
    expect(formatDays(0.5)).toBe("12 hours");
    expect(formatDays(1)).toBe("1 day");
    expect(formatDays(2.34)).toBe("2.3 days");
    expect(formatDays(null)).toBe("—");
    expect(formatDays(undefined)).toBe("—");
  });

  it("formats dates in Philippine English", () => {
    expect(formatDate("2026-01-05T00:00:00.000Z")).toMatch(/2026/);
    expect(formatDate(null)).toBe("—");
    expect(formatDateTime("2026-01-05T01:30:00.000Z")).toMatch(/2026/);
    expect(formatDateTime(null)).toBe("—");
    expect(formatDate("not-a-date")).toBe("—");
  });

  it("describes recency without overstating it", () => {
    const now = Date.now();
    expect(relativeTime(new Date(now).toISOString())).toBe("just now");
    expect(relativeTime(new Date(now - 5 * 60_000).toISOString())).toBe("5 min ago");
    expect(relativeTime(new Date(now - 3 * 3_600_000).toISOString())).toBe("3 hr ago");
    expect(relativeTime(new Date(now - 3 * 86_400_000).toISOString())).toBe("3 days ago");
    expect(relativeTime(null)).toBe("—");
    expect(relativeTime("not-a-date")).toBe("—");
  });

  it("formats file sizes for the document list", () => {
    expect(fileSize(0)).toBe("—");
    expect(fileSize(512)).toBe("512 B");
    expect(fileSize(2048)).toBe("2 KB");
    expect(fileSize(5 * 1024 * 1024)).toBe("5.0 MB");
    expect(fileSize(null)).toBe("—");
  });
});

describe("labels", () => {
  it("labels roles, statuses, types and documents in the interface language", () => {
    expect(roleLabel("administrator")).toBe("Administrator");
    expect(roleLabel("driver")).toMatch(/Driver/);
    expect(roleLabel(null)).toBe("—");

    expect(applicationStatusLabel("pending")).toBe("Pending");
    expect(applicationTypeLabel("renewal")).toBe("Renewal");
    expect(documentLabel("or_cr")).toMatch(/OR/);
  });

  it("humanises enum values for the audit trail", () => {
    expect(actionLabel("application_approved")).toBe("Approved an application");
    expect(actionLabel("role_change")).toBe("Changed a user role");
    expect(humanizeKey("certificate_storage_path")).toBe("Certificate Storage Path");
  });

  it("builds initials for the avatar in the top bar", () => {
    expect(initials("Juan Dela Cruz")).toBe("JD");
    expect(initials("Maria")).toBe("M");
  });
});
