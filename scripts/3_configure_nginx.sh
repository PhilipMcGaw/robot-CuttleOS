#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_SOURCE="$PROJECT_ROOT/configs/nginx.conf"
SITE_NAME="rov-cockpit"
SITE_AVAILABLE="/etc/nginx/sites-available/$SITE_NAME"
SITE_ENABLED="/etc/nginx/sites-enabled/$SITE_NAME"
CACHE_DIR="/var/cache/nginx/rov-map"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }
escape_sed_replacement() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

echo "[INFO] ROV Cockpit Nginx configuration"
echo "[INFO] Project version: unversioned; see MASTER_CONTEXT.md"
echo "[INFO] Project directory: $PROJECT_ROOT"
echo "[INFO] Operating mode: Raspberry Pi/Linux reverse proxy with local map-tile cache"
echo "[INFO] Nginx source: $NGINX_SOURCE"
echo "[INFO] Site target: $SITE_AVAILABLE"
echo "[INFO] Map cache: $CACHE_DIR, maximum configured size 256 MB"
echo "[INFO] Required privileged actions: Nginx configuration, service reload, and cache-directory ownership"

[[ "$(uname -s)" == "Linux" ]] || fail "Unsupported operating system: $(uname -s). This script is for Raspberry Pi/Linux deployment."
[[ -f "$NGINX_SOURCE" ]] || fail "Nginx source configuration is missing: $NGINX_SOURCE. Restore the Cockpit configs directory."
command -v nginx >/dev/null 2>&1 || fail "Nginx executable is unavailable. Install Nginx with the system package manager, then rerun."
command -v sudo >/dev/null 2>&1 || fail "sudo is unavailable. A documented privileged operation is required to install the Nginx site and cache directory."

info "Creating the project-local deployment cache target with controlled ownership."
sudo install -d -o www-data -g www-data -m 0750 "$CACHE_DIR" || fail "Could not create or secure $CACHE_DIR. Check sudo permissions and disk availability."
pass "Nginx map-cache directory is available."

if sudo test -e "$SITE_AVAILABLE"; then
  BACKUP="$SITE_AVAILABLE.bak.$TIMESTAMP"
  info "Backing up the existing Cockpit site configuration to $BACKUP before replacement."
  sudo cp -p "$SITE_AVAILABLE" "$BACKUP" || fail "Could not back up $SITE_AVAILABLE. No configuration was replaced."
  pass "Existing site configuration backed up."
fi

info "Installing the Cockpit Nginx site configuration."
RENDERED_SITE="$(mktemp)"
trap 'rm -f "$RENDERED_SITE"' EXIT
COCKPIT_ROOT_ESCAPED="$(escape_sed_replacement "$PROJECT_ROOT")"
sed "s|@COCKPIT_ROOT@|$COCKPIT_ROOT_ESCAPED|g" "$NGINX_SOURCE" > "$RENDERED_SITE"
sudo install -o root -g root -m 0644 "$RENDERED_SITE" "$SITE_AVAILABLE" || fail "Could not install $SITE_AVAILABLE. Check sudo permissions."
sudo ln -sfn "$SITE_AVAILABLE" "$SITE_ENABLED" || fail "Could not enable $SITE_ENABLED."
pass "Cockpit Nginx site installed and enabled."

info "Validating the complete Nginx configuration before reload."
sudo nginx -t || fail "Nginx validation failed. The service was not restarted; inspect $SITE_AVAILABLE and the preceding diagnostic output."
pass "Nginx configuration is valid."

info "Reloading Nginx and restarting Cockpit so MAP_TILE_PROXY=true takes effect."
sudo systemctl enable nginx >/dev/null || fail "Could not enable Nginx at boot."
sudo systemctl reload nginx || fail "Nginx reload failed. Inspect: sudo journalctl -u nginx -n 50 --no-pager"
sudo systemctl daemon-reload || fail "systemd daemon reload failed."
sudo systemctl restart cockpit || fail "Cockpit restart failed. Inspect: sudo journalctl -u cockpit -n 50 --no-pager"
pass "Nginx and Cockpit services restarted."

echo "[INFO] Environment summary:"
echo "[INFO] nginx=validated and running; site=installed and enabled; map-cache=installed; MAP_TILE_PROXY=configured; Cockpit=restart requested."
echo "[INFO] Verify tile caching with: curl -I http://127.0.0.1/map-tiles/osm/0/0/0.png"
echo "[INFO] A response containing X-ROV-Map-Cache: MISS or HIT confirms the proxy path."
