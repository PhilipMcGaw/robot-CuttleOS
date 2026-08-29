# ROV Control current status

## Architecture

The Control service is a separate Linux/Raspberry Pi Python process. It drives hardware and exchanges the NATS Core contract with other ROV services. It must remain independent of the Cockpit web process.

## Implemented behaviour

- Python control-service entry point under `src/rov_control/main.py`.
- NATS-based command and telemetry boundary as described in the NATS documentation and the master context.
- Profile-driven browser-assisted clock synchronisation: Control validates the NATS message against the active profile and can call Linux `time.clock_settime` when its systemd service has `CAP_SYS_TIME`.
- The Cockpit canonical provisioner renders `configs/python.service` for the actual Control checkout and runtime user, grants only `CAP_SYS_TIME`, generates authenticated NATS configuration, and invokes `scripts/0_deploy_network.sh` with the ignored network configuration.
- `scripts/0_deploy_network.sh` supports named wired profiles, one or more prioritised Wi-Fi clients, a lower-priority `192.168.42.1/24` hotspot profile, authenticated SMB media sharing, hostname configuration, and Avahi enablement.

## Automated-test verification

The documentation currency audit is implemented in `tests/test_documentation.py` and runs without application dependencies. `tests/test_time_synchronisation.py` verifies profile-subject and message validation without hardware. The historical files under `tests/legacy/` are not an automated acceptance suite.

## Bench-tested and Production-validated status

The repository does not currently record physical propulsion, GPIO, serial-board, sensor, clock-synchronisation, or production deployment validation. These statuses require explicit evidence and must not be inferred from source-code presence.

## Planned or unverified

- Full automated control-loop and hardware-abstraction test coverage.
- A shared Adeept Robot HAT ADM133 (V3.3 family) hardware adapter for K9 and
  PiWars. Profiles will define channel assignments and safe operating
  configuration after the installed-board map is confirmed; no physical
  behaviour has been bench-validated. The port-interface guide records
  manufacturer V3 sample mappings and Philip's board observations separately
  from mappings awaiting board-level verification.
- Stable ADM133 `servo-00` through `servo-15` aliases and K9's semantic
  `head-pan`/`head-tilt` profile allocations. The configuration contract is
  automated-test verified; the physical wiring, motor-sharing behaviour, and
  servo behaviour remain unbench-tested.
- Bench validation of command limits, neutral, timeout, emergency-stop, and camera-pitch feedback.
- Production validation on the intended Raspberry Pi and attached hardware.
- Raspberry Pi bench validation of browser-assisted time synchronisation and the deployed `CAP_SYS_TIME` service capability.
- Raspberry Pi 3B+ Trixie Lite 64-bit bench validation of the NATS systemd override, NetworkManager Wi-Fi/hotspot failover, SMB sharing, and the complete provisioning sequence.
- Per-robot SSH access for active-task remote verification. The least-privilege procedure is documented, but no `codex` account, SSH key, remote connection, or automated remote check has been configured or validated on a robot.

## Important references

- `MASTER_CONTEXT.md`
- `docs/documentation-policy.md`
- `docs/nats.md`
- `docs/hardware.md`
- `docs/testing.md`
- `src/rov_control/main.py`
- `src/rov_control/time_sync.py`
- `configs/python.service`
- `scripts/0_deploy_network.sh`
- `run.sh`
- `scripts/1_install_dependencies.bat`
- `scripts/2_start_app.bat`
