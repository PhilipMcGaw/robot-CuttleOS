#!/usr/bin/env bash
set -Eeuo pipefail

fail() { printf '%s\n' "[FAIL] $*" >&2; exit 1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
FRONTEND_DIR="${PROJECT_ROOT}/frontend/cockpit"
STATIC_DIR="${PROJECT_ROOT}/cockpit/src/rov_cockpit/static"
DEMO_DIR="${PROJECT_ROOT}/static-demo"

printf '%s\n' '[INFO] Building self-contained animated static Cockpit demo'
"${SCRIPT_DIR}/build_frontend.sh"
rm -rf "${DEMO_DIR}/assets"
mkdir -p "${DEMO_DIR}/assets" "${DEMO_DIR}/assets/webfonts"
cp "${DEMO_DIR}/index.template.html" "${DEMO_DIR}/index.html"
cp "${STATIC_DIR}/css/pico.css" "${DEMO_DIR}/assets/pico.css"
cp "${STATIC_DIR}/css/cockpit.css" "${DEMO_DIR}/assets/cockpit.css"
sed 's|\.\./webfonts/|/assets/webfonts/|g' "${STATIC_DIR}/css/all.css" > "${DEMO_DIR}/assets/all.css"
cp "${STATIC_DIR}/background.jpg" "${DEMO_DIR}/assets/background.jpg"
cp "${STATIC_DIR}/webfonts/"*.woff2 "${DEMO_DIR}/assets/webfonts/"
cp "${STATIC_DIR}/dist/static-demo.js" "${DEMO_DIR}/assets/static-demo.js"
cp -R "${STATIC_DIR}/dist/components" "${DEMO_DIR}/assets/components"
cp -R "${STATIC_DIR}/dist/telemetry" "${DEMO_DIR}/assets/telemetry"
printf '%s\n' "[PASS] Static demo generated at ${DEMO_DIR}"

UPLOAD_DEST="${DEMO_UPLOAD_DEST:-}"
if [[ -n "$UPLOAD_DEST" && -t 0 ]]; then
  read -r -p "Upload static demo to ${UPLOAD_DEST}? [y/N] " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    command -v rsync >/dev/null 2>&1 || fail "rsync is not installed; upload cancelled."
    # TODO: Confirm the DEMO_UPLOAD_DEST convention and rsync options before relying on automatic uploads.
    rsync -avz "${DEMO_DIR}/" "$UPLOAD_DEST" || fail "Static demo upload failed."
    printf '%s\n' '[PASS] Static demo uploaded successfully.'
  else
    printf '%s\n' '[INFO] Upload skipped.'
  fi
else
  printf '%s\n' '[INFO] Upload skipped; DEMO_UPLOAD_DEST is not configured or the build is non-interactive.'
fi
