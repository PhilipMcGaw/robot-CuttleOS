# robot-CuttleOS — Master Context

> **Role:** Persistent architectural and engineering context for humans and AI
> assistants working on robot-CuttleOS (the consolidated monorepo).
>
> **Authority:** Current code and physical bench evidence > current status and
> roadmap > this file > older documentation and chat recollection.
>
> **Maintenance:** Update this file whenever a significant architectural
> decision, validated behaviour, deployment mechanism, safety boundary, release
> milestone, or roadmap priority changes.
>
> **Status discipline:** Never describe designed, simulated, expected, or
> software-tested behaviour as physically or production validated.

---

## Overview

robot-CuttleOS is a consolidated monorepo containing three co-installed services
for remotely operated and mobile robots:

1. **Cockpit** — Browser-based operator interface (web application, FastAPI)
2. **Control** — Hardware-facing control and safety (motor/actuator control, sensors)
3. **Datalogger** — Telemetry recording and CSV export (SQLite-backed logging)

All three services run on a single Raspberry Pi inside the robot and communicate
via NATS Core (message broker). The operator connects to Cockpit via a standard
web browser.

---

## Part I: Cockpit (Operator Interface)

### 1. Cockpit purpose

Cockpit is a browser-based operator interface for remotely operated and
mobile robots.

Cockpit runs **on the Raspberry Pi installed inside the robot**. The operator
connects to Cockpit using a web browser.

The canonical Raspberry Pi provisioner also establishes the normal robot
runtime user's interactive environment: Zsh, Oh My Zsh's `clean` theme, and an
interactive HyFetch greeting. It deliberately grants that runtime user
passwordless `sudo` through a separately validated `/etc/sudoers.d` policy.
This is appropriate only for a trusted robot or development host, not a
general-purpose multi-user or Internet-exposed Linux host.

Firefox is the preferred operator browser. Chromium-based browsers and Safari
should also remain supported.

The architecture is intended to support different robot types without requiring
substantial changes to the generic Cockpit application.

The initial robot profiles are:

- ROV;
- K9;
- PiWars.

Cockpit is intended to emulate many of the useful operator-interface and
customisation capabilities demonstrated by Blue Robotics Cockpit, while using
this project's own architecture, communications model, safety boundaries, and
offline-first deployment.

Blue Robotics Cockpit is a **design and UX reference only**. Its underlying
communications architecture and dependencies are not requirements for this
project.

**MAVLink is not used.**

### 2. Cockpit: Fundamental deployment model

The fundamental production model is:

> **One robot → one Raspberry Pi → one Cockpit → one operator browser
> connection.**

The Raspberry Pi lives physically inside the robot.

Cockpit is not normally installed on the operator's computer in production.
The operator connects to the Cockpit instance running on the robot.

The production architecture is:

```text
Robot
└── Raspberry Pi
    ├── Cockpit
    ├── Control
    ├── Datalogger
    ├── NATS Core
    ├── Nginx
    └── Camera / media services
```

The operator communicates with Cockpit through HTTP, WebSocket, and browser
video mechanisms as appropriate.

The browser does not communicate directly with NATS or physical hardware.

---

## Part II: Control (Hardware Service)

### Purpose

ROV Control is the hardware-facing control service for the robot.

It runs on the Raspberry Pi installed in the robot and is responsible for:

- receiving logical actuator demands;
- applying robot-profile configuration;
- performing actuator/motor mixing;
- enforcing physical limits;
- enforcing neutral and command timeouts;
- implementing software safety behaviour;
- communicating with distributed hardware;
- reading sensors and hardware status;
- publishing telemetry;
- managing the robot's network configuration and connectivity.

Control is deliberately separate from Cockpit. A web, browser, media, authentication, database, or visualisation problem must not directly stop or destabilise the hardware-control path.

The production target is **real Raspberry Pi hardware first**. Simulation and HiL/SiL support are secondary and must not compromise the production hardware architecture.

### Control architecture

The robot contains a Raspberry Pi running the principal robot services:

```text
Raspberry Pi
│
├── ROV Control
│     ├── safety
│     ├── command handling
│     ├── actuator mixing
│     ├── hardware drivers
│     ├── sensor handling
│     └── network management
│
├── ROV Cockpit
│     └── operator-facing web application
│
└── ROV Datalogger
      └── telemetry recording
```

Control is the robot's motor and safety controller. It owns:

- command reception and validation;
- robot-profile-based configuration;
- actuator mixing and control law;
- physical safety limits and timeouts;
- hardware driver implementation;
- sensor polling and status publication;
- network configuration and connectivity;
- emergency-stop and neutral behaviour.

