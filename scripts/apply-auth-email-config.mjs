#!/usr/bin/env node
/**
 * Read or apply the project's Supabase Auth e-mail configuration.
 *
 * `supabase/config.toml` and `supabase/templates/*` only configure
 * `supabase start`. The hosted project keeps its own copies, and a project
 * left on Supabase's default "Confirm signup" template sends a
 * `{{ .ConfirmationURL }}` link whose button says "Confirm your email
 * address" instead of the 6-digit code the driver/operator app expects.
 *
 * Usage:
 *   node scripts/apply-auth-email-config.mjs            # read-only check
 *   node scripts/apply-auth-email-config.mjs --apply    # push templates
 *   node scripts/apply-auth-email-config.mjs --apply --site-url https://example.com
 *
 * SITE_URL is the production origin used by the invitation template. It is read
 * from --site-url, then the SITE_URL environment variable, then the default
 * below. Never inherit the currently stored value: an outdated deployment URL
 * silently sends invitation links to a host the app no longer serves.
 *
 * Requires a Supabase personal access token (not the anon key):
 *   https://supabase.com/dashboard/account/tokens
 *   set SUPABASE_ACCESS_TOKEN in the shell
 *
 * The project ref is read from SUPABASE_PROJECT_REF, then the linked-project
 * file written by `supabase link`.
 */

import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const templatesDir = path.join(root, "supabase", "templates");

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const siteUrlFlagIndex = args.indexOf("--site-url");
const siteUrlFlag = siteUrlFlagIndex >= 0 ? args[siteUrlFlagIndex + 1] : undefined;

if (siteUrlFlagIndex >= 0 && !siteUrlFlag) {
  fail("--site-url needs a value, e.g. --site-url https://sbtf-system.vercel.app");
}

const DEFAULT_SITE_URL = "https://sbtf-system.vercel.app";
const siteUrl = normaliseUrl(siteUrlFlag ?? process.env.SITE_URL ?? DEFAULT_SITE_URL);

if (!/^https?:\/\/[^/]+$/i.test(siteUrl)) {
  fail(`site_url must be an origin with no trailing slash or path: ${siteUrl}`);
}

if (args.includes("--help") || args.includes("-h")) {
  console.log(
    [
      "Usage: node scripts/apply-auth-email-config.mjs [--apply] [--site-url URL]",
      "",
      "  (no flag)  read the hosted Auth e-mail config and report mismatches",
      "  --apply    push supabase/templates/* and the OTP settings, then re-read",
      "",
      "Environment:",
      "  SUPABASE_ACCESS_TOKEN  required — a personal access token",
      "  SUPABASE_PROJECT_REF   optional — otherwise read from supabase link",
      "  SITE_URL               optional — production origin for invitation links",
    ].join("\n"),
  );
  process.exit(0);
}

const projectRef = readProjectRef();
const token = process.env.SUPABASE_ACCESS_TOKEN;

if (!token) {
  fail(
    "No Supabase access token found.\n" +
      "  1. Create one at https://supabase.com/dashboard/account/tokens\n" +
      "  2. Set SUPABASE_ACCESS_TOKEN in this shell, then run this script again.",
  );
}

/**
 * The four templates the project depends on. `expect` is what the read-back
 * verification requires; `forbid` catches a template that was replaced with
 * Supabase's default link-based body.
 */
const TEMPLATES = [
  {
    key: "confirmation",
    subjectKey: "mailer_subjects_confirmation",
    contentKey: "mailer_templates_confirmation_content",
    subject: "Confirm your SBTF account — verification code",
    file: "confirmation.html",
    expect: ["{{ .Token }}"],
    forbid: ["{{ .ConfirmationURL }}", "{{ .TokenHash }}"],
  },
  {
    key: "magic_link",
    subjectKey: "mailer_subjects_magic_link",
    contentKey: "mailer_templates_magic_link_content",
    subject: "One-time password — SBTF System",
    file: "magic_link.html",
    expect: ["{{ .Token }}"],
    forbid: ["{{ .ConfirmationURL }}"],
  },
  {
    key: "recovery",
    subjectKey: "mailer_subjects_recovery",
    contentKey: "mailer_templates_recovery_content",
    subject: "Your SBTF verification code — SBTF System",
    file: "recovery.html",
    expect: ["{{ .Token }}"],
    forbid: ["{{ .ConfirmationURL }}", "{{ .TokenHash }}"],
  },
  {
    key: "invite",
    subjectKey: "mailer_subjects_invite",
    contentKey: "mailer_templates_invite_content",
    subject: "SBTF staff account invitation — SBTF System",
    file: "invite.html",
    expect: ["{{ .TokenHash }}", "/auth/confirm"],
    forbid: ["{{ .ConfirmationURL }}"],
  },
];

