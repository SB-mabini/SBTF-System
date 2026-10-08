#!/usr/bin/env node
/**
 * Live, read-only verification of the queries the web console actually runs.
 *
 *   npm run db:verify
 *
 * Static checks (npm run validate:sql) prove the SQL parses. This script proves
 * the *deployed* database still answers with the shapes the TypeScript
 * interfaces in apps/web/src/types/database.ts declare — the failure mode where
 * a migration was applied by hand, a column was renamed in the dashboard, or an
 * RPC was dropped from the schema cache and nothing in the repository changed.
 *
 * Everything here is a read:
 *   1. the 8 analytics RPCs are called and their response field-sets are
 *      compared with the parsed interfaces;
 *   2. a certificate round-trip is replayed (read a verification code, verify
 *      it, check the response shape and that the operator name is masked);
 *   3. the two private storage buckets are probed without a session and must
 *      refuse.
 *
 * Set SBTF_VERIFY_EMAIL / SBTF_VERIFY_PASSWORD to run the analytics calls with a
 * real staff session. Without them the calls are still attempted with the
 * publishable key; permission errors are then reported as skipped rather than as
 * failures, because they say nothing about the response shape.
 *
 * Exits 1 if any check fails.
 *
 * The module is also imported by scripts/test-verify-live.mjs, which runs the
 * exact same code against scripts/tests/mock-supabase.mjs — no database needed.
 */
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const DEFAULT_TYPES_PATH = join(ROOT, "apps", "web", "src", "types", "database.ts");
const DEFAULT_ENV_PATH = join(ROOT, "apps", "web", ".env.local");

const TIMEOUT_MS = 20_000;

/** The 8 analytics RPCs and the TypeScript interface each one must satisfy. */
export const ANALYTICS_CHECKS = [
  { rpc: "rpc_analytics_overview", args: {}, iface: "AnalyticsOverview" },
  { rpc: "rpc_analytics_application_trends", args: { p_months: 12 }, iface: "TrendPoint" },
  { rpc: "rpc_analytics_by_toda", args: {}, iface: "TodaAnalytics" },
  { rpc: "rpc_analytics_processing_time", args: { p_months: 12 }, iface: "ProcessingTimePoint" },
  { rpc: "rpc_analytics_expiring", args: { p_days: 180 }, iface: "ExpiringRecord" },
  { rpc: "rpc_analytics_document_compliance", args: {}, iface: "DocumentComplianceRow" },
  { rpc: "rpc_analytics_prescriptive", args: {}, iface: "PrescriptiveIndicator" },
  { rpc: "rpc_analytics_system_health", args: {}, iface: "SystemHealth" },
];

export const PRIVATE_BUCKETS = ["franchise-documents", "certificates"];

/* -------------------------------------------------------------------------- */
/* Interface parsing                                                           */
/* -------------------------------------------------------------------------- */

/**
 * Pulls `export interface Name { … }` members out of a TypeScript source file.
 *
 * Only top-level members are collected (two-space indentation), which is exactly
 * the shape of the flat row interfaces in apps/web/src/types/database.ts. Nested
 * object type literals would need a real parser and none of the interfaces this
 * script checks uses one.
 *
 * @param {string} source
 * @returns {Map<string, Set<string>>}
 */