Control receives commands only through NATS, never directly from the browser.
The Cockpit web application is not a safety-critical path; Control has
independent safety mechanisms.

---

## Part III: Datalogger (Telemetry Service)

### Purpose

The Datalogger is part of the shared multi-robot framework. Each robot uses a
distinct NATS namespace and has one active, Git-versioned JSON robot profile
on its Raspberry Pi. The Datalogger records the subjects produced by that robot
without changing commands or applying Control-side actuator mappings. Profile
and namespace changes require corresponding documentation and test updates.

The Datalogger is co-installed with Cockpit and Control on the robot Raspberry
Pi and communicates with both through NATS Core. It observes and records the
agreed message subjects; it must not intercept, modify, delay, or become a
dependency for control messages.

### Datalogger behavior

The Datalogger subscribes to NATS Core and records a message to SQLite only
when its payload differs from the last recorded value for that subject. Changes
include their UTC timestamp, subject, raw payload, text representation, and
normalised JSON where valid. Repeated identical values are ignored, including
after restart. It provides a foundation for CSV export and later reporting. It
does not control the ROV or provide a web UI.

Configuration is supplied through:
- `NATS_URL` — NATS broker address
- `NATS_SUBJECT` — subscription filter
- `DATALOGGER_DATABASE` — SQLite database path
- `DATALOGGER_RETENTION_DAYS` — retention period (default: 30 days)
- `DATALOGGER_EXPORT_DIR` — CSV export directory

On an installed robot, the provisioned unit sets these values and imports the
authenticated `NATS_URL` from `/etc/robot/nats.env`; local development may set
them directly.

---

## Shared Architecture

### Fundamental architecture

The three services are independent, communicate only through NATS Core, and run
on the same Raspberry Pi:

```text
Browser
  │
  │ HTTP / WebSocket
  ▼
Cockpit (operator interface)
  │
  │ NATS Core
  ▼
┌─────────────┬─────────────┐
│             │             │
▼             ▼             ▼
Control    Datalogger    Other services
(hardware) (telemetry)
```

**Key principle:** Service isolation. Cockpit web failure ≠ motor failure.
Database crash ≠ control loss.

### NATS Core messaging

- Selected internal messaging middleware
- Subject naming: `<namespace>.<category>.<type>.<field>`
  - Example: `rov.telemetry.power.battery.voltage`
- Default dev: `nats://127.0.0.1:4222`
- Production: authenticated loopback from `/etc/robot/nats.env`
- **JetStream explicitly out of scope**
- **Browser never talks NATS directly** (Cockpit WebSocket relays only)

### Robot profiles

Robot-specific behavior is defined through validated JSON profiles:

- Location: `configs/profiles/{rov|k9|piwars}.json`
- Defines NATS namespace, telemetry mappings, command mappings, gamepad config, camera streams, enabled features
- Allows same Cockpit/Control/Datalogger code to run on different robot types without changes
- Changes require corresponding documentation and test updates

### Operating system and platforms

**Production target:**
> **Raspberry Pi OS Trixie Lite 64-bit** (`arm64`) on Raspberry Pi 3B+ or newer

**Development platforms:** Windows, macOS, Linux

**Browser preferences:**
1. Firefox (primary)
2. Chromium-based browsers
3. Safari

---

## Deployment

### Provisioning

The canonical Raspberry Pi provisioner is Cockpit's `scripts/0_provision_raspberry_pi.sh`.
It:

- Installs Python, Node.js, Nginx, Motion, NATS, NetworkManager, Avahi, Samba
- Creates virtual environments for all three services
- Creates shared directories (stills/, videos/, data/csv/)
- Renders systemd units with actual checkout paths
- Renders Nginx config with actual checkout paths
- Enables systemd services
- Configures network (NetworkManager, DHCP, hotspot)

Deployment structure:

```text
/etc/robot/
├── profile.json                # Active robot profile
├── nats.env                    # NATS credentials (restricted)
├── camera.json                 # Camera config
└── users.json                  # Auth hashes

/etc/systemd/system/
├── rov-cockpit.service         # Cockpit daemon
├── rov-control.service         # Control daemon
└── rov-datalogger.service      # Datalogger daemon
```

### Service locations (monorepo)

