# Roadmap

This document outlines the planned architectural improvements and feature development for robot-CuttleOS.

## Configuration Format Migration

### Current State
- Mixed use of YAML and configuration files across the project
- Robot profiles and hardware configurations currently use YAML
- Application configuration varies between formats

### Planned Migration to TOML

**Rationale:**
- TOML provides less ambiguous parsing behavior compared to YAML
- Better suited for engineering configuration (baud rates, timeouts, limits, hardware identifiers)
- Python has built-in `tomllib` support (no additional dependencies)
- Already using TOML in the project via `pyproject.toml`
- More explicit handling of numeric types and structured data

**Migration Plan:**

#### Phase 1: Robot Profiles
- [ ] Convert `configs/robots/rov.yaml` to `rov.toml`
- [ ] Convert `configs/robots/k9.yaml` to `k9.toml`
- [ ] Update Pydantic models to use TOML parsing
- [ ] Update robot profile loading logic
- [ ] Validate existing robot profiles work with new format

#### Phase 2: Hardware Configuration
- [ ] Convert hardware configuration files to TOML
- [ ] Update hardware interface loading logic
- [ ] Ensure RS-485 addresses, baud rates, GPIO assignments are properly handled
- [ ] Test hardware configuration parsing

#### Phase 3: Application Configuration
- [ ] Convert application configuration files to TOML
- [ ] Update FastAPI configuration loading
- [ ] Update service configuration loading
- [ ] Update deployment configuration

**Format Usage Guidelines (Post-Migration):**
- **TOML**: Robot configuration, hardware configuration, application configuration, deployment configuration
- **JSON**: NATS messages (initially), WebSocket messages, REST API
- **SQLite**: Persistent telemetry/logs
- **Pydantic**: Configuration validation and application models

## Architecture Improvements

### Enhanced Robot Configuration Structure

**Current:**
- Robot-specific configurations mixed with generic software
- Some robot-specific code duplication

**Planned:**
- Clear separation between generic software and robot-specific behavior
- Configuration-driven robot definitions where possible
- Single cockpit, communications architecture, and video system

**Structure:**

The following is a proposed future architecture, not a description of the
current repository layout. The current implementation remains the monorepo
described in `README.md`.

```
robots/
├── apps/              # Generic software (works for any robot)
│   ├── cockpit/
│   ├── control/
│   ├── telemetry/
│   ├── video/
│   └── datalogger/
├── robots/            # Robot-specific configurations
│   ├── rov/
│   │   ├── config/
│   │   ├── control/
│   │   └── hardware/
│   └── k9/
│       ├── config/
│       ├── control/
│       └── hardware/
├── packages/          # Shared libraries
│   ├── messages/
│   ├── nats/
│   ├── hardware/
│   └── common/
├── frontend/
├── configs/
├── tests/
├── scripts/
└── docs/
```

### NATS Message Protocol Evolution

**Current:**
- JSON messages for NATS communication
- Easy to debug and inspect

**Future Consideration:**
- Evaluate Protocol Buffers for high-rate telemetry and control
- Benefits: explicit types, versioned schemas, smaller messages, faster serialization
- Timeline: Only when performance becomes a critical concern

## Repository Naming

### Consideration: Repository Rename
- Current: `robot-CuttleOS`
- Considered: `robots` (as suggested in architectural review)
- Rationale: Better reflects multi-robot support (ROV, K9, etc.)
- Decision: Pending stakeholder review

### HIL Repository Relationship
- Current: Single repository approach
- Planned: Clear separation between:
  - `robots/` - actual robot software
  - `robots-hil/` - ROS 2, Gazebo, simulation environment

## Feature Development

### K9 Soundboard and Generated Speech

- [ ] Add a Control-side K9 generated-speech command backed by `assets/robots/k9/tools/k9-say.sh`
- [ ] Define profile-controlled text validation and the supported `normal`, `calm`, `alert`, and `alarm` presets
- [ ] Allow generated speech to fall back to, or replace, pre-recorded soundboard clips where appropriate
- [ ] Add playback failure reporting and Raspberry Pi audio-device validation

### Robot Capabilities Discovery
- [ ] Implement capability-based UI rendering
- [ ] Cockpit discovers robot capabilities from configuration
- [ ] Dynamic UI adaptation based on available features
- [ ] Examples:
  - ROV: depth, heading, thruster allocation, buoyancy, underwater cameras
  - K9: wheel/leg control, head movement, arm control, different camera arrangements

### Enhanced Configuration Validation
- [ ] Expand Pydantic schema coverage
- [ ] JSON Schema validation for configuration contracts
- [ ] Runtime configuration validation
- [ ] Better error messages for configuration issues

## Testing and Validation

### Configuration Testing
- [ ] Unit tests for TOML parsing
- [ ] Integration tests for configuration loading
- [ ] Validation tests for robot profiles
- [ ] Hardware configuration validation tests

### Migration Testing
- [ ] Backward compatibility tests during migration
- [ ] Performance comparison between YAML and TOML parsing
- [ ] Validation that all existing configurations work with new format

## Timeline

### Short-term (1-2 months)
- Phase 1: Robot profile TOML migration
- Pydantic model updates
- Basic testing framework

### Medium-term (3-6 months)
- Phase 2: Hardware configuration migration
- Phase 3: Application configuration migration
- Enhanced configuration validation
- Robot capabilities discovery

### Long-term (6+ months)
- Architecture restructuring
- NATS protocol evaluation
- Repository naming decision
- HIL repository separation

## Dependencies

This roadmap depends on:
- Completion of current status items (see `docs/status.md`)
- Stable robot profile implementation
- Hardware interface validation
- Team consensus on architectural changes

## References

- ChatGPT architectural recommendations (archived in "GPT output.pdf")
- Current project status: `docs/status.md`
- Development guidelines: `docs/development.md`
- Configuration policy: `docs/robot-profile-requirements.md`
