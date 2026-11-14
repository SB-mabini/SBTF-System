#!/usr/bin/env node
/**
 * Assemble the phone-install payload inside the web build.
 *
 *   flutter build web
 *   npm run install:page
 *
 * Flutter wipes `build/web` on every build, so the install page source lives in
 * `apps/mobile/web/install/`. This script copies it into the build, adds the
 * QR code, fetches the published APKs (GitHub release assets listed in
 * `release.json`), verifies their SHA-256, and writes the Vercel headers.
 *
 * `release.json` is produced by `npm run install:publish`. It is committed, so
 * a plain `git push` (and therefore a Vercel build) can assemble the same page
 * without any token or local APK.
 *
 * Set SBTF_INSTALL_URL to move the page to a custom domain.
 */

import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const qrcode = require("../apps/mobile/web/install/vendor/qrcode.js");

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const mobile = path.join(root, "apps", "mobile");
const source = path.join(mobile, "web", "install");
const output = path.join(mobile, "build", "web", "install");
const builtApkDir = path.join(mobile, "build", "app", "outputs", "flutter-apk");

const installUrl =
  process.env.SBTF_INSTALL_URL?.trim() || "https://sbtf-application.vercel.app/install/";

if (!existsSync(path.join(source, "release.json"))) {
  fail(
    "No apps/mobile/web/install/release.json. Publish the APKs first:\n" +
      "  cd apps/mobile && flutter build apk --release --split-per-abi\n" +
      "  npm run install:publish",
  );
}

const release = JSON.parse(readFileSync(path.join(source, "release.json"), "utf8"));
const apks = Array.isArray(release.apks) ? release.apks : [];
if (apks.length === 0) fail("release.json lists no APKs.");

mkdirSync(path.join(output, "download"), { recursive: true });

// 1. The page, its vendored QR library, and the manifest.
copyTree(source, output);

// 2. The APKs. A local build with the matching hash is used as-is; otherwise
//    the published asset is downloaded (this is the path Vercel takes).
for (const apk of apks) {
  const destination = path.join(output, "download", apk.file);
  const local = path.join(builtApkDir, localName(apk));

  if (existsSync(local) && sha256(local) === apk.sha256) {
    copyFileSync(local, destination);
  } else {
    await download(apk.sourceUrl, destination);
    if (sha256(destination) !== apk.sha256) {
      fail(
        `${apk.assetName} did not match the recorded SHA-256. Refusing to ` +
          "publish a different binary than the one that was released.",
      );
    }
  }

  const size = statSync(destination).size;
  if (size !== apk.sizeBytes) {
    fail(`${apk.assetName} is ${size} bytes; release.json says ${apk.sizeBytes}.`);
  }
}

// 3. QR code pointing at the deployed page.
const qr = qrcode(0, "M");
qr.addData(installUrl);
qr.make();
const svg = qr.createSvgTag({
  cellSize: 10,
  margin: 2,
  scalable: true,
  title: "QR code that opens the SBTF installation page",
  alt: `QR code for ${installUrl}`,
});
writeFileSync(path.join(output, "qr.svg"), `${svg}\n`);

// 4. Headers. Vercel infers the APK type, but stating it explicitly keeps
//    browsers from opening the file as text. Files are revalidated so a new
//    release is picked up without renaming the download links.
writeFileSync(
  path.join(mobile, "build", "web", "vercel.json"),
  `${JSON.stringify(
    {
      headers: [
        {
          source: "/install/download/(.*)\\.apk",
          headers: [
            { key: "Content-Type", value: "application/vnd.android.package-archive" },
            { key: "Content-Disposition", value: 'attachment; filename="sbtf.apk"' },
            { key: "Cache-Control", value: "public, max-age=0, must-revalidate" },
          ],
        },
        {
          source: "/install/release.json",
          headers: [{ key: "Cache-Control", value: "no-cache" }],
        },
        {
          source: "/install/qr.svg",
          headers: [{ key: "Cache-Control", value: "public, max-age=86400" }],
        },
      ],
    },
    null,
    2,
  )}\n`,
);

console.log(`Install page: ${installUrl}`);
console.log(`Version:      ${release.version} (build ${release.build})`);
for (const apk of apks) {
  const mb = (apk.sizeBytes / 1048576).toFixed(1);
  console.log(`  ${apk.abi.padEnd(12)} ${mb.padStart(6)} MB  → download/${apk.file}`);
}
console.log(`Output:       ${path.relative(root, output)}`);

function localName(apk) {
  // Matches the artefact names produced by `flutter build apk --split-per-abi`.
  return `app-${apk.abi}-release.apk`;
}

async function download(url, destination) {
  const response = await fetch(url, {
    headers: { "User-Agent": "sbtf-install-site" },
    redirect: "follow",
  });
  if (!response.ok) {
    fail(`Downloading ${url} failed: ${response.status} ${response.statusText}`);
  }
  writeFileSync(destination, Buffer.from(await response.arrayBuffer()));
}

function sha256(file) {
  return createHash("sha256").update(readFileSync(file)).digest("hex");
}

function copyTree(from, to) {
  for (const entry of readdirSync(from, { withFileTypes: true })) {
    if (entry.name === "download") continue; // generated fresh every build
    const src = path.join(from, entry.name);
    const dest = path.join(to, entry.name);
    if (entry.isDirectory()) {
      mkdirSync(dest, { recursive: true });
      copyTree(src, dest);
    } else {
      copyFileSync(src, dest);
    }
  }
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
