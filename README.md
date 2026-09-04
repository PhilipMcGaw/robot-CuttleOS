# robot-CuttleOS

[![Code: PolyForm Noncommercial 1.0.0](LICENSE-POLYFORM-NonCommercial-1.0.0.txt)]
[![Documentation: CC BY-NC-SA 4.0](LICENSE-CC-BY-NC-SA-4.0.txt)]
[![Raspberry Pi](https://img.shields.io/badge/Hardware-Raspberry_Pi-c51a4a.svg)](https://www.raspberrypi.com/)
[![Python](https://img.shields.io/badge/Language-Python-3776ab.svg)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/Web-FastAPI-009688.svg)](https://fastapi.tiangolo.com/)
[![Vue.js](https://img.shields.io/badge/Frontend-Vue.js-42b883.svg)](https://vuejs.org/)
[![NATS](https://img.shields.io/badge/Messaging-NATS-27aae1.svg)](https://nats.io/)

<p align="center">
  <img src="cockpit/src/rov_cockpit/static/android-chrome-512x512.png" alt="CuttleOS project icon" width="220">
</p>

CuttleOS is the robot-side software stack for Raspberry Pi-based robots. It provides the shared Cockpit, Control and Datalogger services for the ROV, K9 and future robot profiles.

## Robots project

CuttleOS is one part of a related set of projects. Cross-project architecture, engineering rationale, significant decisions, reusable guidance, deployment and commissioning procedures, hardware documentation references, operational knowledge, and the overall roadmap are maintained in [Chartroom](https://chartroom.philipmcgaw.com/).

- [Chartroom](https://chartroom.philipmcgaw.com/) — central engineering knowledge base and cross-project documentation.
- [SquidLink](https://github.com/PhilipMcGaw/robot-SquidLink) — independent ROV software-in-the-loop and hardware-in-the-loop environment using ROS 2, Gazebo, and the same application-facing NATS contracts.
- [NautiPi](https://github.com/PhilipMcGaw/robot-NautiPi) — physical hardware, electronics, PCB designs, embedded projects, and associated hardware reference material.

The relationship is deliberately straightforward: CuttleOS runs the real robot software, SquidLink provides simulation and integration testing, NautiPi contains the physical hardware and embedded-project material, and Chartroom records the cross-project engineering context and operational knowledge. They are separate projects with defined interfaces rather than one shared codebase.

## Documentation standard

Project-wide documentation conventions are defined by the [Robots Project Documentation Standard](https://chartroom.philipmcgaw.com/development/documentation-standard/), maintained in Chartroom. CuttleOS follows that standard; it does not maintain a separate copy of the project-wide documentation rules.

## Demo

I have a demo of my Robot Cockpit 🙂 https://cuttleos.philipmcgaw.com/

## People who have helped

- Philip 'Skippy' McGaw - <philip@mcgaw.eu> - [philipmcgaw.com](https://philipmcgaw.com)
- Tamarisk 'NotQuiteHere' McGaw - <tamarisk@mcgaw.eu> - [tamarisk.it](https://tamarisk.it)
- Bob 'thinkl33t' Clough - <bob@clough.me> - [thinkl33t.co.uk](https://thinkl33t.co.uk)

## Architecture

This project uses a monorepo structure with the following layout:

```
robot-CuttleOS/
├── cockpit/           # FastAPI web service and static browser assets
├── control/           # Hardware-facing control service
├── datalogger/        # NATS telemetry logger
├── frontend/          # Frontend source and build configuration
│   └── cockpit/
├── assets/            # Version-controlled shared and robot assets
├── configs/           # Configuration files
│   ├── robots/        # Robot-specific configs (rov.yaml, k9.yaml)
│   └── profiles/      # Cockpit profiles
├── tests/             # Test suites
├── scripts/           # Build and deployment scripts
├── docs/              # Implementation-specific documentation
├── data/              # Runtime data (CSV logs, etc.)
└── media/             # Media files (stills, videos)
```

## Components

### Cockpit (cockpit/)
FastAPI-based web application providing:
- Browser-based operator interface
- WebSocket telemetry streaming
- Low-latency live video and media presentation
- Mono and planned stereo camera support
- Local video and still recording/download management
- Optional live and recorded audio
- Authentication and role-based access
- Configuration UI
- Gamepad/operator input support
- Capability-driven UI adaptation for different robot profiles

### Media architecture

CuttleOS treats camera acquisition, recording, live transport, and presentation as separate concerns. Stereo video is a common capability for robots such as K9 and ROV rather than a K9-specific implementation.

```text
Camera / microphone
        │
        ├──► Local recorder ──► Vehicle storage
        │          │
        │          └──► video + audio master
        │
        └──► Live media service ──► WebRTC ──► Operator / Quest

NATS telemetry + control logs ──► Datalogger
             │
             └──► timestamp-aligned export / subtitles
```

Local recording is independent of the operator connection. Live video is on-demand, so a robot with zero viewers does not need to send live video over its network link. WebRTC is the preferred live transport where low latency is important, particularly for K9 operation over a mobile network. Live quality must be adaptive and must not starve safety-critical control or telemetry.

The master recording preserves native stereo where available. Telemetry and control remain authoritative in their raw NATS/logging forms; presentation formats such as WebVTT subtitles or rendered overlays are derived outputs. Video, audio, telemetry, and control events should share a common time reference.

K9's planned media capability includes a USB microphone for live environmental awareness, microphone audio in saved recordings, and a low-latency audio return path to the robot speaker/soundboard. K9 also has planned dedicated high-capacity local storage, while ROV storage remains an optional discovered capability.

### Frontend
TypeScript frontend source is under `frontend/src/`, with the npm package and toolchain under `frontend/cockpit/`. The compiled browser modules are emitted to `cockpit/src/rov_cockpit/static/dist/`.

### Configuration
- Robot definitions in `configs/robots/`
- Cockpit profiles in `configs/profiles/`
- Service configurations in `configs/`

## Getting Started

### Robot deployment

For the complete project-level procedure for deploying and commissioning a robot, including Raspberry Pi Imager, first-boot provisioning, deployment readiness, and bench validation, follow the [Raspberry Pi deployment procedure in Chartroom](https://chartroom.philipmcgaw.com/development/raspberry-pi-deployment/).

CuttleOS contains the implementation used by that procedure. Its provisioning scripts are the source of truth for CuttleOS-specific package installation, configuration, service units, and first-boot behaviour.

### CuttleOS implementation provisioning

For implementation-level provisioning details, see [`docs/deployment.md`](docs/deployment.md). The bootstrap script can also retrieve and provision CuttleOS on an existing Linux system:

```bash
curl -fsSL https://raw.githubusercontent.com/PhilipMcGaw/robot-CuttleOS/main/scripts/bootstrap_robot.sh | sudo bash
```

Set options in the environment before invoking the script, for example:

```bash
sudo ROBOT_PROFILE=k9 ROBOTS_DIR=/home/philip/robots bash scripts/bootstrap_robot.sh
```

The commands in this section describe the CuttleOS implementation. They are not the complete robot deployment procedure.

### Manual Setup

For local development or manual deployment:

```bash
# Install dependencies
./scripts/1_install_dependencies.sh

# Build frontend
./scripts/build_frontend.sh

# Start the application
./scripts/2_start_app.sh
```

### Raspberry Pi Provisioning

For implementation-level Raspberry Pi provisioning:

```bash
# Run the provisioning script (requires sudo)
sudo ./scripts/0_provision_rpi.sh
```

This installs the CuttleOS system packages, Python environments, services, and configuration. Use the [Chartroom deployment procedure](https://chartroom.philipmcgaw.com/development/raspberry-pi-deployment/) for the complete deployment and commissioning sequence.

### Robot Profile Switching

Switch between different robot configurations (ROV, K9, PiWars, Testbot):

```bash
# Switch to ROV profile
sudo ./scripts/switch_robot_profile.sh rov

# Switch to K9 profile
sudo ./scripts/switch_robot_profile.sh k9

# Switch to PiWars profile
sudo ./scripts/switch_robot_profile.sh piwars

# Switch to the small-robot bench-test profile
sudo ./scripts/switch_robot_profile.sh testbot
```

Switching to K9 automatically checks and installs `espeak-ng` and `sox`; shared `alsa-utils` support is installed for all robot profiles.

Available profiles: `rov`, `k9`, `piwars`, `testbot`

### Robot Types
- **ROV**: Underwater robot with depth, heading, drive, camera, lights, and planned stereo/media capabilities
- **K9**: Ground robot with drive, camera, head, lights, and planned stereo/audio/media capabilities
- **Testbot**: Small-robot profile for safe RPi bench testing, with drive and basic power/network telemetry

## Technology Stack
- **Backend**: Python, FastAPI, NATS
- **Frontend**: TypeScript, Vue.js
- **Configuration**: YAML/TOML
- **Validation**: Pydantic
- **Live media**: WebRTC planned for low-latency video/audio

## Documentation

This repository contains implementation-specific documentation for CuttleOS and its services. For cross-project architecture, engineering decisions, deployment and commissioning procedures, hardware documentation references, reusable guidance, operational knowledge, and the overall roadmap, see [Chartroom](https://chartroom.philipmcgaw.com/).

See `docs/` for detailed implementation documentation.
See `MASTER_CONTEXT.md` for architectural decisions and service boundaries.
See `ROADMAP.md` for planned architectural improvements and feature development.
See `docs/status.md` for implementation and validation status.
See `docs/robot-profile-requirements.md` for profile and capability contracts.

## License
See `LICENSES.md` for license information.
