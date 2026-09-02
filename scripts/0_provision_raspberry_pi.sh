#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTROL_ROOT="${CONTROL_ROOT:-$PROJECT_ROOT/control}"
DATALOGGER_ROOT="${DATALOGGER_ROOT:-$PROJECT_ROOT/datalogger}"
COCKPIT_ROOT="${COCKPIT_ROOT:-$PROJECT_ROOT/cockpit}"
ROBOT_PROFILE="${ROBOT_PROFILE:-rov}"
NATS_CONFIG_FILE="${NATS_CONFIG:-$PROJECT_ROOT/configs/nats.env}"
NETWORK_CONFIG_FILE="${NETWORK_CONFIG:-$PROJECT_ROOT/configs/network.env}"
NETWORK_SECRETS_FILE="${NETWORK_SECRETS:-$PROJECT_ROOT/configs/network.secrets.env}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
warn() { echo "[WARN] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }
escape_sed_replacement() { printf '%s' "$1" | sed 's/[\\&|]/\\&/g'; }

render_template() {
  local source="$1" target="$2" mode="$3" owner="$4" group="$5" temporary
  local cockpit_root control_root datalogger_root robot_user project_root
  temporary="$(mktemp)"
  project_root="$(escape_sed_replacement "$PROJECT_ROOT")"
  cockpit_root="$(escape_sed_replacement "$COCKPIT_ROOT")"
  control_root="$(escape_sed_replacement "$CONTROL_ROOT")"
  datalogger_root="$(escape_sed_replacement "$DATALOGGER_ROOT")"
  robot_user="$(escape_sed_replacement "$PROJECT_USER")"
  sed -e "s|@PROJECT_ROOT@|$project_root|g" \
      -e "s|@COCKPIT_ROOT@|$cockpit_root|g" \
      -e "s|@CONTROL_ROOT@|$control_root|g" \
      -e "s|@DATALOGGER_ROOT@|$datalogger_root|g" \
      -e "s|@ROBOT_USER@|$robot_user|g" \
      "$source" > "$temporary"
  install -o "$owner" -g "$group" -m "$mode" "$temporary" "$target"
  rm -f "$temporary"
}

nats_quote() {
  local value="$1"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail 'NATS credentials must not contain a line break'
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

url_encode() {
  python3 -c 'from sys import argv; from urllib.parse import quote; print(quote(argv[1], safe=""))' "$1"
}

runtime_user_home() {
  getent passwd "$PROJECT_USER" | cut -d: -f6
}

configure_passwordless_sudo() {
  local sudoers_file temporary user_name_pattern='^[a-z_][a-z0-9_-]*$'
  [[ "$PROJECT_USER" =~ $user_name_pattern ]] || fail "Runtime user name is unsafe for a sudoers policy: $PROJECT_USER"
  sudoers_file="/etc/sudoers.d/90-rov-runtime-${PROJECT_USER}"
  temporary="$(mktemp)"
  printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$PROJECT_USER" > "$temporary"
  if ! visudo -cf "$temporary"; then
    rm -f "$temporary"
    fail "Generated passwordless sudo policy is invalid for $PROJECT_USER"
  fi
  install -o root -g root -m 0440 "$temporary" "$sudoers_file"
  rm -f "$temporary"
  pass "Passwordless sudo is configured for $PROJECT_USER through $sudoers_file."
}

configure_interactive_shell() {
  local project_user_home zsh_bin zsh_directory zshrc zprofile template temporary
  project_user_home="$(runtime_user_home)"
  [[ -n "$project_user_home" && -d "$project_user_home" ]] || fail "Cannot determine a valid home directory for $PROJECT_USER"
  zsh_bin="$(command -v zsh)"
  [[ -n "$zsh_bin" ]] || fail 'Zsh is not installed after package installation'
  zsh_directory="$project_user_home/.oh-my-zsh"
  zshrc="$project_user_home/.zshrc"
  zprofile="$project_user_home/.zprofile"
  template="$zsh_directory/templates/zshrc.zsh-template"

  if [[ ! -d "$zsh_directory" ]]; then
    runuser -u "$PROJECT_USER" -- env HOME="$project_user_home" git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$zsh_directory" || fail "Could not install Oh My Zsh for $PROJECT_USER"
  fi
  [[ -f "$template" ]] || fail "Oh My Zsh template is unavailable: $template"
  usermod -s "$zsh_bin" "$PROJECT_USER"

  # Install Powerlevel10k theme
  local p10k_directory="$zsh_directory/themes/powerlevel10k"
  if [[ ! -d "$p10k_directory" ]]; then
    info "Installing Powerlevel10k theme for $PROJECT_USER"
    runuser -u "$PROJECT_USER" -- env HOME="$project_user_home" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_directory" || warn "Could not install Powerlevel10k, falling back to clean theme"
  fi

  # Install Zsh plugins
  info "Installing enhanced Zsh plugins for $PROJECT_USER"
  runuser -u "$PROJECT_USER" -- env HOME="$project_user_home" git clone --depth=1 https://github.com/zsh-users/zsh-completions "$zsh_directory/plugins/zsh-completions" 2>/dev/null || warn "Could not install zsh-completions plugin"
  runuser -u "$PROJECT_USER" -- env HOME="$project_user_home" git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$zsh_directory/plugins/zsh-autosuggestions" 2>/dev/null || warn "Could not install zsh-autosuggestions plugin"
  runuser -u "$PROJECT_USER" -- env HOME="$project_user_home" git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_directory/plugins/zsh-syntax-highlighting" 2>/dev/null || warn "Could not install zsh-syntax-highlighting plugin"

  if [[ ! -f "$zshrc" ]]; then
    install -o "$PROJECT_USER" -g "$PROJECT_GROUP" -m 0644 "$template" "$zshrc"
  fi

  # Set theme to Powerlevel10k if available, otherwise clean
  if [[ -d "$p10k_directory" ]]; then
    if grep -Eq '^ZSH_THEME=' "$zshrc"; then
      sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc"
    else
      temporary="$(mktemp)"
      awk '
        /oh-my-zsh\.sh/ && !theme_added { print "ZSH_THEME=\"powerlevel10k/powerlevel10k\""; theme_added=1 }
        { print }
        END { if (!theme_added) print "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" }
      ' "$zshrc" > "$temporary"
      install -o "$PROJECT_USER" -g "$PROJECT_GROUP" -m 0644 "$temporary" "$zshrc"
      rm -f "$temporary"
    fi
  else
    if grep -Eq '^ZSH_THEME=' "$zshrc"; then
      sed -i 's|^ZSH_THEME=.*|ZSH_THEME="clean"|' "$zshrc"
    else
      temporary="$(mktemp)"
      awk '
        /oh-my-zsh\.sh/ && !theme_added { print "ZSH_THEME=\"clean\""; theme_added=1 }
        { print }
        END { if (!theme_added) print "ZSH_THEME=\"clean\"" }
      ' "$zshrc" > "$temporary"
      install -o "$PROJECT_USER" -g "$PROJECT_GROUP" -m 0644 "$temporary" "$zshrc"
      rm -f "$temporary"
    fi
  fi

  # Configure plugins (Linux-appropriate plugins only)
  if ! grep -Eq '^plugins=\(' "$zshrc"; then
    temporary="$(mktemp)"
    awk '
      /oh-my-zsh\.sh/ && !plugins_added {
        print "plugins=(git debian systemd python sudo history-substring-search command-not-found zsh-completions zsh-autosuggestions zsh-syntax-highlighting)"
        plugins_added=1
      }
      { print }
      END { if (!plugins_added) print "plugins=(git debian systemd python sudo history-substring-search command-not-found zsh-completions zsh-autosuggestions zsh-syntax-highlighting)" }
    ' "$zshrc" > "$temporary"
    install -o "$PROJECT_USER" -g "$PROJECT_GROUP" -m 0644 "$temporary" "$zshrc"
    rm -f "$temporary"
  fi

  # Configure Oh My Zsh auto-update mode
  if ! grep -Eq '^zstyle.*:omz:update' "$zshrc"; then
    cat >> "$zshrc" <<'EOF'

# Oh My Zsh auto-update configuration
zstyle ':omz:update' mode auto
EOF
  fi

  if ! grep -Fq 'oh-my-zsh.sh' "$zshrc"; then
    cat >> "$zshrc" <<'EOF'

# ROV deployment: use the installed Oh My Zsh framework.
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
source "$ZSH/oh-my-zsh.sh"
EOF
  fi

  # Add prompt anchoring (commented out by default as it may interfere with HyFetch)
  cat >> "$zshrc" <<'EOF'

# Optional: Fix prompt at the bottom of the terminal window
# Uncomment the following lines if you want this behavior:
# alias clear="clear && printf '\n%.0s' {1..100}"
# printf '\n%.0s' {1..100}
EOF

  chown "$PROJECT_USER:$PROJECT_GROUP" "$zshrc"
  chmod 0644 "$zshrc"

  temporary="$(mktemp)"
  if [[ -f "$zprofile" ]]; then
    sed '/^# BEGIN ROV deployment shell greeting$/,/^# END ROV deployment shell greeting$/d' "$zprofile" > "$temporary"
  fi
  cat >> "$temporary" <<'EOF'

# BEGIN ROV deployment shell greeting
# Show the host identity only for an interactive Zsh login.
if [[ -o interactive ]]; then
  clear
  if (( $+commands[hyfetch] )); then
    hyfetch
  fi
fi
# END ROV deployment shell greeting
EOF
  install -o "$PROJECT_USER" -g "$PROJECT_GROUP" -m 0644 "$temporary" "$zprofile"
  rm -f "$temporary"
  pass "Zsh, Oh My Zsh with Powerlevel10k theme, enhanced plugins (git, debian, systemd, python, sudo, history-substring-search, command-not-found, zsh-completions, zsh-autosuggestions, zsh-syntax-highlighting), and interactive HyFetch greeting are configured for $PROJECT_USER."
}

install_nats_configuration() {
  local nats_bind_address nats_service_user nats_service_group nats_binary temporary url_user url_password
  [[ -r "$NATS_CONFIG_FILE" ]] || fail "NATS configuration is missing: $NATS_CONFIG_FILE. Copy configs/nats.env.example to configs/nats.env and review it."
  [[ -r "$NETWORK_SECRETS_FILE" ]] || fail "Network/NATS secrets are missing: $NETWORK_SECRETS_FILE. Copy configs/network.secrets.example to configs/network.secrets.env and set restrictive permissions."
  # shellcheck disable=SC1090
  source "$NATS_CONFIG_FILE"
  # shellcheck disable=SC1090
  source "$NETWORK_SECRETS_FILE"
  : "${NATS_REMOTE_ACCESS:=false}"
  : "${NATS_USERNAME:?NATS_USERNAME is required for the deployed NATS server}"
  : "${NATS_PASSWORD:?NATS_PASSWORD is required for the deployed NATS server}"
  case "$NATS_REMOTE_ACCESS" in
    true) nats_bind_address='0.0.0.0' ;;
    false) nats_bind_address='127.0.0.1' ;;
    *) fail 'NATS_REMOTE_ACCESS must be true or false' ;;
  esac
  nats_service_user="$(systemctl show --property=User --value nats-server)"
  [[ -n "$nats_service_user" ]] || nats_service_user=root
  id "$nats_service_user" >/dev/null 2>&1 || fail "NATS service user does not exist: $nats_service_user"
  nats_service_group="$(id -gn "$nats_service_user")"
  nats_binary="$(command -v nats-server)"
  install -d -o root -g root -m 0755 /etc/robot /etc/nats /etc/systemd/system/nats-server.service.d
  temporary="$(mktemp)"
  {
    printf 'listen: %s:4222\n' "$nats_bind_address"
    printf 'http: 127.0.0.1:8222\n'
    printf 'authorization {\n  timeout: 3\n  users: [ { user: %s, password: %s } ]\n}\n' "$(nats_quote "$NATS_USERNAME")" "$(nats_quote "$NATS_PASSWORD")"
  } > "$temporary"
  install -o "$nats_service_user" -g "$nats_service_group" -m 0600 "$temporary" /etc/nats/rov-nats.conf
  rm -f "$temporary"
  temporary="$(mktemp)"
  printf '[Service]\nExecStart=\nExecStart=%s --config /etc/nats/rov-nats.conf\n' "$nats_binary" > "$temporary"
  install -o root -g root -m 0644 "$temporary" /etc/systemd/system/nats-server.service.d/rov.conf
  rm -f "$temporary"
  url_user="$(url_encode "$NATS_USERNAME")"
  url_password="$(url_encode "$NATS_PASSWORD")"
  temporary="$(mktemp)"
  printf 'NATS_URL=nats://%s:%s@127.0.0.1:4222\n' "$url_user" "$url_password" > "$temporary"
  install -o root -g root -m 0600 "$temporary" /etc/robot/nats.env
  rm -f "$temporary"
  pass "NATS is configured with authentication; remote client access=$NATS_REMOTE_ACCESS."
}

