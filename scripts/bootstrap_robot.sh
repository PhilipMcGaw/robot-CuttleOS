#!/usr/bin/env bash
set -Eeuo pipefail

ROBOTS_DIR="${ROBOTS_DIR:-$HOME/robots}"
ROBOT_USER="${ROBOT_USER:-$(whoami)}"
GITHUB_USER="${GITHUB_USER:-PhilipMcGaw}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-https}"

banner() {
  echo
  echo "======================================================================"
  echo "  $*"
  echo "======================================================================"
  echo
}

section() {
  echo
  echo "----------------------------------------------------------------------"
  echo "  $*"
  echo "----------------------------------------------------------------------"
  echo
}

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

banner "CuttleOS — One-Click Robot Bootstrap"
info "This script installs the CuttleOS monorepo and provisions the target system."

section "System Checks"
if [[ "${EUID}" -ne 0 ]]; then
  fail "This script must run as root for system package installation and service configuration. Run: sudo bash $0"
fi
if [[ "$(uname -s)" != "Linux" ]]; then
  fail "This script is for Linux/Raspberry Pi only. Detected: $(uname -s)"
fi
info "System: $(uname -m) $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
info "Target directory: $ROBOTS_DIR"
info "Runtime user: $ROBOT_USER"
info "Deployment mode: $DEPLOYMENT_MODE"

section "Git"
if ! command -v git >/dev/null 2>&1; then
  info "Installing git."
  apt-get update
  apt-get install -y git
else
  pass "Git is already installed: $(git --version)"
fi

section "CuttleOS Repository"
mkdir -p "$ROBOTS_DIR"
cd "$ROBOTS_DIR"

if [[ -e "$ROBOTS_DIR/robot-CuttleOS" ]]; then
  fail "Target directory already exists: $ROBOTS_DIR/robot-CuttleOS. Remove it or set ROBOTS_DIR to an empty deployment directory before bootstrapping."
fi

if [[ "$DEPLOYMENT_MODE" == "ssh" ]]; then
  info "Cloning CuttleOS via SSH (developer mode)."
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]] && [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
    warn "No SSH key found. Creating one."
    ssh-keygen -t ed25519 -C "${ROBOT_USER}@robot" -f "$HOME/.ssh/id_ed25519" -N ""
    info "SSH key created. Add the public key to GitHub:"
    cat "$HOME/.ssh/id_ed25519.pub"
    read -p "Press Enter after adding the key to GitHub..."
  fi
  git clone "git@github.com:${GITHUB_USER}/robot-CuttleOS.git" robot-CuttleOS || fail "Failed to clone robot-CuttleOS"
else
  info "Cloning CuttleOS via HTTPS (read-only mode)."
  git clone --depth=1 "https://github.com/${GITHUB_USER}/robot-CuttleOS.git" robot-CuttleOS || fail "Failed to clone robot-CuttleOS"
fi
pass "CuttleOS monorepo cloned successfully."

section "Configuration"
cd "$ROBOTS_DIR/robot-CuttleOS"
if [[ ! -f "configs/nats.env" ]]; then
  cp configs/nats.env.example configs/nats.env
  info "Created configs/nats.env from example."
fi
if [[ ! -f "configs/network.env" ]]; then
  cp configs/network.env.example configs/network.env
  info "Created configs/network.env from example."
fi
if [[ ! -f "configs/network.secrets.env" ]]; then
  cp configs/network.secrets.example configs/network.secrets.env
  chmod 600 configs/network.secrets.env
  warn "Created configs/network.secrets.env — edit this file with your credentials."
fi

ROBOT_PROFILE="${ROBOT_PROFILE:-rov}"
info "Using robot profile: $ROBOT_PROFILE"

if grep -q "CHANGE_ME" configs/network.secrets.env; then
  warn "The secrets file contains placeholder values that must be changed."
  cat configs/network.secrets.env
  read -p "Press Enter after editing the secrets file, or Ctrl+C to abort..."
fi

section "Robot Provisioning"
export ROBOT_PROFILE="$ROBOT_PROFILE"
info "Starting Raspberry Pi provisioning."
info "This will take several minutes and requires internet access."
bash scripts/0_provision_rpi.sh
pass "Raspberry Pi provisioning completed."

banner "Bootstrap Complete"
pass "CuttleOS monorepo installed and provisioned."
info "Control and Datalogger are deployed from the CuttleOS monorepo."
info "Next steps:"
info "  1. Edit configuration files if needed."
info "  2. Reboot the system: sudo reboot"
info "  3. Access Cockpit at http://$(hostname -I | awk '{print $1}')"
