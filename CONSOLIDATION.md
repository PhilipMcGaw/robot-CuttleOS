# Monorepo Consolidation Summary

This document describes the consolidation of separate ROV repositories into a single monorepo structure.

## Changes Made

### Folder Structure

The three separate repositories have been consolidated into a single `robot-CuttleOS` monorepo:

**Before:**
```
cockpit/
control/
datalogger/
```

**After:**
```
cockpit/                    # Cockpit web application
├── cockpit/src/rov_cockpit/ # FastAPI application code
├── requirements.txt
└── run.sh

control/                    # Control service (hardware)
├── src/rov_control/        # Control application code
├── configs/                # Control-specific configurations
├── scripts/                # Control deployment scripts
├── tests/
├── requirements.txt
└── run.sh

datalogger/                 # Datalogger service (telemetry)
├── src/rov_datalogger/     # Datalogger application code
├── configs/                # Datalogger configurations
├── scripts/                # Datalogger deployment scripts
├── tests/
├── requirements.txt
└── run.sh
```

### Documentation

- Consolidated all shared documentation into top-level `docs/`
- Removed duplicate documentation from service folders
- Added hardware-specific docs from Control: `adeept-robot-hat-adm133*.md`, `hardware.md`, `nats.md`, `remote-ssh-access.md`
- Preserved service-specific `MASTER_CONTEXT.md` in each service folder for architecture details

### File Updates

The following files were updated to reference the new path structure:

#### Scripts
- `scripts/0_provision_raspberry_pi.sh` — updated CONTROL_ROOT and DATALOGGER_ROOT defaults
- `scripts/1_install_dependencies.sh` — updated COCKPIT_REQUIREMENTS path
- `scripts/2_start_app.sh` — updated COCKPIT_DIR path
- `scripts/2_start_app.bat` — updated COCKPIT_DIR path (Windows)
- `scripts/build_frontend.sh` — updated STATIC_DIR path
- `scripts/build_frontend.bat` — updated STATIC_DIR path (Windows)

#### Service Configuration
- `configs/cockpit.service` — updated ExecStart path
- `configs/nginx.conf` — updated static file alias path

#### Debug Configuration
- `robot-CuttleOS.code-workspace` — updated all debug launch paths

#### Tests
- Updated test paths in:
  - `tests/test_raspberry_pi_provisioning.py`
  - `tests/test_simulation_topics.py`
  - `tests/test_diagnostic_tray.py`
  - `tests/test_heading_tick_hierarchy.py`
  - `tests/test_k9_soundboard.py`
  - `tests/test_operator_shell.py`
  - `tests/test_operator_status.py`

#### Service Scripts
- `cockpit/run.sh` — updated COCKPIT_ROOT and MONOREPO_ROOT references
- `control/run.sh` — updated CONTROL_ROOT and MONOREPO_ROOT references
- `datalogger/run.sh` — updated DATALOGGER_ROOT and MONOREPO_ROOT references

## Development Workflow

### Local Development

Development setup remains the same, but now uses the consolidated structure:

```bash
# Install dependencies
./scripts/1_install_dependencies.sh

# Start all services
./scripts/2_start_app.sh

# Or start individual services from VS Code debug menu (F5)
# Configurations available:
#   - Python: Cockpit
#   - Python: Control
#   - Python: Datalogger
```

### Workspace Configuration

The VS Code workspace has been updated to reflect the new paths:
- Debug configs now point to `cockpit/src`, `control/src`, `datalogger/src`
- All path references use the new monorepo structure

## Deployment

### Provisioning

When provisioning a Raspberry Pi, the services are now located in:
- `~/robots/cockpit/`
- `~/robots/control/`
- `~/robots/datalogger/`

The provisioning script automatically finds and deploys all three services:

```bash
cd ~/robots/robot-CuttleOS
sudo bash scripts/0_provision_raspberry_pi.sh
```

Environment variables can override service locations if needed:
```bash
CONTROL_ROOT=/path/to/control DATALOGGER_ROOT=/path/to/datalogger \
  sudo bash scripts/0_provision_raspberry_pi.sh
```

### Systemd Units

Rendered systemd service files reference the new paths:
- `/etc/systemd/system/rov-cockpit.service` — executes `cockpit/run.sh`
- `/etc/systemd/system/rov-control.service` — executes `control/run.sh`
- `/etc/systemd/system/rov-datalogger.service` — executes `datalogger/run.sh`

## Benefits of Consolidation

1. **Single Repository** — No need to manage three separate repositories
2. **Simplified Cloning** — One `git clone` instead of three
3. **Unified Documentation** — Centralized docs reduce duplication and sync issues
4. **Easier Deployment** — All three services are co-located and provisioned together
5. **Atomic Updates** — Services can be updated together when needed
6. **Consistent Tooling** — Single workspace configuration for all services

## Migration Notes

- No git history was preserved during consolidation (as requested)
- All functionality remains the same
- Service boundaries and communication model (NATS) unchanged
- Configuration files and environment variables follow the same patterns

## Future Improvements

- Consider unified venv at monorepo root (currently per-service)
- Unified requirements.txt or Poetry lock file for all services
- Shared CI/CD pipeline for all services
- Unified logging configuration across services