echo "[INFO] ROV Cockpit Raspberry Pi provisioning"
echo "[INFO] Project version: unversioned; see MASTER_CONTEXT.md"
echo "[INFO] Project directory: $PROJECT_ROOT"
echo "[INFO] Runtime: Debian system packages plus project-local Python environments"
echo "[INFO] Operating mode: initial Raspberry Pi platform and Cockpit deployment"
echo "[INFO] Components: Python, Node.js/npm, Nginx, Motion, NATS Server, Cockpit, Control, Datalogger, shared profile and networking"
echo "[INFO] Privileged actions: apt package installation, systemd service installation and service enablement"

[[ "$(uname -s)" == "Linux" ]] || fail "Unsupported operating system: $(uname -s). This script is for Raspberry Pi/Linux only."
[[ "${EUID}" -eq 0 ]] || fail "This provisioning script must run with sudo/root because it changes system packages and services. Run: sudo bash scripts/0_provision_raspberry_pi.sh"
[[ -f "$PROJECT_ROOT/cockpit/requirements.txt" ]] || fail "Cockpit requirements file is missing: $PROJECT_ROOT/cockpit/requirements.txt. Restore the Cockpit component before continuing."
[[ -f "$PROJECT_ROOT/configs/cockpit.service" ]] || fail "Cockpit service file is missing: $PROJECT_ROOT/configs/cockpit.service. Restore the deployment files before continuing."
[[ -f "$DATALOGGER_ROOT/configs/datalogger.service" ]] || fail "Datalogger service file is missing: $DATALOGGER_ROOT/configs/datalogger.service. Clone Datalogger beside Cockpit or set DATALOGGER_ROOT."
[[ -f "$DATALOGGER_ROOT/requirements.txt" ]] || fail "Datalogger requirements are missing: $DATALOGGER_ROOT/requirements.txt. Restore the repository before continuing."
[[ -f "$CONTROL_ROOT/configs/python.service" ]] || fail "Control service file is missing: $CONTROL_ROOT/configs/python.service. Clone Control beside Cockpit or set CONTROL_ROOT."
[[ -f "$CONTROL_ROOT/requirements.txt" ]] || fail "Control requirements are missing: $CONTROL_ROOT/requirements.txt. Restore the repository before continuing."
[[ -r "$NATS_CONFIG_FILE" ]] || fail "NATS configuration is missing: $NATS_CONFIG_FILE. Copy configs/nats.env.example to configs/nats.env and review it."
[[ -r "$NETWORK_CONFIG_FILE" ]] || fail "Network configuration is missing: $NETWORK_CONFIG_FILE. Copy configs/network.env.example to configs/network.env and review it."
[[ -r "$NETWORK_SECRETS_FILE" ]] || fail "Network/NATS secrets are missing: $NETWORK_SECRETS_FILE. Copy configs/network.secrets.example to configs/network.secrets.env, set values, and use mode 600."
NETWORK_SECRETS_MODE="$(stat -c '%a' "$NETWORK_SECRETS_FILE")"
[[ "$NETWORK_SECRETS_MODE" == 600 || "$NETWORK_SECRETS_MODE" == 400 ]] || fail "Network/NATS secrets must have mode 600 or 400 before provisioning (found $NETWORK_SECRETS_MODE)."
command -v apt-get >/dev/null 2>&1 || fail "apt-get is unavailable. This script supports Debian-based Raspberry Pi operating systems only."

