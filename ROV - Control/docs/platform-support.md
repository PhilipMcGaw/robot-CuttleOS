# Platform support

Control is a Raspberry Pi/Linux hardware service. Windows and macOS are useful
for source review, tests, and simulation, but they are not physical-control
targets.

| Capability | Windows | macOS | Raspberry Pi OS Trixie Lite 64-bit (`arm64`) |
|---|:---:|:---:|:---:|
| Source, profile, and documentation checks | Supported | Supported | Supported |
| NATS contract and mock/disconnected development | Supported where dependencies run | Supported where dependencies run | Supported |
| Canonical robot deployment | Not supported | Not supported | Target platform on Raspberry Pi 3B+ or newer; unbench-tested |
| GPIO, I2C, SPI, PWM, serial, camera, and HAT control | Not supported | Not supported | Target platform; requires hardware commissioning |
| NetworkManager, SMB, Avahi, NATS, and systemd deployment | Not supported | Not supported | Target platform; requires Raspberry Pi validation |

## Raspberry Pi baseline

The selected deployment baseline is **Raspberry Pi OS Trixie Lite 64-bit** on
the Raspberry Pi 3B+ and newer 64-bit Raspberry Pi models. The 3B+'s Cortex-A53
processor is 64-bit-capable. Lite is preferred because the robot Pi is
headless, and its 1 GB RAM must accommodate NATS, Control, Cockpit, Datalogger,
Nginx, Motion, and any enabled camera pipeline.

The provisioning script requires a Debian-based system with `apt-get`; it does
not yet enforce a Pi model, operating-system release, or CPU-architecture
check. The Pi 3B+ Trixie 64-bit combination is the target baseline, not yet
clean-image or hardware bench validation. Record the architecture, OS release,
RAM, package-install result, and hardware test evidence during first
commissioning.

Do not use Legacy 32-bit as the normal installation. It is a temporary,
documented fallback only if a required and verified dependency cannot run on
Trixie 64-bit. Record the blocker, the affected hardware capability, and the
migration plan. A 32-bit `armhf` image is not the project baseline.

Before provisioning, record:

```zsh
uname -m
cat /etc/os-release
getconf LONG_BIT
free -h
```

Expected baseline: `aarch64`, Raspberry Pi OS based on Debian Trixie, and
`64`. If a Pi 3B+ experiences memory pressure, reduce non-essential services
or camera resolution/bitrate before relaxing safety behaviour or adding swap as
a substitute for capacity.

## Platform rules

- Use the active profile and logical NATS commands in non-Pi development.
- Control alone owns physical mapping, sensor access, and actuator safety.
- Use stable Linux `/dev/serial/by-id/` paths only after device discovery and
  profile configuration.
- Do not run connected propulsion tests from a development workstation.
- Describe support as simulated, automated-test verified, bench-tested, or
  production-validated only with the corresponding evidence.
