# Raspberry Pi deployment

Control is deployed beside Cockpit and Datalogger on the robot. The canonical installer is Cockpit's `scripts/0_provision_raspberry_pi.sh`; it renders this repository's systemd unit with the real checkout path and runtime account. It does not require `/home/pi/ROV---Control`.

## Initial robot provisioning

Use Cockpit's [source-installation route](https://github.com/PhilipMcGaw/ROV---Cockpit/blob/main/docs/deployment.md#choose-a-source-installation-route)
to retrieve Cockpit, Control, and Datalogger as sibling repositories. It
provides a read-only HTTPS route for normal robot installations and a
Pi-specific GitHub SSH route for Philip's developer pull/push work. Before
running the Cockpit provisioner, create the ignored Control configuration
files:

```zsh
cd ~/robots/ROV---Control
cp configs/network.env.example configs/network.env
cp configs/network.secrets.example configs/network.secrets.env
cp configs/nats.env.example configs/nats.env
chmod 600 configs/network.secrets.env
```

Set every `replace-me` value before provisioning. The Cockpit provisioner installs Debian dependencies, Control's virtual environment, NATS, the rendered `python.service`, the shared robot profile, network configuration, SMB, Avahi, and the sibling services. It must run as `root`; Cockpit's `docs/deployment.md` is the complete installation guide.

For a Control-only development environment, run the project-local dependency installer as the normal user:

```zsh
./scripts/1_install_dependencies.sh
```

This does not install or configure system services.

## Start the application

```zsh
./scripts/2_start_app.sh
```

On Windows use `scripts\\2_start_app.bat`. On macOS, or on Linux without deployed systemd units, the shell script starts the local development service. On a deployed Raspberry Pi it restarts the rendered `python` unit; restarting it may interrupt safe robot operation.

## Services and NATS

The provisioner installs `configs/python.service` as a template, rendering `@ROBOT_USER@` and `@CONTROL_ROOT@`. It supplies the authenticated loopback NATS URL through the root-readable `/etc/robot/nats.env` environment file and grants only `CAP_SYS_TIME` for browser-assisted time synchronisation.

NATS binds to `127.0.0.1:4222` by default and requires the `NATS_USERNAME` and `NATS_PASSWORD` defined in the ignored secrets file. Set `NATS_REMOTE_ACCESS=true` in the ignored `configs/nats.env` only for an explicitly trusted HiL/SiL network. This opens the authenticated NATS listener on robot network interfaces; the monitoring endpoint remains loopback-only.

After a safe update to the rendered Control unit:

```zsh
sudo systemctl daemon-reload
sudo systemctl restart python
sudo systemctl status python --no-pager
```

`python` is the installed Control unit name. Do not restart it while propulsion hardware can move.

## Browser-assisted clock synchronisation

The installed `python.service` grants Control `CAP_SYS_TIME` through `CapabilityBoundingSet` and `AmbientCapabilities`. This permits Control alone to apply a validated browser time message for an RPi without an RTC; Cockpit and the browser have no Linux clock-setting capability.

The active profile at `/etc/robot/profile.json` must enable the `time_synchronisation` contract. The feature is implemented but not Raspberry Pi bench-tested and is not a replacement for trusted NTP.

## Network deployment

Control owns the Raspberry Pi NetworkManager deployment. `scripts/0_deploy_network.sh` is invoked by the Cockpit provisioner after it installs `network-manager`, `dnsmasq-base`, Avahi, Samba, and the Cockpit media directories. It can also be run independently on a reviewed robot.

After creating and reviewing the ignored configuration files during initial provisioning, rerun the network deployment with:

```zsh
sudo scripts/0_deploy_network.sh --dry-run
sudo scripts/0_deploy_network.sh
```

`--dry-run` validates the configuration-file contract and prints the intended
profile changes without querying existing NetworkManager profiles or interfaces.
The real deployment verifies both interfaces and must be run on the robot.

The script starts NetworkManager before it creates or updates a named wired profile, rather than assuming that a NetworkManager connection name equals the interface name. It does not restart NetworkManager after changing profiles, so it does not intentionally drop the SSH connection used for deployment. A reboot, link reconnect, or an explicit reviewed `nmcli connection up` is required to apply an address change immediately. Wired operation is either DHCP (`WIRED_DHCP=true`) or a deliberately selected static address (`WIRED_DHCP=false`); it does not claim automatic wired DHCP-to-static failover or run a wired DHCP server. Do not use the wireless-hotspot subnet for a wired static interface while the hotspot can be active.

`network.secrets.env` supports one or more preferred Wi-Fi client profiles. Define each identifier in the `WIFI_CLIENTS` Bash array and provide matching `WIFI_<identifier>_SSID`, `WIFI_<identifier>_PASSWORD`, and optional `WIFI_<identifier>_PRIORITY` values. The highest-priority profile is preferred. The legacy single `WIFI_SSID`/`WIFI_PASSWORD` form remains accepted for an existing installation.

The hotspot is a lower-priority auto-connect profile. It uses `192.168.42.1/24`, with NetworkManager shared IPv4 mode supplying DHCP and local DNS to connected clients. The `.42` choice is intentional: it references *The Hitchhiker's Guide to the Galaxy* and was selected because this private range is not used elsewhere in the current environment. It remains a convention rather than a guarantee of conflict-free use. The configuration prefers known Wi-Fi before the hotspot, but physical failover, reconnection, and multi-adapter behaviour remain Raspberry Pi bench-test work.

The deployment creates the Cockpit `stills/`, `videos/`, and `data/csv/` directories if needed, configures an authenticated writable SMB `media` share for the chosen runtime account, and enables Avahi. SMB permissions permit upload as well as read/delete because SMB deletion requires write authority; do not enable guest access or expose this share outside trusted robot networks.

## First checks

```zsh
systemctl status nats-server python cockpit datalogger nginx motion --no-pager
nmcli device status
avahi-browse --all --terminate
curl http://127.0.0.1/
```

Use an authenticated NATS client URL from `/etc/robot/nats.env` for broker diagnostics. Do not copy credentials into shell history, shared documentation, or Git.