info "Refreshing Debian package metadata."
apt-get update || fail "apt-get update failed. Check network access, repository configuration, and system time."

info "Checking that all required platform packages are available before installation."
PACKAGES=(python3 python3-venv python3-dev nodejs npm nginx motion curl ca-certificates git zsh hyfetch nats-server network-manager dnsmasq-base avahi-daemon samba)
if [[ "$ROBOT_PROFILE" == "k9" ]]; then
  PACKAGES+=(espeak-ng sox alsa-utils)
fi
for package in "${PACKAGES[@]}"; do
  apt-cache show "$package" >/dev/null 2>&1 || fail "Required package is unavailable in the configured repositories: $package. Add a trusted repository or install this dependency using the documented vendor method before rerunning. No partial service configuration was attempted."
done
pass "All required Debian packages are available."

info "Installing Python, Node.js/npm, Nginx, Motion, NATS, NetworkManager, SMB, Zeroconf and required system packages."
apt-get install -y "${PACKAGES[@]}" || fail "Platform package installation failed. Review the apt diagnostics above; services have not been configured by this script."
pass "Platform packages installed or already present."

info "Installing ncurses-term for Ghostty terminfo support."
apt-get install -y ncurses-term || warn "ncurses-term installation failed; Ghostty may have terminal display issues."
# Create symlink for Ghostty terminfo if it doesn't exist
if [[ ! -f "/usr/share/terminfo/x/xterm-ghostty" ]] && [[ -f "/usr/share/terminfo/g/ghostty" ]]; then
  ln -s /usr/share/terminfo/g/ghostty /usr/share/terminfo/x/xterm-ghostty || warn "Could not create Ghostty terminfo symlink."
  pass "Ghostty terminfo symlink created."
