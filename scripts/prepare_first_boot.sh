#!/usr/bin/env bash
set -Eeuo pipefail

# Prepare Raspberry Pi OS bootfs/user-data from macOS after Raspberry Pi
# Imager has written the SD card. This does not modify the image itself.

usage() {
  cat <<'EOF'
Usage:
  scripts/prepare_first_boot.sh /Volumes/bootfs --user USER [options]

Required:
  --user USER                 Imager-created Linux runtime user

Options:
  --profile PROFILE           Robot profile (default: rov)
  --repo-owner OWNER          GitHub owner (default: PhilipMcGaw)
  --repo-branch BRANCH        Git branch (default: main)
  --config-dir DIRECTORY      Directory containing nats.env, network.env and
                              network.secrets.env for unattended provisioning
  --help                      Show this help
EOF
}

[[ "$(uname -s)" == "Darwin" ]] || { echo "This helper must be run on macOS." >&2; exit 1; }

BOOT_VOLUME="${1:-}"
[[ -n "$BOOT_VOLUME" && "$BOOT_VOLUME" != --* ]] || { usage; exit 2; }
shift
ROBOT_USER=""
ROBOT_PROFILE="rov"
REPO_OWNER="PhilipMcGaw"
REPO_BRANCH="main"
CONFIG_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) ROBOT_USER="${2:-}"; shift 2 ;;
    --profile) ROBOT_PROFILE="${2:-}"; shift 2 ;;
    --repo-owner) REPO_OWNER="${2:-}"; shift 2 ;;
    --repo-branch) REPO_BRANCH="${2:-}"; shift 2 ;;
    --config-dir) CONFIG_DIR="${2:-}"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

fail() { echo "[FAIL] $*" >&2; exit 1; }
[[ -d "$BOOT_VOLUME" ]] || fail "Boot volume does not exist: $BOOT_VOLUME"
[[ -f "$BOOT_VOLUME/user-data" ]] || fail "Expected cloud-init user-data on $BOOT_VOLUME. Use a current Raspberry Pi OS image."
[[ "$ROBOT_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail "Provide a safe Linux username with --user."
[[ "$ROBOT_PROFILE" =~ ^[a-z0-9_-]+$ ]] || fail "Robot profile is unsafe: $ROBOT_PROFILE"
[[ "$REPO_OWNER" =~ ^[A-Za-z0-9_.-]+$ ]] || fail "Repository owner is unsafe."
[[ "$REPO_BRANCH" =~ ^[A-Za-z0-9_.-]+$ ]] || fail "Repository branch is unsafe."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIRSTBOOT_SCRIPT="$PROJECT_ROOT/scripts/first_boot_provision.sh"
SERVICE_FILE="$PROJECT_ROOT/configs/cuttleos-first-boot.service"

encode_file() {
  base64 < "$1" | tr -d '\n'
}

ENV_FILE="$(mktemp)"
trap 'rm -f "$ENV_FILE"' EXIT
printf '%s\n' \
  "ROBOT_USER=$ROBOT_USER" \
  "ROBOT_PROFILE=$ROBOT_PROFILE" \
  "REPO_OWNER=$REPO_OWNER" \
  "REPO_BRANCH=$REPO_BRANCH" \
  'ROBOTS_DIR=/home/'"$ROBOT_USER"'/robots' \
  'CONFIG_SEED_DIR=/var/lib/cuttleos/first-boot-config' > "$ENV_FILE"

USER_DATA="$BOOT_VOLUME/user-data"
ORIGINAL_USER_DATA="$(mktemp)"
TEMP_USER_DATA="$(mktemp)"
trap 'rm -f "$ENV_FILE" "$ORIGINAL_USER_DATA" "$TEMP_USER_DATA"' EXIT
cp "$USER_DATA" "$ORIGINAL_USER_DATA"

{
  printf '%s\n' '#cloud-config-archive' '---' '- type: text/cloud-config' '  content: |'
  sed 's/^/    /' "$ORIGINAL_USER_DATA" | sed '/^    #cloud-config$/d'
  printf '%s\n' '---' '- type: text/cloud-config' '  content: |' '    write_files:'
  printf '%s\n' '      - path: /usr/local/sbin/cuttleos-first-boot' '        owner: root:root' '        permissions: "0750"' '        encoding: b64' '        content: '
  encode_file "$FIRSTBOOT_SCRIPT"; printf '\n'
  printf '%s\n' '      - path: /etc/systemd/system/cuttleos-first-boot.service' '        owner: root:root' '        permissions: "0644"' '        encoding: b64' '        content: '
  encode_file "$SERVICE_FILE"; printf '\n'
  printf '%s\n' '      - path: /etc/cuttleos/first-boot.env' '        owner: root:root' '        permissions: "0600"' '        encoding: b64' '        content: '
  encode_file "$ENV_FILE"; printf '\n'

  if [[ -n "$CONFIG_DIR" ]]; then
    [[ -d "$CONFIG_DIR" ]] || fail "Config directory does not exist: $CONFIG_DIR"
    for config in nats.env network.env network.secrets.env; do
      [[ -f "$CONFIG_DIR/$config" ]] || fail "Missing config file: $CONFIG_DIR/$config"
      printf '%s\n' "      - path: /var/lib/cuttleos/first-boot-config/$config" '        owner: root:root' '        permissions: "0600"' '        encoding: b64' '        content: '
      encode_file "$CONFIG_DIR/$config"; printf '\n'
    done
  else
    echo "[WARN] No --config-dir supplied; first boot will stop until private deployment configs are provided." >&2
  fi

  printf '%s\n' '    runcmd:' '      - [systemctl, daemon-reload]' '      - [systemctl, enable, --now, cuttleos-first-boot.service]'
} > "$TEMP_USER_DATA"

cp "$TEMP_USER_DATA" "$USER_DATA"
echo "[PASS] First-boot configuration written to $USER_DATA"
if [[ -z "$CONFIG_DIR" ]]; then
  echo "[WARN] Add the private deployment configs before powering the Pi, or provisioning will stop safely."
fi