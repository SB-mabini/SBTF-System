#!/usr/bin/env node
/**
 * Publish the release APKs and update the phone-install page.
 *
 *   cd apps/mobile && flutter build apk --release --split-per-abi
 *   npm run install:publish
 *
 * The APKs are attached to a GitHub Release in this repository (the repo is
 * public, so the asset URLs need no authentication and survive every Vercel
 * deployment). Their public URLs, sizes and hashes are written to
 * `apps/mobile/web/install/release.json`, which is committed. The Vercel build
 * then downloads those exact files into `build/web/install/download/`, so the
 * buttons on the install page stay on the app's own domain.
 *
 * This keeps ~50 MB of binaries out of git while still letting a plain
 * `git push` produce a complete site.
 *
 * Credentials: GITHUB_TOKEN (or GH_TOKEN) if set; otherwise the credential
 * already stored by git for github.com is used via `git credential fill`.
 *
 * Options:
 *   --no-upload  rebuild release.json from an existing GitHub release
 *   --dry-run    print what would happen, change nothing
 */

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const mobile = path.join(root, "apps", "mobile");
const source = path.join(mobile, "web", "install");
const apkDir = path.join(mobile, "build", "app", "outputs", "flutter-apk");
const releaseJsonPath = path.join(source, "release.json");

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const upload = !args.includes("--no-upload");

const repo = process.env.GITHUB_REPOSITORY?.trim() || "SB-mabini/SBTF-System";
const installUrl =
  process.env.SBTF_INSTALL_URL?.trim() || "https://sbtf-application.vercel.app/install/";

const CHANNELS = [
  {
    abi: "arm64-v8a",
    file: "sbtf-arm64.apk",
    source: "app-arm64-v8a-release.apk",
    label: "Android 7+ (64-bit, most phones)",
    primary: true,
  },
  {
    abi: "armeabi-v7a",
    file: "sbtf-armeabi-v7a.apk",
    source: "app-armeabi-v7a-release.apk",
    label: "Android 7+ (32-bit, older phones)",
    primary: false,
  },
];

const { version, build } = readVersion();
const tag = `app-v${version}-${build}`;

const apks = CHANNELS.map((channel) => {
  const filePath = path.join(apkDir, channel.source);
  if (!existsSync(filePath)) {
    fail(
      `Missing ${channel.source}. Build the APKs first:\n` +
        "  cd apps/mobile && flutter build apk --release --split-per-abi",
    );
  }
  return {
    ...channel,
    assetName: `sbtf-${version}-${channel.abi}.apk`,
    path: filePath,
    sizeBytes: statSync(filePath).size,
    sha256: createHash("sha256").update(readFileSync(filePath)).digest("hex"),
  };
});

console.log(`Release:  ${tag}`);
console.log(`Version:  ${version} (build ${build})`);
for (const apk of apks) {
  console.log(`  ${apk.abi.padEnd(12)} ${(apk.sizeBytes / 1048576).toFixed(1)} MB`);
}

if (dryRun) {
  console.log("\n--dry-run: no release or file was changed.");
  process.exit(0);
}

let release = null;
let token = null;

if (upload) {
  token = readToken();
  release = await findOrCreateRelease(token);
  for (const apk of apks) {
    await uploadAsset(token, release, apk);
  }
  console.log(`Release ready: https://github.com/${repo}/releases/tag/${tag}`);
} else {
  release = await findReleaseWithoutToken();
  if (!release) fail(`Release ${tag} not found on github.com/${repo}.`);
}

// Build the manifest from the asset URLs GitHub reports, so the page and the
// build step never guess a path.
const assets = await listAssets(token, release);
const manifest = {
  version,
  build,
  released: new Date().toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }),
  generatedAt: new Date().toISOString(),
  pageUrl: installUrl,
  releaseUrl: `https://github.com/${repo}/releases/tag/${tag}`,
  apks: apks.map((apk) => {
    const asset = assets.find((item) => item.name === apk.assetName);
    if (!asset) fail(`Asset ${apk.assetName} is missing from release ${tag}.`);
    return {
      abi: apk.abi,
      label: apk.label,
      file: apk.file,
      assetName: apk.assetName,
      sourceUrl: asset.browser_download_url,
      sizeBytes: apk.sizeBytes,
      sha256: apk.sha256,
      primary: apk.primary,
    };
  }),
};