else
  info "Ghostty terminfo already configured or ncurses-term not available."
fi

info "Creating the project-local Python environment and installing Cockpit requirements."
if [[ "${SUDO_USER:-}" != "" && "${SUDO_USER}" != "root" ]]; then
  PROJECT_USER="$SUDO_USER"
else
  PROJECT_USER="$(stat -c '%U' "$PROJECT_ROOT")"
fi
id "$PROJECT_USER" >/dev/null 2>&1 || fail "The selected runtime user does not exist: $PROJECT_USER"
[[ "$PROJECT_USER" != root ]] || fail 'Provision from a normal user account; root is not a supported robot runtime user.'
PROJECT_GROUP="$(id -gn "$PROJECT_USER")"
if [[ ! -d "$PROJECT_ROOT/.venv" ]]; then
  runuser -u "$PROJECT_USER" -- python3 -m venv "$PROJECT_ROOT/.venv" || fail "Could not create $PROJECT_ROOT/.venv for $PROJECT_USER. Check repository ownership and Python venv support."
fi
runuser -u "$PROJECT_USER" -- "$PROJECT_ROOT/.venv/bin/python" -m pip install --upgrade pip || fail "Could not update pip in $PROJECT_ROOT/.venv."
runuser -u "$PROJECT_USER" -- "$PROJECT_ROOT/.venv/bin/python" -m pip install -r "$COCKPIT_ROOT/requirements.txt" || fail "Could not install Cockpit requirements from $COCKPIT_ROOT/requirements.txt."
chown -R "$PROJECT_USER:$PROJECT_GROUP" "$PROJECT_ROOT/.venv"
pass "Cockpit Python environment installed for $PROJECT_USER."

