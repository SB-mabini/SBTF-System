#!/usr/bin/env node
/**
 * Self-test for scripts/verify-live.mjs — `npm run test:verify`.
 *
 * The verifier is the thing that catches a schema drifted from the TypeScript
 * interfaces, so it needs a test that does not itself depend on a database.
 * This harness runs the real verifier against scripts/tests/mock-supabase.mjs
 * twice:
 *
 *   1. a healthy project  → every check passes, exit code 0;
 *   2. the same project with one analytics column renamed → the verifier fails,
 *      exits 1, and names both the RPC and the missing field.
 *
 * 10 assertions. No network, no database, no Supabase CLI.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { runVerify, parseInterfaces, ANALYTICS_CHECKS } from "./verify-live.mjs";
import { createMockFetch, MOCK_KEY, MOCK_URL } from "./tests/mock-supabase.mjs";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const TYPES_PATH = join(ROOT, "apps", "web", "src", "types", "database.ts");

const RENAMED_FIELD = "total_applications";
const RENAMED_RPC = "rpc_analytics_overview";

let passed = 0;
const failed = [];

async function check(label, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${label}`);
  } catch (error) {
    failed.push(label);
    console.error(`  ✗ ${label}\n      ${error.message.split("\n").join("\n      ")}`);
  }
}

const find = (checks, name) => checks.find((check) => check.name === name);

console.log("SBTF verifier self-test (mock Supabase, no database)\n");

const healthy = await runVerify({
  url: MOCK_URL,
  key: MOCK_KEY,
  fetchImpl: createMockFetch(),
  typesPath: TYPES_PATH,
});

const renamed = await runVerify({
  url: MOCK_URL,
  key: MOCK_KEY,
  fetchImpl: createMockFetch({ mode: "renamed" }),
  typesPath: TYPES_PATH,
});

const healthySummary = healthy.checks
  .map((check) => `${check.name}=${check.status}`)
  .join(", ");

await check("1. a healthy project produces no failures", () => {
  assert.equal(healthy.failures.length, 0, `failures: ${healthySummary}`);
});

await check("2. all 8 analytics RPC field-sets pass against the interfaces", () => {
  for (const { rpc } of ANALYTICS_CHECKS) {
    const found = find(healthy.checks, rpc);
    assert.ok(found, `${rpc} was never checked`);
    assert.equal(found.status, "pass", `${rpc}: ${found.detail}`);
  }
});

await check("3. the certificate round-trip verifies a real code with a masked name", () => {
  const found = find(healthy.checks, "certificate round-trip");
  assert.ok(found, "the certificate round-trip was never checked");
  assert.equal(found.status, "pass", found.detail);
  assert.match(found.detail, /ABCD-EFGH-JKMP/);
  assert.match(found.detail, /masked/);
});

await check("4. both private storage buckets refuse anonymous downloads", () => {
  for (const bucket of ["franchise-documents", "certificates"]) {
    const found = find(healthy.checks, `storage: ${bucket}`);
    assert.ok(found, `${bucket} was never probed`);
    assert.equal(found.status, "pass", `${bucket}: ${found.detail}`);
  }
});

await check("5. a healthy project exits 0", () => {
  assert.equal(healthy.exitCode, 0);
});

await check("6. a renamed analytics column is reported as a failure", () => {
  assert.ok(renamed.failures.length > 0, "the renamed column was not detected");
});

await check(`7. the failure names the missing field (${RENAMED_FIELD})`, () => {
  const detail = renamed.failures.map((failure) => failure.detail).join(" | ");
  assert.ok(
    detail.includes(RENAMED_FIELD),
    `expected "${RENAMED_FIELD}" in the failure output, got: ${detail}`,
  );
});

await check(`8. the failure names the RPC (${RENAMED_RPC})`, () => {
  const names = renamed.failures.map((failure) => failure.name);
  assert.ok(names.includes(RENAMED_RPC), `expected ${RENAMED_RPC} among ${names.join(", ")}`);
});

await check("9. a drifted schema exits 1", () => {
  assert.equal(renamed.exitCode, 1);
});

await check("10. the interface parser reads AnalyticsOverview from database.ts", () => {
  const interfaces = parseInterfaces(readFileSync(TYPES_PATH, "utf8"));
  const fields = interfaces.get("AnalyticsOverview");
  assert.ok(fields, "AnalyticsOverview not found");
  assert.ok(fields.has("total_applications"), "total_applications not parsed");
  assert.ok(fields.has("unread_notifications"), "unread_notifications not parsed");
  assert.equal(fields.has("auth_user_id"), false, "fields from other interfaces leaked in");
  assert.equal(fields.size, 25, `expected 25 fields, parsed ${fields.size}`);
});

console.log("");
if (failed.length > 0) {
  console.log(`${passed} of ${passed + failed.length} assertions passed, ${failed.length} failed.\n`);
  process.exit(1);
}
console.log(`${passed} assertions passed.\n`);
process.exit(0);
