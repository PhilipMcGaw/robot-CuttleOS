# Platform support

Cockpit development is portable, whereas robot deployment depends on Raspberry
Pi/Linux hardware and the configured camera, network, and service stack.

| Capability | Windows | macOS | Raspberry Pi OS Trixie Lite 64-bit (`arm64`) |
|---|:---:|:---:|:---:|
| Cockpit UI and simulator | Supported by the documented launcher | Supported by the documented launcher | Supported |
| NATS-backed Cockpit service | Supported where dependencies run | Supported where dependencies run | Supported |
| Camera UI/configuration | UI supported; local Motion is not expected | UI supported; local Motion is not expected | Target platform; physical camera operation requires validation |
| Canonical robot deployment | Not supported | Not supported | Target platform on Raspberry Pi 3B+ or newer; unbench-tested |
| GPIO, I2C, SPI, PWM, serial, and HAT hardware | Not supported | Not supported | Control-owned target platform; requires commissioning |

## Raspberry Pi baseline

The selected deployment baseline is **Raspberry Pi OS Trixie Lite 64-bit** on
the Raspberry Pi 3B+ and newer 64-bit Raspberry Pi models. Cockpit runs on the
robot Pi and the operator uses a separate browser, so the Lite image is
preferred over the desktop image to preserve the Pi 3B+'s 1 GB RAM for NATS,
Nginx, Motion, and the robot services.

The Pi 3B+ is supported by Raspberry Pi OS 64-bit because it has a 64-bit
Cortex-A53 processor. The current project has not yet been clean-image or
hardware bench-tested on that model, so this is a deployment target rather than
production-validation evidence.

Do not choose Legacy 32-bit as the normal installation. Use it only as a
documented temporary compatibility fallback when a required, verified hardware
dependency cannot run on Trixie 64-bit. Record the reason, affected dependency,
and follow-up migration work; it is not the supported project baseline.

Before provisioning, record:

```zsh
uname -m
cat /etc/os-release
getconf LONG_BIT
free -h
```

Expected baseline: `aarch64`, Raspberry Pi OS based on Debian Trixie, and
`64`. On a Pi 3B+, investigate excessive Motion/video resolution or bitrate
before adding more services if memory pressure occurs.

## Browser Gamepad API

The Cockpit gamepad page uses the standard Browser Gamepad API. Pair the
controller in the operating system before opening Cockpit. Test with propulsion
disabled; browser input is not the only safety mechanism. Control owns
dead-man, neutral-on-disconnect, arming, timeout, and output safety behaviour.

For local development, serve Cockpit from `localhost` or `127.0.0.1`. Use HTTPS
when Cockpit is reachable beyond a trusted local network. Browser support and
authentication details are maintained in the Cockpit development documentation.

## Platform rules

- Use the relevant component's launcher and declared script interpreter.
- Use mocks or the Cockpit simulator for non-Pi development.
- Keep physical mapping out of Cockpit; Control owns hardware access and
  profile validation.
- Describe a platform as simulated, automated-test verified, bench-tested, or
  production-validated only with the corresponding evidence.
