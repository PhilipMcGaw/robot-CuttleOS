#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${NETWORK_CONFIG:-$PROJECT_ROOT/configs/network.env}"
SECRETS_FILE="${NETWORK_SECRETS:-$PROJECT_ROOT/configs/network.secrets.env}"
COCKPIT_ROOT="${COCKPIT_ROOT:-$PROJECT_ROOT/../ROV---Cockpit}"
ROBOT_RUNTIME_USER="${ROBOT_RUNTIME_USER:-pi}"
DRY_RUN=false

usage() {
  printf 'Usage: sudo %s [--dry-run]\n' "$(basename "$0")"
}

log() { printf '[network] %s\n' "$*"; }
die() { printf '[network] ERROR: %s\n' "$*" >&2; exit 1; }
run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '[dry-run]'; printf ' %q' "$@"; printf '\n'
  else
    "$@"
  fi
}

for argument in "$@"; do
  case "$argument" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $argument" ;;
  esac
done

[[ "$(uname -s)" == Linux ]] || die 'this script supports Raspberry Pi/Linux only'
[[ "${EUID}" -eq 0 ]] || die 'run this deployment script with sudo'
command -v nmcli >/dev/null || die 'NetworkManager/nmcli is required; install it before running this script'
[[ -r "$CONFIG_FILE" ]] || die "missing network configuration: $CONFIG_FILE"
[[ -r "$SECRETS_FILE" ]] || die "missing network secrets file: $SECRETS_FILE"

# shellcheck disable=SC1090
source "$CONFIG_FILE"
# shellcheck disable=SC1090
source "$SECRETS_FILE"

: "${NETWORK_INTERFACE:?NETWORK_INTERFACE is required}"
: "${WIFI_INTERFACE:?WIFI_INTERFACE is required}"
: "${HOTSPOT_SSID:?HOTSPOT_SSID is required}"
: "${HOTSPOT_PASSWORD:?HOTSPOT_PASSWORD is required}"
: "${FALLBACK_ROBOT_ADDRESS:?FALLBACK_ROBOT_ADDRESS is required}"
: "${MEDIA_ROOT:?MEDIA_ROOT is required}"
: "${SMB_SHARE_NAME:?SMB_SHARE_NAME is required}"
: "${SMB_USER:?SMB_USER is required}"
: "${SMB_PASSWORD:?SMB_PASSWORD is required}"
: "${WIRED_CONNECTION_NAME:=robot-wired}"
: "${WIFI_CONNECTION_PREFIX:=robot-wifi}"
: "${HOTSPOT_CONNECTION_NAME:=robot-hotspot}"

if [[ ${WIFI_CLIENTS+x} != x ]]; then
  : "${WIFI_SSID:?WIFI_SSID is required when WIFI_CLIENTS is not set}"
  : "${WIFI_PASSWORD:?WIFI_PASSWORD is required when WIFI_CLIENTS is not set}"
  WIFI_CLIENTS=(legacy)
  WIFI_legacy_SSID="$WIFI_SSID"
  WIFI_legacy_PASSWORD="$WIFI_PASSWORD"
  WIFI_legacy_PRIORITY=100