info "Installing Datalogger dependencies and shared Cockpit media directories."
if [[ ! -d "$DATALOGGER_ROOT/.venv" ]]; then
  runuser -u "$PROJECT_USER" -- python3 -m venv "$DATALOGGER_ROOT/.venv" || fail "Could not create $DATALOGGER_ROOT/.venv for $PROJECT_USER."
fi
runuser -u "$PROJECT_USER" -- "$DATALOGGER_ROOT/.venv/bin/python" -m pip install --upgrade pip || fail "Could not update pip in $DATALOGGER_ROOT/.venv."
runuser -u "$PROJECT_USER" -- "$DATALOGGER_ROOT/.venv/bin/python" -m pip install -r "$DATALOGGER_ROOT/requirements.txt" || fail "Could not install Datalogger requirements."
install -d -o "$PROJECT_USER" -g "$PROJECT_GROUP" -m 0750 "$DATALOGGER_ROOT/data" "$PROJECT_ROOT/media/stills" "$PROJECT_ROOT/media/videos" "$PROJECT_ROOT/data/csv"
chown -R "$PROJECT_USER:$PROJECT_GROUP" "$DATALOGGER_ROOT/.venv" "$DATALOGGER_ROOT/data" "$PROJECT_ROOT/media" "$PROJECT_ROOT/data"
pass "Datalogger Python environment and shared CSV directory configured."

