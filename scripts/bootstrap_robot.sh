#!/usr/bin/env bash
set -Eeuo pipefail

# One-Click Robot CuttleOS Bootstrap Script
# This script pulls down all repositories and deploys the complete robot software stack

ROBOTS_DIR="${ROBOTS_DIR:-$HOME/robots}"
ROBOT_USER="${ROBOT_USER:-$(whoami)}"
GITHUB_USER="${GITHUB_USER:-PhilipMcGaw}"
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-https}" # 'https' for read-only, 'ssh' for developer

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

echo "======================================================================"
echo "  Robot CuttleOS One-Click Bootstrap"
echo "======================================================================"
echo "This script will:"
echo "  1. Install required system packages"
echo "  2. Clone robot-CuttleOS, Control, and Datalogger repositories"
echo "  3. Set up configuration files"
echo "  4. Run the complete provisioning"
echo "======================================================================"
echo ""

# Check if running as root (required for provisioning)
if [[ "${EUID}" -ne 0 ]]; then
  fail "This script must run as root for system package installation and service configuration. Run: sudo bash $0"
fi

# Detect operating system
if [[ "$(uname -s)" != "Linux" ]]; then
  fail "This script is for Linux/Raspberry Pi only. Detected: $(uname -s)"
fi

info "System: $(uname -m) $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
info "Target directory: $ROBOTS_DIR"
info "Runtime user: $ROBOT_USER"
info "Deployment mode: $DEPLOYMENT_MODE"
echo ""

# Install git if not available
if ! command -v git >/dev/null 2>&1; then
  info "Installing git..."
  apt-get update
  apt-get install -y git
else
  info "Git is already installed: $(git --version)"
fi

# Create robots directory
info "Creating robots directory: $ROBOTS_DIR"
mkdir -p "$ROBOTS_DIR"
cd "$ROBOTS_DIR"

# Clone repositories based on deployment mode
if [[ "$DEPLOYMENT_MODE" == "ssh" ]]; then
  info "Cloning repositories via SSH (developer mode)..."
  
  # Check for SSH key
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]] && [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
    warn "No SSH key found. Creating one..."
    ssh-keygen -t ed25519 -C "${ROBOT_USER}@robot" -f "$HOME/.ssh/id_ed25519" -N ""
    info "SSH key created. Add the public key to GitHub:"
    cat "$HOME/.ssh/id_ed25519.pub"
    read -p "Press Enter after adding the key to GitHub..."
  fi
  
  git clone git@github.com:${GITHUB_USER}/robot-CuttleOS.git robot-CuttleOS || fail "Failed to clone robot-CuttleOS"
  git clone git@github.com:${GITHUB_USER}/robot-Control.git control || fail "Failed to clone Control"
  git clone git@github.com:${GITHUB_USER}/robot-Datalogger.git datalogger || fail "Failed to clone Datalogger"
  
else
  info "Cloning repositories via HTTPS (read-only mode)..."
  git clone --depth=1 https://github.com/${GITHUB_USER}/robot-CuttleOS.git robot-CuttleOS || fail "Failed to clone robot-CuttleOS"
  git clone --depth=1 https://github.com/${GITHUB_USER}/robot-Control.git control || fail "Failed to clone Control"
  git clone --depth=1 https://github.com/${GITHUB_USER}/robot-Datalogger.git datalogger || fail "Failed to clone Datalogger"
fi

info "Repositories cloned successfully!"

# Set up configuration files
info "Setting up configuration files..."
cd "$ROBOTS_DIR/robot-CuttleOS"

# Copy example configs to actual configs
if [[ ! -f "configs/nats.env" ]]; then
  cp configs/nats.env.example configs/nats.env
  info "Created configs/nats.env from example"
fi

if [[ ! -f "configs/network.env" ]]; then
  cp configs/network.env.example configs/network.env
  info "Created configs/network.env from example"
fi

if [[ ! -f "configs/network.secrets.env" ]]; then
  cp configs/network.secrets.example configs/network.secrets.env
  chmod 600 configs/network.secrets.env
  warn "Created configs/network.secrets.env - EDIT THIS FILE WITH YOUR CREDENTIALS!"
fi

# Set robot profile
ROBOT_PROFILE="${ROBOT_PROFILE:-rov}"
info "Using robot profile: $ROBOT_PROFILE"

# Check if secrets file has been edited
if grep -q "CHANGE_ME" configs/network.secrets.env; then
  warn "======================================================================"
  warn "IMPORTANT: Edit configs/network.secrets.env with your credentials!"
  warn "The file contains placeholder values that must be changed."
  warn "======================================================================"
  warn "Current contents:"
  cat configs/network.secrets.env
  warn "======================================================================"
  read -p "Press Enter after editing the secrets file, or Ctrl+C to abort..."
fi

# Set environment variables for provisioning
export CONTROL_ROOT="$ROBOTS_DIR/control"
export DATALOGGER_ROOT="$ROBOTS_DIR/datalogger"
export ROBOT_PROFILE="$ROBOT_PROFILE"

# Run the provisioning script
info "Starting Raspberry Pi provisioning..."
info "This will take several minutes and requires internet access."
echo ""

bash scripts/0_provision_raspberry_pi.sh

info "======================================================================"
info "Bootstrap completed successfully!"
info "======================================================================"
info "Next steps:"
info "  1. Edit configuration files if needed"
info "  2. Reboot the system: sudo reboot"
info "  3. Access Cockpit at http://$(hostname -I | awk '{print $1}')"
info "======================================================================"
