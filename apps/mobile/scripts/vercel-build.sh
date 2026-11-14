#!/usr/bin/env bash
# Builds the Flutter web application for Vercel.
#
# Vercel's build image does not ship the Flutter SDK, so the pinned stable
# release is downloaded into the build workspace first. The resulting static
# bundle is written to build/web, which vercel.json declares as the output
# directory.
#
# SUPABASE_URL and SUPABASE_ANON_KEY are optional: lib/core/env.dart already
# compiles in the active project's publishable values. Set them as Vercel
# environment variables to point the deployment at another project.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.7}"
FLUTTER_SDK_DIR="${FLUTTER_SDK_DIR:-$PWD/.flutter-sdk}"

if [ ! -x "$FLUTTER_SDK_DIR/bin/flutter" ]; then
  archive="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${archive}"
  tmp_dir="$(mktemp -d)"

  echo "Downloading Flutter ${FLUTTER_VERSION}..."
  curl -fsSL "$url" -o "${tmp_dir}/${archive}"
  tar -xJf "${tmp_dir}/${archive}" -C "$tmp_dir"

  rm -rf "$FLUTTER_SDK_DIR"
  mkdir -p "$(dirname "$FLUTTER_SDK_DIR")"
  mv "${tmp_dir}/flutter" "$FLUTTER_SDK_DIR"
  rm -rf "$tmp_dir"
fi

export PATH="$FLUTTER_SDK_DIR/bin:$PATH"
export CI=true

# Vercel checks out the project as a different user than the one that owns the
# extracted SDK, so git refuses to inspect it ("dubious ownership"). Flutter's
# tool reads the SDK's git metadata; mark just this directory as safe.
git config --global --add safe.directory "$FLUTTER_SDK_DIR"

flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get

build_args=(--release)
if [ -n "${SUPABASE_URL:-}" ]; then
  build_args+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
fi
if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  build_args+=("--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}")
fi

flutter build web "${build_args[@]}"

# Assemble /install: copies the page, generates the QR code, and downloads the
# release APKs listed in web/install/release.json. Keeping this here means a
# plain `git push` publishes a complete install page, not just the web app.
node ../../scripts/build-install-site.mjs