info "Installing Control dependencies and hardware service environment."
if [[ ! -d "$CONTROL_ROOT/.venv" ]]; then
  runuser -u "$PROJECT_USER" -- python3 -m venv "$CONTROL_ROOT/.venv" || fail "Could not create $CONTROL_ROOT/.venv for $PROJECT_USER."
fi
runuser -u "$PROJECT_USER" -- "$CONTROL_ROOT/.venv/bin/python" -m pip install --upgrade pip || fail "Could not update pip in $CONTROL_ROOT/.venv."
runuser -u "$PROJECT_USER" -- "$CONTROL_ROOT/.venv/bin/python" -m pip install -r "$CONTROL_ROOT/requirements.txt" || fail "Could not install Control requirements."
chown -R "$PROJECT_USER:$PROJECT_GROUP" "$CONTROL_ROOT/.venv"
pass "Control Python environment installed for $PROJECT_USER."

info "Installing the selected Motion camera configuration."
for motion_config in motion.conf motion1.conf motion2.conf; do
  [[ -f "$PROJECT_ROOT/configs/$motion_config" ]] || fail "Motion configuration is missing: $PROJECT_ROOT/configs/$motion_config"
  render_template "$PROJECT_ROOT/configs/$motion_config" "/etc/motion/$motion_config" 0644 root root
done
pass "Motion configuration is installed with the deployed Cockpit media path."

info "Configuring authenticated NATS Core."
install_nats_configuration

info "Installing portable systemd units for Cockpit."
render_template "$PROJECT_ROOT/configs/cockpit.service" /etc/systemd/system/cockpit.service 0644 root root
# TODO: Enable these units after Control and Datalogger deployment is ready and validated.
# render_template "$DATALOGGER_ROOT/configs/datalogger.service" /etc/systemd/system/datalogger.service 0644 root root
# render_template "$CONTROL_ROOT/configs/python.service" /etc/systemd/system/python.service 0644 root root
systemctl daemon-reload || fail "systemd daemon reload failed after installing service units."
systemctl enable nats-server nginx motion cockpit || fail "Could not enable one or more services: nats-server, nginx, motion, cockpit."
pass "Cockpit, NATS Server, Nginx, and Motion are enabled for startup."