writeFileSync(releaseJsonPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Wrote ${path.relative(root, releaseJsonPath)}`);
console.log("Next: commit it and push. The Vercel build downloads the APKs into /install/download/.");

function readVersion() {
  const pubspec = readFileSync(path.join(mobile, "pubspec.yaml"), "utf8");
  const match = pubspec.match(/^version:\s*([0-9A-Za-z.\-]+)\+([0-9]+)/m);
  if (!match) fail("Could not read `version: x.y.z+build` from apps/mobile/pubspec.yaml.");
  return { version: match[1], build: match[2] };
}

function readToken() {
  if (process.env.GITHUB_TOKEN) return process.env.GITHUB_TOKEN.trim();
  if (process.env.GH_TOKEN) return process.env.GH_TOKEN.trim();
  try {
    const raw = execFileSync("git", ["credential", "fill"], {
      input: "protocol=https\nhost=github.com\n\n",
      encoding: "utf8",
    });
    const match = raw.match(/^password=(.+)$/m);
    if (match) return match[1].trim();
  } catch {
    // Fall through to the instruction below.
  }
  fail(
    "No GitHub token. Set GITHUB_TOKEN (repo scope) or sign in with git so " +
      "`git credential fill` returns a credential for github.com.",
  );
}

async function findOrCreateRelease(token) {
  const existing = await api(token, "GET", `/repos/${repo}/releases/tags/${tag}`, null, {
    allow404: true,
  });
  if (existing) {
    console.log(`Reusing release ${tag}.`);
    return existing;
  }

  const created = await api(token, "POST", `/repos/${repo}/releases`, {
    tag_name: tag,
    name: `SBTF Android ${version} (build ${build})`,
    body:
      `Installable APKs for the SBTF driver/operator app.\n\n` +
      `Install from ${installUrl} — that page carries the QR code and instructions.\n\n` +
      `Version ${version}, build ${build}.`,
    draft: false,
    prerelease: false,
  });
  console.log(`Created release ${tag}.`);
  return created;
}

async function uploadAsset(token, release, apk) {
  // Re-uploading the same version is allowed: replace the asset rather than
  // failing, so a rebuild after a mistake still publishes.
  const assets = await listAssets(token, release);
  const existing = assets.find((item) => item.name === apk.assetName);
  if (existing) {
    await api(token, "DELETE", `/repos/${repo}/releases/assets/${existing.id}`);
    console.log(`Replaced ${apk.assetName}.`);
  }

  const body = readFileSync(apk.path);
  const url =
    `https://uploads.github.com/repos/${repo}/releases/${release.id}/assets` +
    `?name=${encodeURIComponent(apk.assetName)}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/vnd.android.package-archive",
      "User-Agent": "sbtf-install-publisher",
    },
    body,
  });

  if (!response.ok) {
    fail(`Uploading ${apk.assetName} failed: ${response.status} ${await response.text()}`);
  }
  console.log(`Uploaded ${apk.assetName}.`);
}

async function listAssets(token, release) {
  return api(
    token,
    "GET",
    `/repos/${repo}/releases/${release.id}/assets?per_page=100`,
  );
}

async function findReleaseWithoutToken() {
  try {
    const response = await fetch(`https://api.github.com/repos/${repo}/releases/tags/${tag}`, {
      headers: { Accept: "application/vnd.github+json", "User-Agent": "sbtf-install-publisher" },
    });
    if (!response.ok) return null;
    return response.json();
  } catch {
    return null;
  }
}

async function api(token, method, endpoint, body, { allow404 = false } = {}) {
  const headers = {
    Accept: "application/vnd.github+json",
    "User-Agent": "sbtf-install-publisher",
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`https://api.github.com${endpoint}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (allow404 && response.status === 404) return null;
  if (!response.ok) {
    fail(`${method} ${endpoint} failed: ${response.status} ${await response.text()}`);
  }
  return response.status === 204 ? null : response.json();
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