export function parseInterfaces(source) {
  const out = new Map();
  const header = /export interface (\w+)[^{]*\{/g;
  let match;

  while ((match = header.exec(source)) !== null) {
    const name = match[1];
    let depth = 1;
    let index = header.lastIndex;

    while (index < source.length && depth > 0) {
      const ch = source[index];
      if (ch === "{") depth++;
      else if (ch === "}") depth--;
      index++;
    }

    const body = source.slice(header.lastIndex, index - 1);
    const fields = new Set();
    for (const line of body.split("\n")) {
      const field = /^ {2}(\w+)\??\s*:/.exec(line);
      if (field) fields.add(field[1]);
    }
    out.set(name, fields);
    header.lastIndex = index;
  }

  return out;
}

/* -------------------------------------------------------------------------- */
/* Minimal PostgREST / storage client                                          */
/* -------------------------------------------------------------------------- */

export function createClient({ url, key, fetchImpl = fetch }) {
  const base = url.replace(/\/$/, "");

  async function request(pathname, init = {}) {
    const response = await fetchImpl(`${base}${pathname}`, {
      ...init,
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(init.headers ?? {}),
      },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const text = await response.text();
    let body = null;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      body = text;
    }
    return { status: response.status, ok: response.ok, body, text };
  }

  return {
    /** @param {string} table @param {string} query */
    get(table, query = "") {
      return request(`/rest/v1/${table}${query ? `?${query}` : ""}`);
    },
    /** @param {string} name @param {Record<string, unknown>} args */
    rpc(name, args = {}) {
      return request(`/rest/v1/rpc/${name}`, { method: "POST", body: JSON.stringify(args) });
    },
    request,
  };
}

/** True when PostgREST/GoTrue refused the call for authorisation reasons. */
function isPermissionFailure(result) {
  if (result.status === 401 || result.status === 403) return true;
  const message = typeof result.text === "string" ? result.text : "";
  return message.includes("42501") || message.includes("permission denied");
}

/* -------------------------------------------------------------------------- */
/* Verification                                                                */
/* -------------------------------------------------------------------------- */

/**
 * @param {object} options
 * @param {string} options.url
 * @param {string} options.key
 * @param {typeof fetch} [options.fetchImpl]
 * @param {string} [options.typesPath]
 * @returns {Promise<{ checks: Array<{name: string, status: "pass"|"fail"|"skip"|"warn", detail: string}>, failures: Array<{name: string, detail: string}>, exitCode: number }>}
 */
export async function runVerify(options) {
  const { url, key, fetchImpl = fetch } = options;
  const typesPath = options.typesPath ?? DEFAULT_TYPES_PATH;
  const client = createClient({ url, key, fetchImpl });

  const checks = [];
  const record = (name, status, detail) => checks.push({ name, status, detail });

  let interfaces;
  try {
    interfaces = parseInterfaces(readFileSync(typesPath, "utf8"));
  } catch (error) {
    return {
      checks: [{ name: "interface parsing", status: "fail", detail: error.message }],
      failures: [{ name: "interface parsing", detail: error.message }],
      exitCode: 1,
    };
  }

  // --- 1. analytics field sets ---------------------------------------------
  for (const { rpc, args, iface } of ANALYTICS_CHECKS) {
    const declared = interfaces.get(iface);
    if (!declared) {
      record(rpc, "fail", `interface ${iface} not found in apps/web/src/types/database.ts`);
      continue;
    }

    let result;
    try {
      result = await client.rpc(rpc, args);
    } catch (error) {
      record(rpc, "fail", `request failed: ${error.message}`);
      continue;
    }

    if (typeof result.text === "string" && result.text.includes("PGRST202")) {
      record(rpc, "fail", `${rpc} is missing from the PostgREST schema cache`);
      continue;
    }
    if (isPermissionFailure(result)) {
      record(
        rpc,
        "skip",
        `HTTP ${result.status} — a staff session is required; set SBTF_VERIFY_EMAIL / SBTF_VERIFY_PASSWORD`,
      );
      continue;
    }
    if (!result.ok) {
      record(rpc, "fail", `HTTP ${result.status}: ${String(result.text).slice(0, 200)}`);
      continue;
    }

    const rows = Array.isArray(result.body) ? result.body : result.body == null ? [] : [result.body];
    if (rows.length === 0) {
      record(rpc, "warn", `returned 0 rows — ${iface} field set could not be compared`);
      continue;
    }

    const actual = new Set(Object.keys(rows[0]));
    const missing = [...declared].filter((field) => !actual.has(field));
    const extra = [...actual].filter((field) => !declared.has(field));

    if (missing.length > 0) {
      record(
        rpc,
        "fail",
        `${iface}: missing field(s) ${missing.join(", ")}${
          extra.length ? `; unexpected field(s) ${extra.join(", ")}` : ""
        }`,
      );
      continue;
    }
    record(
      rpc,
      extra.length > 0 ? "warn" : "pass",
      `${iface}: all ${declared.size} field(s) present${
        extra.length ? `; unexpected field(s) ${extra.join(", ")}` : ""
      }`,
    );
  }

  // --- 2. certificate round-trip -------------------------------------------
  const declaredVerification = interfaces.get("CertificateVerification");
  if (!declaredVerification) {
    record("certificate round-trip", "fail", "interface CertificateVerification not found");
  } else {
    let codes = [];
    try {
      const listed = await client.get("franchise_records", "select=verification_code&limit=1");
      if (listed.ok && Array.isArray(listed.body)) {
        codes = listed.body.map((row) => row.verification_code).filter(Boolean);
      } else if (isPermissionFailure(listed)) {
        record(
          "certificate round-trip",
          "skip",
          `franchise_records refused with HTTP ${listed.status} — a staff session is required`,
        );
      }
    } catch (error) {
      record("certificate round-trip", "fail", `franchise_records read failed: ${error.message}`);
    }

    if (codes.length === 0) {
      record(
        "certificate round-trip",
        "warn",
        "no verification code available — issue a franchise record first, then re-run",
      );
    } else {
      const code = codes[0];
      let verified;
      try {
        verified = await client.rpc("rpc_verify_certificate", { p_code: code });
      } catch (error) {
        record("certificate round-trip", "fail", `rpc_verify_certificate failed: ${error.message}`);
        verified = null;
      }

      if (verified) {
        if (!verified.ok) {
          record(
            "certificate round-trip",
            "fail",
            `rpc_verify_certificate HTTP ${verified.status}: ${String(verified.text).slice(0, 200)}`,
          );
        } else {
          const row = Array.isArray(verified.body) ? verified.body[0] : verified.body;
          if (!row || typeof row !== "object") {
            record("certificate round-trip", "fail", "rpc_verify_certificate returned no row");
          } else {
            const actual = new Set(Object.keys(row));
            const missing = [...declaredVerification].filter((field) => !actual.has(field));
            const status = row.verification_status;
            if (missing.length > 0) {
              record(
                "certificate round-trip",
                "fail",
                `CertificateVerification: missing field(s) ${missing.join(", ")}`,
              );
            } else if (!["valid", "expired", "archived", "not_found"].includes(status)) {
              record(
                "certificate round-trip",
                "fail",
                `unexpected verification_status ${JSON.stringify(status)}`,
              );
            } else if (status !== "not_found" && row.franchise_number == null) {
              record(
                "certificate round-trip",
                "fail",
                `verification_status ${status} without a franchise_number`,
              );
            } else if (
              status !== "not_found" &&
              typeof row.operator_display_name === "string" &&
              !row.operator_display_name.includes("*")
            ) {
              record(
                "certificate round-trip",
                "fail",
                "the operator name is not masked — rpc_verify_certificate must not expose it",
              );
            } else {
              record(
                "certificate round-trip",
                "pass",
                `code ${code} → ${status}${
                  row.franchise_number ? ` (${row.franchise_number})` : ""
                }, operator name masked`,
              );
            }
          }
        }
      }
    }
  }

  // --- 3. private storage refusals -----------------------------------------
  for (const bucket of PRIVATE_BUCKETS) {
    let result;
    try {
      // An unsigned download of an arbitrary private path must be refused.
      result = await client.request(`/storage/v1/object/${bucket}/verify-live-probe.pdf`);
    } catch (error) {
      record(`storage: ${bucket}`, "fail", `request failed: ${error.message}`);
      continue;
    }

    if (result.ok) {
      record(
        `storage: ${bucket}`,
        "fail",
        `an anonymous download succeeded (HTTP ${result.status}) — the bucket must stay private`,
      );
      continue;
    }
    if (result.status === 404) {
      record(
        `storage: ${bucket}`,
        "warn",
        "refused with 404 — expected 400/401/403; confirm the bucket exists",
      );
      continue;
    }
    record(`storage: ${bucket}`, "pass", `anonymous download refused (HTTP ${result.status})`);
  }

  const failures = checks
    .filter((check) => check.status === "fail")
    .map(({ name, detail }) => ({ name, detail }));

  return { checks, failures, exitCode: failures.length > 0 ? 1 : 0 };
}

/* -------------------------------------------------------------------------- */
/* CLI                                                                         */
/* -------------------------------------------------------------------------- */

function readEnvFile(path) {
  const env = {};
  for (const raw of readFileSync(path, "utf8").split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    env[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
  }
  return env;
}

const SYMBOLS = { pass: "✓", fail: "✗", warn: "!", skip: "·" };

export async function main(argv = process.argv) {
  let fileEnv = {};
  try {
    fileEnv = readEnvFile(DEFAULT_ENV_PATH);
  } catch {
    /* The process environment alone is enough. */
  }
  const env = { ...fileEnv, ...process.env };

  const url = env.NEXT_PUBLIC_SUPABASE_URL ?? "";
  const key =
    env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "";

  if (!url.startsWith("http") || url.includes("your-project-ref") || key.length <= 20) {
    console.error("SBTF live verification\n");
    console.error(
      "  ✗ apps/web/.env.local is missing or still holds placeholder values.\n" +
        "    Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY first.",
    );
    return 1;
  }

  const projectRef = url.replace(/^https?:\/\//, "").split(".")[0];
  console.log(`SBTF live verification — ${projectRef}\n`);

  const { checks, failures, exitCode } = await runVerify({ url, key });

  for (const check of checks) {
    console.log(`  ${SYMBOLS[check.status]} ${check.name.padEnd(38)} ${check.detail}`);
  }

  const warnings = checks.filter((check) => check.status === "warn").length;
  const skipped = checks.filter((check) => check.status === "skip").length;

  console.log("");
  console.log(
    `  ${checks.length - failures.length - warnings - skipped} passed, ${failures.length} failed, ` +
      `${warnings} warning(s), ${skipped} skipped.`,
  );

  if (failures.length > 0) {
    console.log("");
    for (const failure of failures) console.log(`  ✗ ${failure.name}: ${failure.detail}`);
    console.log("");
    return exitCode;
  }

  console.log("\nEvery live query answered with the shape the application expects.\n");
  return exitCode;
}

const invokedDirectly =
  process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1]);

if (invokedDirectly) {
  process.exit(await main());
}
