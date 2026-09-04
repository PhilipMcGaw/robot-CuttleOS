#!/usr/bin/env bash
set -Eeuo pipefail

# Non-interactive first-boot entry point. The macOS preparation helper embeds
# this file into cloud-init user-data; it is also useful for manual testing on
# a Raspberry Pi.

CONFIG_FILE="${CUTTLEOS_FIRSTBOOT_ENV:-/etc/cuttleos/first-boot.env}"
[[ -r "$CONFIG_FILE" ]] || { echo "[FAIL] First-boot configuration is missing: $CONFIG_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

ROBOT_USER="${ROBOT_USER:-}"
ROBOT_PROFILE="${ROBOT_PROFILE:-rov}"
ROBOTS_DIR="${ROBOTS_DIR:-/home/${ROBOT_USER}/robots}"
REPO_OWNER="${REPO_OWNER:-PhilipMcGaw}"
REPO_BRANCH="${REPO_BRANCH:-main}"
CONFIG_SEED_DIR="${CONFIG_SEED_DIR:-/var/lib/cuttleos/first-boot-config}"
PROJECT_ROOT="$ROBOTS_DIR/robot-CuttleOS"
CONTROL_ROOT="$ROBOTS_DIR/control"
DATALOGGER_ROOT="$ROBOTS_DIR/datalogger"
MARKER="/var/lib/cuttleos/first-boot-complete"

info() { echo "[INFO] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

[[ "${EUID}" -eq 0 ]] || fail "This script must run as root."
[[ "$ROBOT_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail "ROBOT_USER is missing or unsafe: $ROBOT_USER"
[[ "$ROBOT_PROFILE" =~ ^[a-z0-9_-]+$ ]] || fail "ROBOT_PROFILE is unsafe: $ROBOT_PROFILE"
id "$ROBOT_USER" >/dev/null 2>&1 || fail "The Imager-created runtime user does not exist: $ROBOT_USER"

if [[ -e "$MARKER" ]]; then
  info "CuttleOS first-boot provisioning is already complete."
  exit 0
fi

info "Installing the small first-boot source dependency."
apt-get update
apt-get install --yes ca-certificates git

install -d -o "$ROBOT_USER" -g "$(id -gn "$ROBOT_USER")" -m 0755 "$ROBOTS_DIR"

clone_or_update() {
  local url="$1" target="$2"
  if [[ -d "$target/.git" ]]; then
    git -C "$target" fetch --depth=1 origin "$REPO_BRANCH"
    git -C "$target" reset --hard "origin/$REPO_BRANCH"
  else
    git clone --depth=1 --branch "$REPO_BRANCH" "$url" "$target"
  fi
  chown -R "$ROBOT_USER:$(id -gn "$ROBOT_USER")" "$target"
}

info "Retrieving the CuttleOS repositories."
clone_or_update "https://github.com/$REPO_OWNER/robot-CuttleOS.git" "$PROJECT_ROOT"
clone_or_update "https://github.com/$REPO_OWNER/robot-Control.git" "$CONTROL_ROOT"
clone_or_update "https://github.com/$REPO_OWNER/robot-Datalogger.git" "$DATALOGGER_ROOT"

for config in nats.env network.env network.secrets.env; do
  [[ -r "$CONFIG_SEED_DIR/$config" ]] || fail "Missing first-boot deployment configuration: $CONFIG_SEED_DIR/$config"
  install -o "$ROBOT_USER" -g "$(id -gn "$ROBOT_USER")" -m 0644 "$CONFIG_SEED_DIR/$config" "$PROJECT_ROOT/configs/$config"
done
chmod 600 "$PROJECT_ROOT/configs/network.secrets.env"

info "Running the CuttleOS provisioner for profile $ROBOT_PROFILE."
export CONTROL_ROOT DATALOGGER_ROOT ROBOT_PROFILE
export SUDO_USER="$ROBOT_USER"
bash "$PROJECT_ROOT/scripts/0_provision_rpi.sh"

install -d -m 0755 "$(dirname "$MARKER")"
touch "$MARKER"
chmod 0644 "$MARKER"
info "CuttleOS first-boot provisioning completed successfully."