const apiBase = `https://api.supabase.com/v1/projects/${projectRef}/config/auth`;

console.log(`Project: ${projectRef}`);
console.log(`Site URL: ${siteUrl}`);
console.log(`Mode:    ${apply ? "apply then verify" : "read-only check"}`);
console.log("");

const before = await request(apiBase, { method: "GET" });

if (!before.ok || !before.data) {
  fail(`Could not read the Auth config: ${before.status} ${before.detail}`);
}

if (apply) {
  const body = {
    mailer_otp_length: 6,
    mailer_otp_exp: 600,
    site_url: siteUrl,
  };

  for (const template of TEMPLATES) {
    const contentPath = path.join(templatesDir, template.file);
    if (!existsSync(contentPath)) {
      fail(`Missing template file: ${contentPath}`);
    }
    body[template.subjectKey] = template.subject;
    body[template.contentKey] = readFileSync(contentPath, "utf8");
  }

  const updated = await request(apiBase, { method: "PATCH", body });

  if (!updated.ok) {
    fail(`The config update failed: ${updated.status} ${updated.detail}`);
  }
  console.log("Templates and OTP settings were accepted by the Management API.");
  console.log("");
}

const config = apply ? await request(apiBase, { method: "GET" }) : before;

if (!config.ok || !config.data) {
  fail(`Could not read the Auth config: ${config.status} ${config.detail}`);
}

let failures = 0;
const ok = (message) => console.log(`  ✓ ${message}`);
const bad = (message) => {
  failures++;
  console.error(`  ✗ ${message}`);
};

console.log("OTP settings");
for (const [key, expected] of [
  ["mailer_otp_length", 6],
  ["mailer_otp_exp", 600],
]) {
  const actual = config.data[key];
  if (String(actual) === String(expected)) {
    ok(`${key} = ${actual}`);
  } else {
    bad(`${key} is ${actual ?? "(not set)"}; expected ${expected}`);
  }
}

const storedSiteUrl = config.data.site_url;
if (storedSiteUrl === siteUrl) {
  ok(`site_url = ${siteUrl}`);
} else {
  bad(`site_url is ${storedSiteUrl ?? "(not set)"}; expected ${siteUrl}`);
}

console.log("");
console.log("Email templates");

for (const template of TEMPLATES) {
  const subject = config.data[template.subjectKey];
  const content = config.data[template.contentKey] ?? "";

  if (subject === template.subject) {
    ok(`${template.key}: subject matches`);
  } else {
    bad(
      `${template.key}: subject is ${JSON.stringify(subject ?? null)}; expected ${JSON.stringify(template.subject)}`,
    );
  }

  const missing = template.expect.filter((needle) => !content.includes(needle));
  if (missing.length === 0) {
    ok(`${template.key}: body contains ${template.expect.join(", ")}`);
  } else {
    bad(`${template.key}: body is missing ${missing.join(", ")}`);
  }

  const present = template.forbid.filter((needle) => content.includes(needle));
  if (present.length === 0) {
    ok(`${template.key}: no link-only placeholders`);
  } else {
    bad(`${template.key}: body still contains ${present.join(", ")}`);
  }
}

console.log("");
if (failures > 0) {
  console.error(
    `${failures} check(s) failed. ` +
      (apply
        ? "The Management API accepted the update but the stored values differ; check the project ref."
        : "Run this script with --apply to push the repository templates."),
  );
  process.exit(1);
}

console.log(
  "The hosted project is sending codes, not confirmation links. " +
    "Registration and the mobile OTP screen will agree.",
);

async function request(url, { method, body }) {
  let response;
  try {
    response = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (error) {
    return { ok: false, status: 0, detail: error.message };
  }

  const text = await response.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = null;
  }

  return {
    ok: response.ok,
    status: response.status,
    data,
    detail: response.ok ? "" : text.slice(0, 500),
  };
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
    "No linked Supabase project. Set SUPABASE_PROJECT_REF or run " +
      "`npx supabase link --project-ref <ref>`.",
  );
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function normaliseUrl(value) {
  return value.trim().replace(/\/+$/, "");
}