fi
[[ "$(declare -p WIFI_CLIENTS 2>/dev/null)" == "declare -a"* ]] || die 'WIFI_CLIENTS must be a Bash array of client identifiers'
(( ${#WIFI_CLIENTS[@]} > 0 )) || die 'WIFI_CLIENTS must include at least one preferred Wi-Fi client'

[[ "$SECRETS_FILE" == "$PROJECT_ROOT"/* ]] || die 'secrets file must be within the Control project directory'
if [[ "$DRY_RUN" == false ]]; then
  permissions="$(stat -c '%a' "$SECRETS_FILE")"
  [[ "$permissions" == 600 || "$permissions" == 400 ]] || die "secrets file must have mode 600 or 400 (found $permissions)"
fi

if [[ "$DRY_RUN" == true ]]; then
  log 'would ensure NetworkManager is enabled and running before creating connection profiles'
else
  systemctl enable --now NetworkManager || die 'could not enable and start NetworkManager'
fi

nm_connection_exists() {
  [[ "$DRY_RUN" == true ]] && return 1
  nmcli -t -f NAME connection show | grep -Fxq "$1"
}
interface_exists() {
  [[ "$DRY_RUN" == true ]] && return 0
  nmcli -t -f DEVICE device status | grep -Fxq "$1"
}
configure_wifi_client() {
  local client="$1" ssid="$2" password="$3" priority="$4" connection_name
  [[ "$client" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "Wi-Fi client identifier is invalid: $client"
  [[ "$priority" =~ ^-?[0-9]+$ ]] || die "Wi-Fi client priority must be an integer: $client=$priority"
  connection_name="$WIFI_CONNECTION_PREFIX-$client"
  if nm_connection_exists "$connection_name"; then
    run nmcli connection modify "$connection_name" connection.interface-name "$WIFI_INTERFACE" 802-11-wireless.ssid "$ssid"
  else
    run nmcli connection add type wifi ifname "$WIFI_INTERFACE" con-name "$connection_name" ssid "$ssid"
  fi
  run nmcli connection modify "$connection_name" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$password" connection.autoconnect yes connection.autoconnect-priority "$priority" connection.autoconnect-retries 0 ipv4.method auto ipv6.method auto
}

log "deploying network configuration from $CONFIG_FILE"
log "wired interface: $NETWORK_INTERFACE; Wi-Fi interface: $WIFI_INTERFACE"
[[ "$DRY_RUN" == true ]] && log 'dry-run does not query live NetworkManager interfaces or existing profiles'
interface_exists "$NETWORK_INTERFACE" || die "wired interface is unavailable: $NETWORK_INTERFACE"
interface_exists "$WIFI_INTERFACE" || die "Wi-Fi interface is unavailable: $WIFI_INTERFACE"

for wifi_client in "${WIFI_CLIENTS[@]}"; do
  ssid_variable="WIFI_${wifi_client}_SSID"
  password_variable="WIFI_${wifi_client}_PASSWORD"
  priority_variable="WIFI_${wifi_client}_PRIORITY"
  ssid="${!ssid_variable:-}"
  password="${!password_variable:-}"
  priority="${!priority_variable:-100}"
  [[ -n "$ssid" ]] || die "missing SSID for Wi-Fi client: $wifi_client"
  [[ -n "$password" ]] || die "missing password for Wi-Fi client: $wifi_client"
  configure_wifi_client "$wifi_client" "$ssid" "$password" "$priority"
done

if nm_connection_exists "$HOTSPOT_CONNECTION_NAME"; then
  run nmcli connection modify "$HOTSPOT_CONNECTION_NAME" connection.interface-name "$WIFI_INTERFACE" 802-11-wireless.mode ap 802-11-wireless.ssid "$HOTSPOT_SSID" 802-11-wireless.channel "${HOTSPOT_CHANNEL:-6}" ipv4.method shared ipv4.addresses "$FALLBACK_ROBOT_ADDRESS" ipv6.method disabled 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$HOTSPOT_PASSWORD" connection.autoconnect yes connection.autoconnect-priority -100 connection.autoconnect-retries 0
else
  run nmcli connection add type wifi ifname "$WIFI_INTERFACE" con-name "$HOTSPOT_CONNECTION_NAME" ssid "$HOTSPOT_SSID"
  run nmcli connection modify "$HOTSPOT_CONNECTION_NAME" 802-11-wireless.mode ap 802-11-wireless.channel "${HOTSPOT_CHANNEL:-6}" ipv4.method shared ipv4.addresses "$FALLBACK_ROBOT_ADDRESS" ipv6.method disabled 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$HOTSPOT_PASSWORD" connection.autoconnect yes connection.autoconnect-priority -100 connection.autoconnect-retries 0
fi

if nm_connection_exists "$WIRED_CONNECTION_NAME"; then
  run nmcli connection modify "$WIRED_CONNECTION_NAME" connection.interface-name "$NETWORK_INTERFACE"
else
  run nmcli connection add type ethernet ifname "$NETWORK_INTERFACE" con-name "$WIRED_CONNECTION_NAME"
fi
run nmcli connection modify "$WIRED_CONNECTION_NAME" connection.autoconnect yes connection.autoconnect-priority 100 connection.autoconnect-retries 0

if [[ "$DRY_RUN" == false ]]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y avahi-daemon samba
  systemctl enable avahi-daemon
  systemctl restart avahi-daemon

  id "$SMB_USER" >/dev/null || die "SMB user does not exist: $SMB_USER"
  install -d -o "$SMB_USER" -g "$(id -gn "$SMB_USER")" -m 0750 "$MEDIA_ROOT/stills" "$MEDIA_ROOT/videos" "$MEDIA_ROOT/data/csv"
  [[ ! -f /etc/samba/smb.conf ]] || cp -a /etc/samba/smb.conf "/etc/samba/smb.conf.backup.$(date -u +%Y%m%dT%H%M%SZ)"
  cat > /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   server string = ${ROBOT_HOSTNAME:-robot}
   security = user
   map to guest = never
   interfaces = lo ${NETWORK_INTERFACE} ${WIFI_INTERFACE}
   bind interfaces only = yes
   min protocol = SMB2

[${SMB_SHARE_NAME}]
   path = ${MEDIA_ROOT}
   browseable = yes
   read only = no
   valid users = ${SMB_USER}
   force user = ${SMB_USER}
   create mask = 0640
   directory mask = 0750
EOF
  printf '%s\n' "$SMB_PASSWORD" | smbpasswd -s -a "$SMB_USER"
  smbpasswd -e "$SMB_USER"
  testparm -s >/dev/null
  systemctl enable smbd
  systemctl restart smbd
fi

if [[ -n "${ROBOT_HOSTNAME:-}" ]]; then
  run hostnamectl set-hostname "$ROBOT_HOSTNAME"
fi

if [[ "${WIRED_DHCP:-true}" == true ]]; then
  run nmcli connection modify "$WIRED_CONNECTION_NAME" ipv4.method auto ipv4.addresses '' ipv4.gateway '' ipv6.method auto
else
  : "${WIRED_STATIC_ADDRESS:?WIRED_STATIC_ADDRESS is required when WIRED_DHCP=false}"
  run nmcli connection modify "$WIRED_CONNECTION_NAME" ipv4.method manual ipv4.addresses "$WIRED_STATIC_ADDRESS" ipv4.gateway "${WIRED_GATEWAY:-}" ipv6.method disabled
fi

run nmcli connection reload
log 'network profiles deployed without restarting NetworkManager; preferred Wi-Fi clients have higher autoconnect priority than the hotspot fallback'
log 'existing active links are not forced down. Reboot, reconnect the link, or activate the reviewed profile with nmcli when an immediate address change is required.'
log 'verify with: nmcli connection show; nmcli device status'
