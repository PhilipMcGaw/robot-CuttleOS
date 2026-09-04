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

## Repeatable Raspberry Pi deployment

- [x] Add a macOS helper that prepares Raspberry Pi Imager's cloud-init
  `user-data` without discarding Imager's hostname, user, network or SSH
  customisation.
- [x] Add a non-interactive first-boot wrapper and systemd service that reuse the
  canonical profile-driven provisioner.
- [ ] Complete clean-image bench validation on a Raspberry Pi OS Trixie Lite
  target, including failure recovery and service startup.

## Testbot weekend bench validation

Work through these checks on the physical Testbot with the wheels raised or propulsion disconnected until motor behaviour is understood. Record the date, RPi model, OS image, profile revision, hardware connected, result, and any evidence in the Testbot build record.

### Deployment and safe startup

- [ ] Write the current RPi image and apply the macOS first-boot helper.
- [ ] Confirm the `testbot` profile is installed and selected.
- [ ] Confirm CuttleOS services start cleanly and record their status.
- [ ] Confirm NATS connectivity and the `testbot` namespace.
- [ ] Confirm the emergency-stop and command-timeout behaviour before enabling propulsion.

### Basic hardware bring-up

- [ ] Confirm the Pi Camera is detected and produces a stable image.
- [ ] Confirm the camera servo operates on PCA9685 channel 0 and record safe tilt limits.
- [ ] Confirm M1 and M2 motor identity, polarity, and differential steering with propulsion isolated.
- [ ] Confirm battery voltage telemetry and record the battery-monitor calibration.
- [ ] Confirm the two onboard WS2812 LEDs can be controlled and agree the red, amber, green, and blue status meanings.
- [ ] Confirm the onboard buzzer produces a short, duration-limited horn pattern.

### USB headset audio validation

- [ ] Connect the USB headset and confirm its microphone and speakers appear in ALSA device listings.
- [ ] Record a short local microphone sample and check its level and clarity.
- [ ] Play a known audio file through the headset speakers and check its level and clarity.
- [ ] Confirm audio device selection survives a service restart and RPi reboot.
- [ ] Record headset disconnect and reconnect behaviour.
- [ ] Keep the headset as a bench-test device; do not treat it as the final Testbot audio hardware.

### K9 audio path validation without a moving platform

- [ ] Validate a K9 soundboard clip locally through the USB headset.
- [ ] Validate the profile-selected sound command over NATS.
- [ ] Validate `k9-say.sh` with its supported speech presets: `normal`, `calm`, `alert`, and `alarm`.
- [ ] Record playback failures, missing devices, and invalid sound or speech requests.
- [ ] Confirm that soundboard validation does not require motor operation or video synchronisation.

### Optional Testbot hardware

- [ ] Fit and identify the MPU6050 before enabling its profile capability.
- [ ] Add and test the ultrasonic sensor.
- [ ] Add and test digital switches.
- [ ] Add and test the line-tracking module.
- [ ] Add and test the light-tracing module.

### BlueROV and BlueOS-inspired operational foundations

These items are informed by the practical operation and documentation of
BlueROV2 and BlueOS. They are CuttleOS work items, not a proposal to adopt
BlueOS, MAVLink, or ArduPilot as runtime dependencies.

Safety and control additions from ArduSub should be implemented in this order:

- [ ] Define profile-driven vehicle states for initialising, not ready, ready,
  armed, emergency stop, failsafe, and maintenance.
- [ ] Implement pre-operation checks with clear failure reasons and controlled
  bench-test bypasses.
- [ ] Separate disarm, emergency motor stop, and failsafe recovery semantics.
- [ ] Add deadman/command-freshness checks and require explicit recovery after
  communication loss.
- [ ] Add layered battery, leak, pressure, temperature, sensor-validity,
  hardware-node, and watchdog responses.
- [ ] Expose only modes supported by the active profile and required sensors.
- [ ] Add versioned calibration, tuning, limits, and safety-event records.
- [ ] Build the safety test matrix from disconnected software tests through dry
  integration and shallow-water commissioning.

- [ ] Add a clear headless-robot startup and network-health view to Cockpit,
  including robot discovery, active interface, connection state, and useful
  bandwidth indicators.
- [ ] Define an explicit safe operating mode and a separate maintenance mode
  for configuration, updates, and other actions that should not be available
  while propulsion is armed.