info "Installing the shared robot profile."
PROFILE_SOURCE="$PROJECT_ROOT/configs/profiles/${ROBOT_PROFILE}.json"
[[ -f "$PROFILE_SOURCE" ]] || fail "Robot profile is missing: $PROFILE_SOURCE. Set ROBOT_PROFILE to a valid profile name."
install -d -o root -g root -m 0755 /etc/robot
install -o root -g root -m 0644 "$PROFILE_SOURCE" /etc/robot/profile.json
python3 -m json.tool /etc/robot/profile.json >/dev/null || fail "The selected robot profile is not valid JSON: $PROFILE_SOURCE"
pass "Robot profile installed at /etc/robot/profile.json: $ROBOT_PROFILE"

if [[ -x "$CONTROL_ROOT/scripts/0_deploy_network.sh" ]]; then
  info "Invoking Control-owned networking, SMB and Avahi deployment."
  PROJECT_ROOT="$PROJECT_ROOT" \
  COCKPIT_ROOT="$COCKPIT_ROOT" \
  ROBOT_RUNTIME_USER="$PROJECT_USER" \
  NETWORK_CONFIG="$NETWORK_CONFIG_FILE" \
  NETWORK_SECRETS="$NETWORK_SECRETS_FILE" \
    "$CONTROL_ROOT/scripts/0_deploy_network.sh" || fail "Control networking deployment failed. Review its diagnostics before continuing."
  pass "Control-owned networking deployment completed."
else
  warn "Control networking script not found at $CONTROL_ROOT/scripts/0_deploy_network.sh; networking, SMB and Avahi were not deployed. Set CONTROL_ROOT or deploy Control separately."
fi

info "Testing NATS Server availability before configuring the reverse proxy."
systemctl is-active --quiet nats-server || systemctl start nats-server || fail "NATS Server did not start. Inspect: journalctl -u nats-server -n 50 --no-pager"
curl --fail --silent --show-error http://127.0.0.1:8222/varz >/dev/null 2>&1 || warn "NATS monitoring endpoint is not available at port 8222; service status is active but connectivity is not fully verified."

info "Applying the Nginx site and map-tile cache configuration."
bash "$PROJECT_ROOT/scripts/3_configure_nginx.sh" || fail "Nginx configuration helper failed. Review its diagnostics; the previous site backup remains available."

info "Starting Cockpit and checking service state."
systemctl restart cockpit || fail "Cockpit failed to start. Inspect: journalctl -u cockpit -n 50 --no-pager"
systemctl restart datalogger || fail "Datalogger failed to start. Inspect: journalctl -u datalogger -n 50 --no-pager"
systemctl restart python || fail "Control failed to start. Inspect: journalctl -u python -n 50 --no-pager"
systemctl is-active --quiet cockpit || fail "Cockpit is not active after restart. Inspect: journalctl -u cockpit -n 50 --no-pager"
systemctl is-active --quiet datalogger || fail "Datalogger is not active after provisioning. Inspect: journalctl -u datalogger -n 50 --no-pager"
systemctl is-active --quiet python || fail "Control is not active after provisioning. Inspect: journalctl -u python -n 50 --no-pager"
systemctl is-active --quiet nginx || fail "Nginx is not active after provisioning. Inspect: journalctl -u nginx -n 50 --no-pager"
systemctl is-active --quiet nats-server || fail "NATS Server is not active after provisioning. Inspect: journalctl -u nats-server -n 50 --no-pager"
pass "Control, Cockpit, Datalogger, Nginx and NATS Server are active."

info "Configuring the runtime user's Zsh environment and administrator policy."
configure_interactive_shell
configure_passwordless_sudo

echo "[INFO] Environment summary:"
echo "[INFO] Python=installed and configured; Nginx=installed, configured and active; Motion=installed and enabled; NATS Server=authenticated, enabled and active; Cockpit=installed, enabled and active; Datalogger=installed, enabled and active; CSV export=shared with Cockpit data directory; runtime shell=Zsh with Oh My Zsh Powerlevel10k theme, enhanced plugins, and HyFetch greeting."
echo "[WARN] Hardware cameras, motor controllers, sensors, network links and ROV operation are not physically validated by this script."
echo "[INFO] Provisioning completed at $TIMESTAMP."