```text
~/robots/robot-CuttleOS/
├── cockpit/                    # Cockpit web application
│   ├── src/rov_cockpit/
│   ├── configs/
│   ├── scripts/
│   └── ...
├── control/                    # Control service
│   ├── src/rov_control/
│   ├── configs/
│   ├── scripts/
│   └── ...
├── datalogger/                 # Datalogger service
│   ├── src/rov_datalogger/
│   ├── configs/
│   ├── scripts/
│   └── ...
├── scripts/                    # Monorepo-level scripts
└── docs/                       # Consolidated documentation
```

---

## Development & Testing

### Testing stages (in order)

1. **Static checks** — Python syntax, compile KiCad
2. **NATS & web smoke test** — HTTP routes, WebSocket, offline state
3. **Serial protocol test** — malformed payloads, reconnect
4. **Sensor test** — units, raw vs display, leak detection
5. **Actuator bench test** — thrusters disconnected, range limits
6. **Dry integration test** — full stack, no water
7. **Wet test** — seals, shallow tether, leak monitoring

### Engineering principles

1. **Separate intent from hardware** — operator says "set light level", not "toggle GPIO"
2. **Hardware independence** — config-driven mapping, no hardcoded COM/paths
3. **Mock-first development** — safe mocks for all hardware
4. **Units first** — every telemetry value has explicit unit and scale
5. **Honest validation status** — "simulated" vs "bench-tested" vs "production-proven"
6. **Reproducibility** — record software rev, hardware rev, config, test conditions
7. **Safety before convenience** — web config NOT the only motor safety

---

## Status discipline

- **Never describe designed/simulated/software-tested as physically/production validated**
- Use evidence hierarchy: code > status & roadmap > documentation > chat recollection
- Update this file when architectural decisions change

---

## Todo Tree plugin integration

**Requirement:** This project uses the VS Code **Better Todo Tree** extension
to track and visualize TODO, FIXME, and other priority tags across the codebase.

### Formatting standard for TODOs and future roadmap items

All TODO and FIXME comments must follow this format to be recognized by Better Todo Tree:

```
# TODO: Brief description of what needs to be done
// TODO: Another example (JavaScript/TypeScript)
// FIXME: Bug or issue that needs fixing
// NOTE: Important note or consideration
// HACK: Quick fix that needs refactoring
```

**Format rules:**
- Use a comment marker appropriate to the file language (`#`, `//`, `--`, etc.)
- Space between marker and tag: `# TODO:` (not `#TODO:`)
- Space after tag: `TODO: description` (not `TODO:description`)
- Keep descriptions concise (one line preferred)
- No additional punctuation after the tag colon

**Supported tags (recognized by Better Todo Tree):**
- `TODO` — feature or work to be completed
- `FIXME` — bug or issue requiring attention
- `NOTE` — important information or context
- `HACK` — temporary solution needing refactoring
- `BUG` — confirmed defect
- `XXX` — critical attention required

**Roadmap items** (larger initiatives tracked in MASTER_CONTEXT.md):
When documenting roadmap priorities in this file, prefix items with:
- `[ROADMAP]` or `[TODO]` for alignment with the Better Todo Tree format

Example:
```markdown
### Part IV: Future expansion (planned)

#### Workspace & Development Infrastructure
- [TODO] Better Todo Tree workspace settings (custom tags, exclude patterns, colors)
- [TODO] Add Control and Datalogger as optional dependency groups in `pyproject.toml`
- [TODO] Review and unify root-level `.gitignore` for all monorepo patterns
- [TODO] Unified CI/CD pipeline documentation (GitHub Actions or similar)

#### Consolidation Improvements
- [ROADMAP] Unified requirements strategy (root-level `pyproject.toml` with optional groups instead of per-service `requirements.txt`)
- [ROADMAP] Unified venv at monorepo root (currently per-service; simplifies Python path configuration)

#### Core Features & Bug Fixes
- [TODO] Multi-robot coordination through shared NATS namespace
- [ROADMAP] Cockpit offline-first PWA implementation
- [FIXME] Address control timeout race condition on restart
```

**Developer workflow:**
1. Use Better Todo Tree extension to scan codebase for all TODO/FIXME/NOTE tags
2. Open the Better Todo Tree panel via the Activity Bar or command palette
3. Filter by tag, file, or scope as needed
4. Update MASTER_CONTEXT.md with strategic roadmap items
5. Update individual code comments as work progresses

---

## See also

- [CONSOLIDATION.md](CONSOLIDATION.md) — Monorepo consolidation history
- [docs/](docs/) — Comprehensive documentation
- [cockpit/](cockpit/) — Cockpit service source code and docs
- [control/](control/) — Control service source code and docs
- [datalogger/](datalogger/) — Datalogger service source code and docs