- [ ] Add profile-driven vehicle setup views for actuator identity, direction,
  limits, trim, safe manual checks, and camera or gimbal configuration.
- [ ] Add a searchable/downloadable operational log view for telemetry, control,
  service health, and important vehicle events.
- [ ] Complete configurable video-stream management with persistent settings,
  multiple output paths where required, and a documented WebRTC boundary.
- [ ] Define the equivalent audio-stream management boundary for microphones,
  speakers, and recorded audio tracks.
- [ ] Define a bounded extension boundary for optional payloads and services,
  including permissions, resource limits, logs, restart, disable, update, and
  rollback behaviour.
- [ ] Define stable, beta, and development deployment channels for CuttleOS
  releases and robot profiles.

## Feature Development

### Shared Adeept ADM133 Control driver

- [ ] Define the hardware-independent Control adapter interface and mock behaviour
- [ ] Implement ADM133 discovery, I²C health checks, and safe initialisation
- [ ] Implement profile-driven buzzer and WS2812 status output
- [ ] Implement battery ADC telemetry and calibration
- [ ] Implement PCA9685 servo output while enforcing H-bridge channel reservations
- [ ] Implement safe single-motor bring-up, command timeout, and M1/M2 differential drive
- [ ] Add optional ADM133 sensor drivers one at a time with independent validation evidence
- [ ] Reuse the validated adapter profile for K9, then assess ROV suitability separately

### K9 Soundboard and Generated Speech

- [ ] Add a Control-side K9 generated-speech command backed by `assets/robots/k9/tools/k9-say.sh`
- [ ] Define profile-controlled text validation and the supported `normal`, `calm`, `alert`, and `alarm` presets
- [ ] Allow generated speech to fall back to, or replace, pre-recorded soundboard clips where appropriate
- [ ] Add playback failure reporting and Raspberry Pi audio-device validation

### Testbot bring-up and operator controls

- [ ] Bench-test the Testbot ADM133 motor, battery, camera-servo, WS2812, and buzzer bindings with propulsion safely supported
- [ ] Confirm the camera-servo PCA9685 channel, motor polarity, battery calibration, WS2812 LED count, and buzzer behaviour
- [ ] Produce and record Testbot CAD, including the RPi, ADM133, battery, motor, camera, and camera-servo mounting points
- [ ] Add profile-driven Cockpit status-indicator rendering using the shared red/amber/green/blue semantic states
- [ ] Add a profile-driven Horn control with a `fa-bullhorn` button and a duration-limited buzzer pattern
- [ ] Add optional Testbot profiles for the MPU6050, ultrasonic sensor, digital switches, line tracking, and light tracing after each module is fitted and tested

### USB Microphone and Live Audio Streaming

- [ ] Add profile capabilities such as `microphone` and `audio_stream`, initially for K9 and optionally for ROV
- [ ] Add a robot-side ALSA capture service for a configured USB microphone
- [ ] Provide a browser-compatible low-latency stream through the existing Nginx deployment; evaluate HTTP Opus first and WebRTC where lower latency is required
- [ ] Add authenticated access, device selection, reconnect handling, and microphone privacy/status indicators
- [ ] Validate audio capture, bandwidth, and service recovery on K9 and ROV hardware
- [ ] For K9, provide live microphone audio to the operator for local situational awareness
- [ ] Include captured microphone audio as an audio track in every applicable saved video recording
- [ ] Define a low-latency operator-to-K9 audio return path for the soundboard/speaker

### Common Stereo Video and Media Pipeline

Stereo video is a common CuttleOS capability for robots such as K9 and ROV, rather than a K9-specific feature. The camera, recording, live-streaming, and presentation layers should remain separate so that the same stereo source can support multiple outputs.

