# robot-CuttleOS

A monorepo for robot control systems, supporting multiple robot types (ROV, K9) with a shared architecture.

CuttleOS is part of the SquidLink, CuttleOS, and NautiPi set

    The operating system, this name combines “Cuttlefish” (a clever cephalopod) with “OS” (operating system), giving it a futuristic yet natural feel.

The other two names are
1. SquidLink  (For your main control software or Raspberry Pi) - https://github.com/PhilipMcGaw/robot-SquidLink

    A sleek, tech-sounding-name that implies connectivity and agility—perfect for a robotics control system.


3. NautiPi (For your secondary device or backup system) - https://github.com/PhilipMcGaw/robot-NautiPi

    A nod to the “Nautilus” (the shell of a nautilus, another cephalopod relative) and “Raspberry Pi,” making it a fun and functional name.

Why These Work Together:

    Thematic Unity: All three names tie into cephalopods and technology.
    Clear Roles: Each name suggests a different component (software, PCB/OS, and device).
    Memorable: They’re short, catchy, and easy to remember.

## Demo

I have a demo of my Robot Cockpit 🙂 https://cuttleos.philipmcgaw.com/


 * need the generator script to correct font location /assets/webfonts/
 * replace background image with https://www.youtube.com/watch?v=4Gz9FJzXeb8 (need to correctly give cc/licence etc) can the video be on loop?

## Architecture

This project uses a monorepo structure with the following layout:

```
robot-CuttleOS/
├── cockpit/           # FastAPI web service and static browser assets
├── control/           # Hardware-facing control service
├── datalogger/        # NATS telemetry logger
├── frontend/          # Frontend source and build configuration
│   └── cockpit/
├── configs/           # Configuration files
│   ├── robots/        # Robot-specific configs (rov.yaml, k9.yaml)
│   └── profiles/      # Cockpit profiles
├── tests/             # Test suites
├── scripts/           # Build and deployment scripts
├── docs/              # Documentation
├── data/              # Runtime data (CSV logs, etc.)
└── media/             # Media files (stills, videos)
```

## Components

### Cockpit (cockpit/)
FastAPI-based web application providing:
- Browser-based operator interface
- WebSocket telemetry streaming
- Camera management
- Authentication
- Configuration UI

### Frontend (frontend/cockpit)
TypeScript/Vue.js frontend for the cockpit interface.

### Configuration
- Robot definitions in `configs/robots/`
- Cockpit profiles in `configs/profiles/`
- Service configurations in `configs/`

## Getting Started

### Quick Start (One-Click Setup)

For complete robot deployment on a Raspberry Pi, follow [the deployment guide](docs/deployment.md).
The bootstrap script requires root privileges:

```bash
curl -fsSL https://raw.githubusercontent.com/PhilipMcGaw/robot-CuttleOS/main/scripts/bootstrap_robot.sh | sudo bash
```

Set options in the environment before invoking the script, for example:

```bash
sudo ROBOT_PROFILE=k9 ROBOTS_DIR=/home/philip/robots bash scripts/bootstrap_robot.sh
```

See `ONE-LINE-SETUP.txt` for complete one-liner reference and `QUICKSTART.txt` for detailed setup instructions.

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

### Raspberry Pi Deployment

For manual Raspberry Pi provisioning:

```bash
# Run the provisioning script (requires sudo)
sudo ./scripts/0_provision_raspberry_pi.sh
```

This installs all system packages, Python environments, services, and configuration.

### Robot Profile Switching

Switch between different robot configurations (ROV, K9, PiWars):

```bash
# Switch to ROV profile
sudo ./scripts/switch_robot_profile.sh rov

# Switch to K9 profile
sudo ./scripts/switch_robot_profile.sh k9

# Switch to PiWars profile
sudo ./scripts/switch_robot_profile.sh piwars
```

Available profiles: `rov`, `k9`, `piwars`

### Robot Types
- **ROV**: Underwater robot with depth, heading, drive, camera, lights
- **K9**: Ground robot with drive, camera, head, lights

## Technology Stack
- **Backend**: Python, FastAPI, NATS
- **Frontend**: TypeScript, Vue.js
- **Configuration**: YAML/TOML
- **Validation**: Pydantic

## Documentation
See `docs/` for detailed documentation on development, deployment, and testing.
See `ROADMAP.md` for planned architectural improvements and feature development.

## License
See `LICENSES.md` for license information.
