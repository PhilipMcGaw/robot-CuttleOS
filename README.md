# robot-CuttleOS

A monorepo for robot control systems, supporting multiple robot types (ROV, K9) with a shared architecture.

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

### Cockpit (apps/cockpit)
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

### Setup
```bash
# Install dependencies
./scripts/1_install_dependencies.sh

# Build frontend
./scripts/build_frontend.sh

# Start the application
./scripts/2_start_app.sh
```

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

## License
See `docs/LICENSES.md` for license information.
