# robot-CuttleOS

A monorepo for robot control systems, supporting multiple robot types (ROV, K9) with a shared architecture.

CuttleOS is part of the SquidLink, CuttleOS, and NautiPi set

    The operating system, this name combines “Cuttlefish” (a clever cephalopod) with “OS” (operating system), giving it a futuristic yet natural feel.

The other two names are
1. SquidLink  (For your main control software or Raspberry Pi)

    A sleek, tech-sounding-name that implies connectivity and agility—perfect for a robotics control system.


3. NautiPi (For your secondary device or backup system)

    A nod to the “Nautilus” (the shell of a nautilus, another cephalopod relative) and “Raspberry Pi,” making it a fun and functional name.

Why These Work Together:

    Thematic Unity: All three names tie into cephalopods and technology.
    Clear Roles: Each name suggests a different component (software, PCB/OS, and device).
    Memorable: They’re short, catchy, and easy to remember.


## Architecture

This project uses a monorepo structure with the following layout:

```
robot-CuttleOS/
├── apps/              # Application services
│   └── cockpit/       # FastAPI/Vue web UI for robot control
├── packages/          # Shared libraries
│   ├── messages/      # NATS message schemas
│   ├── robot/         # Robot abstractions
│   ├── hardware/      # Hardware interfaces
│   └── common/        # Shared utilities
├── frontend/          # Frontend applications
│   └── cockpit/       # Vue.js cockpit frontend
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

For complete robot deployment on a Raspberry Pi, use the one-line bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/PhilipMcGaw/robot-CuttleOS/main/scripts/bootstrap_robot.sh | bash
```

**Available Options:**
- **Developer mode** (SSH access): `DEPLOYMENT_MODE=ssh bash`
- **K9 robot**: `ROBOT_PROFILE=k9 bash`
- **Custom directory**: `ROBOTS_DIR=/path/to/dir bash`

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
