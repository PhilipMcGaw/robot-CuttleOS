#!/usr/bin/env bash
set -Eeuo pipefail

# Robot Profile Switcher
# Switch between ROV, K9, and PiWars robot configurations

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$PROJECT_ROOT/configs/profiles"
ACTIVE_PROFILE="$PROJECT_ROOT/configs/profiles/active-profile.example.json"
SYSTEM_PROFILE="/etc/robot/profile.json"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

echo "======================================================================"
echo "  Robot Profile Switcher"
echo "======================================================================"

# Check if profiles directory exists
[[ -d "$PROFILES_DIR" ]] || fail "Profiles directory not found: $PROFILES_DIR"

# List available profiles
echo "Available robot profiles:"
echo ""
for profile in "$PROFILES_DIR"/*.json; do
  if [[ "$(basename "$profile")" != "active-profile.example.json" ]]; then
    profile_name=$(basename "$profile" .json)
    echo "  - $profile_name"
  fi
done
echo ""

# Get current profile
if [[ -f "$ACTIVE_PROFILE" ]]; then
  current_profile=$(cat "$ACTIVE_PROFILE" 2>/dev/null || echo "none")
  echo "Current active profile: $current_profile"
else
  echo "Current active profile: none"
fi
echo ""

# Check if profile argument provided
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <profile-name>"
  echo "Example: $0 rov"
  echo "         $0 k9"
  echo "         $0 piwars"
  exit 1
fi

TARGET_PROFILE="$1"
TARGET_PROFILE_FILE="$PROFILES_DIR/${TARGET_PROFILE}.json"

# Check if target profile exists
[[ -f "$TARGET_PROFILE_FILE" ]] || fail "Profile not found: $TARGET_PROFILE. Available profiles: rov, k9, piwars"

# Validate JSON
python3 -m json.tool "$TARGET_PROFILE_FILE" >/dev/null || fail "Profile file is not valid JSON: $TARGET_PROFILE_FILE"

info "Switching to profile: $TARGET_PROFILE"

# Update local active profile
echo "$TARGET_PROFILE" > "$ACTIVE_PROFILE"
info "Local active profile updated to: $TARGET_PROFILE"

# Update system profile if running as root
if [[ "${EUID}" -eq 0 ]]; then
  if [[ -f "$SYSTEM_PROFILE" ]]; then
    info "Updating system profile: $SYSTEM_PROFILE"
    cp "$TARGET_PROFILE_FILE" "$SYSTEM_PROFILE"
    info "System profile updated. Restart services to apply changes:"
    echo "  sudo systemctl restart cockpit"
    echo "  sudo systemctl restart control"
    echo "  sudo systemctl restart datalogger"
  else
    warn "System profile not found at $SYSTEM_PROFILE. Robot may not be fully provisioned."
  fi
else
  warn "Not running as root. System profile not updated. Run with sudo to update system profile."
  warn "To apply changes, run: sudo $0 $TARGET_PROFILE"
fi

echo ""
echo "======================================================================"
info "Profile switched to: $TARGET_PROFILE"
echo "======================================================================"
info "Local configuration updated."
if [[ "${EUID}" -eq 0 ]]; then
  info "System configuration updated. Restart services to apply changes."
else
  warn "Run with sudo to update system configuration."
fi
echo "======================================================================"