- [ ] Define a common vehicle-side video service for synchronised stereo camera acquisition, encoding, recording, still capture, and live distribution
- [ ] Support synchronised left/right camera capture, with global shutter preferred for remote driving
- [ ] Target approximately 75–80 mm stereo baseline where the vehicle camera installation permits it
- [ ] Preserve native stereo as the master recording; do not make anaglyph the primary storage format
- [ ] Decouple local recording from live streaming so recording can continue when no operator is viewing the live feed
- [ ] Implement on-demand live streaming so that zero viewers results in zero live video traffic over the network
- [ ] Prefer WebRTC for low-latency live video, particularly for K9 operation over a mobile network
- [ ] Add adaptive live-video quality profiles for changing network conditions, with a degraded mono/low-resolution mode available when bandwidth is constrained
- [ ] Ensure video traffic cannot starve safety-critical control and telemetry traffic
- [ ] Support a common media presentation layer capable of mono, side-by-side stereo, and future stereoscopic/VR presentation
- [ ] Investigate Meta Quest/WebXR support as a Cockpit viewing mode without changing the vehicle-side stereo master
- [ ] Define a common timestamp/reference clock for stereo video, audio, telemetry, and control events
- [ ] Preserve raw video and raw NATS telemetry/control logs as the authoritative recordings
- [ ] Generate synchronised telemetry subtitle tracks (for example WebVTT) from recorded NATS data rather than burning telemetry into the master video
- [ ] Provide optional rendered telemetry overlays for exported video where a permanent overlay is required

### Vehicle Storage and Recording

- [ ] Treat storage as a discovered vehicle capability rather than assuming every robot has the same media storage
- [ ] For K9, support a dedicated 1 TB portable SSD for video, audio, telemetry, command/control logs, stills, and diagnostics, while retaining the SD card for OS/application storage
- [ ] For ROV, support both SSD-equipped high-rate recording and reduced-capability operation where only SD-card storage is available
- [ ] Define recording retention, free-space monitoring, and failure behaviour when storage becomes unavailable or full
- [ ] Keep the recording service independent of Cockpit so loss of the operator connection does not stop local recording

### Robot Capabilities Discovery
- [ ] Implement capability-based UI rendering
- [ ] Cockpit discovers robot capabilities from configuration
- [ ] Dynamic UI adaptation based on available features
- [ ] Examples:
  - ROV: depth, heading, thruster allocation, buoyancy, underwater cameras, stereo video
  - K9: wheel/leg control, head movement, arm control, different camera arrangements, stereo video, microphone, speaker/audio output

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

### Media and Cockpit Testing
- [ ] Test mono and stereo live-video paths independently of the recording path
- [ ] Verify that no live video traffic is generated when there are zero viewers
- [ ] Test adaptive video profiles over constrained/mobile-network links
- [ ] Measure end-to-end video latency for remote driving and establish an engineering target
- [ ] Verify synchronisation between left/right video, microphone audio, NATS telemetry, and control logs
- [ ] Test recording recovery after network loss, Cockpit restart, camera failure, and storage failure
- [ ] Validate K9 SSD recording endurance and behaviour at low free space
- [ ] Validate ROV operation with and without optional high-capacity storage
- [ ] Test Meta Quest/WebXR stereo presentation without altering the master recording

## Timeline

### Short-term (1-2 months)
- Phase 1: Robot profile TOML migration
- Pydantic model updates
- Basic testing framework
- Define common media-service interfaces and robot media capabilities
- Establish the stereo recording/live-stream architecture

### Medium-term (3-6 months)
- Phase 2: Hardware configuration migration
- Phase 3: Application configuration migration
- Enhanced configuration validation
- Robot capabilities discovery
- Implement common stereo video recording and on-demand live streaming
- Implement K9 microphone capture, live audio, and recorded audio
- Add vehicle storage capability and recording-health monitoring

### Distant and conditional work
- Multi-robot coordination through a shared NATS namespace is explicitly deferred. Revisit it only if CuttleOS proves useful for the [SwarmBot project](https://philipmcgaw.com/projects/swarmbot/); it is not part of the core CuttleOS roadmap.
- Meta Quest/WebXR presentation is conditional on achieving an acceptable low-latency stereo WebRTC path first.

### Long-term (6+ months)
- Architecture restructuring
- NATS protocol evaluation
- Repository naming decision
- HIL repository separation
- Advanced stereo/VR presentation and media export tooling

## Dependencies

This roadmap depends on:
- Completion of current status items (see `docs/status.md`)
- Stable robot profile implementation
- Hardware interface validation
- Team consensus on architectural changes
- Validation of the chosen camera and encoding hardware on target Raspberry Pi hardware
- Sufficient network performance for the intended remote-driving use case

## References

- ChatGPT architectural recommendations (archived in "GPT output.pdf")
- Current project status: `docs/status.md`
- Development guidelines: `docs/development.md`
- Configuration policy: `docs/robot-profile-requirements.md`
