#!/usr/bin/env node
/**
 * Deploy the SBTF Edge Functions to the linked Supabase project.
 *
 * The CLI needs a Supabase access token. Create one at
 * https://supabase.com/dashboard/account/tokens and expose it as
 * SUPABASE_ACCESS_TOKEN (or run `npx supabase login` once).
 *
 * Usage:
 *   node scripts/deploy-functions.mjs                 # admin-users only
 *   node scripts/deploy-functions.mjs --all           # every function
 *   node scripts/deploy-functions.mjs --site-url https://example.com
 *
 * SITE_URL is the origin the administrator-issued setup/reset links point at.
 * It is read from --site-url, then the SITE_URL environment variable, then
 * NEXT_PUBLIC_SITE_URL in apps/web/.env.local.
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);
// Invoke the installed CLI directly instead of shelling out to `npx`. On
// Windows, Node 24 refuses to spawn `npx.cmd` without a shell.
const cliPath = path.join(
  path.dirname(require.resolve("supabase/package.json")),
  "dist",
  "supabase.js",
);

const args = process.argv.slice(2);
const all = args.includes("--all");
const siteUrlFlagIndex = args.indexOf("--site-url");
const siteUrlFlag = siteUrlFlagIndex >= 0 ? args[siteUrlFlagIndex + 1] : undefined;

if (siteUrlFlagIndex >= 0 && !siteUrlFlag) {
  fail("--site-url needs a value, e.g. --site-url https://sbtf-system.vercel.app");
}

const projectRef = readProjectRef();
const siteUrl = normaliseUrl(siteUrlFlag ?? process.env.SITE_URL ?? readLocalSiteUrl());
const allowedOrigins = process.env.ALLOWED_WEB_ORIGINS ?? siteUrl;

if (!siteUrl) {
  fail(
    "SITE_URL is not known. Set it explicitly:\n" +
      "  node scripts/deploy-functions.mjs --site-url https://your-web-origin\n" +
      "or set NEXT_PUBLIC_SITE_URL in apps/web/.env.local.",
  );
}

const token = process.env.SUPABASE_ACCESS_TOKEN;
if (!token && !hasStoredLogin()) {
  fail(
    "No Supabase access token found.\n" +
      "  1. Create one at https://supabase.com/dashboard/account/tokens\n" +
      "  2. Set SUPABASE_ACCESS_TOKEN in this shell, then run this script again\n" +
      "     (or run `npx supabase login` once).",
  );
}

console.log(`Project:       ${projectRef}`);
console.log(`SITE_URL:      ${siteUrl}`);
console.log(`Allowed CORS:  ${allowedOrigins}`);
console.log(`Functions:     ${all ? "all" : "admin-users"}`);
console.log("");

// Secrets must be set before the function is deployed so the first invocation
// already builds links against the right origin.
run([
  "secrets",
  "set",
  `SITE_URL=${siteUrl}`,
  `ALLOWED_WEB_ORIGINS=${allowedOrigins}`,
  "--project-ref",
  projectRef,
]);

const deployments = all
  ? [
      ["admin-users"],
      ["ai-decision-support"],
      ["password-recovery", "--no-verify-jwt"],
      ["renewal-reminders", "--no-verify-jwt"],
    ]
  : [["admin-users"]];

for (const [name, ...flags] of deployments) {
  run(["functions", "deploy", name, "--use-api", "--project-ref", projectRef, ...flags]);
}

run(["functions", "list", "--project-ref", projectRef]);

console.log("");
console.log("Done. In the web app, sign out and back in as an active administrator, then retry.");

function run(parts) {
  console.log(`> supabase ${parts.join(" ")}`);
  execFileSync(process.execPath, [cliPath, ...parts], {
    cwd: root,
    stdio: "inherit",
    env: process.env,
  });
}

function readProjectRef() {
  if (process.env.SUPABASE_PROJECT_REF) return process.env.SUPABASE_PROJECT_REF;

  const linked = path.join(root, "supabase", ".temp", "linked-project.json");
  if (existsSync(linked)) {
    try {
      const parsed = JSON.parse(readFileSync(linked, "utf8"));
      if (parsed?.ref) return parsed.ref;
    } catch {
      // Fall through to the explicit instruction below.
    }
  }

  fail(
    "No linked Supabase project. Run `npx supabase link --project-ref <ref>` " +
      "or set SUPABASE_PROJECT_REF.",
  );
}

function readLocalSiteUrl() {
  const envFile = path.join(root, "apps", "web", ".env.local");
  if (!existsSync(envFile)) return undefined;

  for (const line of readFileSync(envFile, "utf8").split(/\r?\n/)) {
    const match = line.match(/^\s*NEXT_PUBLIC_SITE_URL\s*=\s*(.+?)\s*$/);
    if (match) return match[1].replace(/^["']|["']$/g, "");
  }
  return undefined;
}

function normaliseUrl(value) {
  return value?.trim().replace(/\/+$/, "");
}

function hasStoredLogin() {
  const home = process.env.USERPROFILE ?? process.env.HOME;
  return Boolean(home && existsSync(path.join(home, ".supabase", "access-token")));
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
