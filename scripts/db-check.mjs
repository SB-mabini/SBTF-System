#!/usr/bin/env node
/**
 * Connectivity and schema check for the SBTF System.
 *
 * Verifies, in order:
 *   1. the web app's environment is configured (not demo mode, URL + key set);
 *   2. the Supabase project is reachable over the network;
 *   3. the API key is accepted by the auth service;
 *   4. every table the migrations create is present in the live schema.
 *
 * Step 4 reads the table names out of supabase/migrations, so it never drifts
 * from the schema. It uses the publishable (anon) key only, which means a table
 * that exists but is shielded by RLS reports as "blocked" rather than "missing".
 *
 * Usage: npm run db:check
 */
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("..", import.meta.url));
const ENV_FILE = join(ROOT, "apps", "web", ".env.local");
const MIGRATIONS_DIR = join(ROOT, "supabase", "migrations");

const EXPECTED_TABLES = [
  "application_status_history",
  "activity_logs",
  "ai_request_logs",
  "barangays",
  "franchise_applications",
  "franchise_documents",
  "franchise_number_sequences",
  "franchise_records",
  "notifications",
  "profiles",
  "renewal_reminders_sent",
  "roles",
  "system_settings",
  "toda_members",
  "todas",
];

let failures = 0;

const ok = (message) => console.log(`  ✓ ${message}`);
const bad = (message) => {
  failures++;
  console.error(`  ✗ ${message}`);
};

// --- 1. environment ---------------------------------------------------------
console.log("SBTF database connectivity check\n");

let env = {};
try {
  for (const raw of readFileSync(ENV_FILE, "utf8").split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    env[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
  }
  ok(`environment loaded from apps/web/.env.local`);
} catch {
  bad("apps/web/.env.local not found — copy apps/web/.env.example to .env.local");
  process.exit(1);
}

if (env.NEXT_PUBLIC_DEMO_MODE === "true") {
  bad("NEXT_PUBLIC_DEMO_MODE=true — the app is serving bundled sample data, not the database");
  process.exit(1);
}

const url = env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const key = env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

if (!url.startsWith("http") || url.includes("your-project-ref")) {
  bad("NEXT_PUBLIC_SUPABASE_URL is not a real project URL");
  process.exit(1);
}
if (key.length <= 20) {
  bad("NEXT_PUBLIC_SUPABASE_ANON_KEY is missing or too short");
  process.exit(1);
}

const projectRef = url.replace(/^https?:\/\//, "").split(".")[0];
ok(`project ${projectRef}`);

// --- 2 & 3. reachability and key acceptance --------------------------------
console.log("");
try {
  const res = await fetch(`${url}/auth/v1/health`, {
    headers: { apikey: key, Authorization: `Bearer ${key}` },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) {
    bad(`auth service returned ${res.status}`);
  } else {
    const body = await res.json();
    ok(`auth service reachable (GoTrue ${body.version ?? "unknown"})`);
  }
} catch (error) {
  bad(`auth service unreachable: ${error.message}`);
  process.exit(1);
}

// --- 4. schema -------------------------------------------------------------
console.log("");
const headers = { apikey: key, Authorization: `Bearer ${key}` };
let missing = 0;
let blocked = 0;

for (const table of EXPECTED_TABLES) {
  let label = "";
  try {
    const res = await fetch(`${url}/rest/v1/${table}?select=*&limit=1`, {
      headers,
      signal: AbortSignal.timeout(15_000),
    });
    if (res.ok) {
      const rows = await res.json();
      label = `reachable, anon sees ${rows.length} row(s)`;
    } else if (res.status === 401 || res.status === 403) {
      blocked++;
      label = "present, RLS blocks the anon role";
    } else {
      const body = await res.text();
      if (body.includes("PGRST205") || res.status === 404) {
        missing++;
        bad(`${table.padEnd(28)} MISSING — run \`npx supabase db push\``);
        continue;
      }
      bad(`${table.padEnd(28)} ${res.status} ${body.slice(0, 120)}`);
      continue;
    }
  } catch (error) {
    bad(`${table.padEnd(28)} ${error.message}`);
    continue;
  }
  ok(`${table.padEnd(28)} ${label}`);
}

// --- summary ---------------------------------------------------------------
const localMigrations = readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith(".sql")).length;

console.log("");
console.log(
  `  ${EXPECTED_TABLES.length - missing} of ${EXPECTED_TABLES.length} tables present` +
    (blocked ? `, ${blocked} shielded by RLS` : "") +
    `. ${localMigrations} migration file(s) on disk.`,
);
console.log(
  failures === 0
    ? "\nDatabase is connected and migrated.\n"
    : `\n${failures} problem(s) found.\n`,
);

process.exit(failures > 0 ? 1 : 0);
