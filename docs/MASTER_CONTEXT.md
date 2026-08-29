# ROV Cockpit — Master Context

> **Role:** Persistent architectural and engineering context for humans and AI
> assistants working on ROV Cockpit.
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

## 1. Project purpose

ROV Cockpit is a browser-based operator interface for remotely operated and
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

---

## 2. Fundamental deployment model

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

## 3. Operating system and platforms

### Production

The production platform is:

> **Raspberry Pi OS, the Debian-based operating system provided by the
> Raspberry Pi Foundation.**

The selected robot baseline is Raspberry Pi OS Trixie Lite 64-bit (`arm64`) on
a Raspberry Pi 3B+ or newer 64-bit model. The Pi 3B+'s 1 GB RAM makes the Lite
image appropriate for the headless co-installed services. This target remains
unbench-tested until a clean-image provision and hardware evidence are
recorded. Legacy 32-bit is a temporary compatibility fallback only when a
specific verified dependency blocks Trixie 64-bit use.

Cockpit must therefore be designed and tested primarily as a Raspberry Pi
Linux application.

### Development

Windows and Linux are development platforms.

Development tooling should make it straightforward to develop, test, and
bootstrap Cockpit without requiring the developer workstation to reproduce the
complete robot environment.

Standalone Windows/bootstrap tooling exists to support development and
engineering deployment. It is not the production Cockpit architecture.

macOS may also be used for development where practical, but production
assumptions must not be derived from macOS, Windows, or Linux development
workstations.

---

## 4. Repository boundaries

Cockpit is maintained separately from the other robot services.

The intended repository boundaries are:

```text
ROV---Cockpit
ROV---Control
ROV---Datalogger
ROV---HiL-and-SiL
```

Cockpit owns the operator-facing web application.

Control owns hardware-facing control and physical safety.

Datalogger owns telemetry recording and generation of recorded data files.

HiL/SiL is maintained separately and is outside the Cockpit production
architecture.

Repositories communicate through defined service interfaces rather than
importing each other's implementation.

---

## 5. Service architecture

The production robot contains three primary application services:

```text
                    ┌─────────────────────┐
                    │      Operator       │
                    │  Firefox preferred  │
                    └──────────┬──────────┘
                               │
                         HTTP / WebSocket
                               │
                    ┌──────────▼──────────┐
                    │      Cockpit        │
                    │  Operator interface │
                    └──────────┬──────────┘
                               │
                           NATS Core
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
          Control          Datalogger       Other services
              │                │
              ▼                ▼
          Hardware          Recorded data
```

### Cockpit

Cockpit owns:

- operator presentation;
- browser UI;
- operator input;
- gamepad/keyboard mapping;
- telemetry visualisation;
- camera/media controls;
- camera presentation;
- navigation/HUD presentation;
- access to recorded CSV files;
- publication of operator commands to the configured NATS boundary;
- profile-defined soundboard selection;
- Cockpit-specific state;
- configurable Views, Widgets, Actions, and layouts.

Cockpit does **not** own physical actuator control or the robot's ultimate
safety response.

### Control

Control owns:

- hardware-facing commands;
- motor and actuator control;
- physical direction mapping;
- hardware limits;
- neutral behaviour;
- command timeouts;
- failsafe behaviour;
- emergency-stop behaviour;
- physical safety.

Cockpit must never become the robot's only propulsion or actuator safety layer.

K9's soundboard drawer is a profile-gated Cockpit control. It appears only
when the active profile enables `soundboard`, reads its labelled sound IDs from
that profile, and is usable only by an authenticated `driver` or `admin`.
Cockpit publishes the selected ID to `<namespace>.command.sound.play`; it does
not read, serve, or play the audio file itself. Control resolves the ID to the
profile-defined file and owns speaker hardware, volume limits, and safe
playback. The Cockpit command path is implemented and automatically tested;
Control-side playback is not yet implemented or bench-tested.

The shared header's identity icon is profile configuration rather than a
hard-coded vehicle glyph. The current profiles use an otter for the ROV, a bone
for K9, and a robot for PiWars.

### Datalogger

Datalogger owns:

- telemetry recording;
- long-term data storage;
- generation of recorded CSV files;
- logging configuration;
- recording of agreed NATS subjects.

Datalogger observes the system and must not alter control messages.

Cockpit may provide access to recorded CSV files for operator download, but does
not own CSV generation or long-term recording.

---

## 6. NATS architecture

NATS Core is the selected internal messaging middleware.

Cockpit communicates with Control, Datalogger, and other robot services through
NATS Core.

The browser never connects directly to NATS.

The intended flow is:

```text
Browser
   │
   │ HTTP / WebSocket
   ▼
Cockpit
   │
   │ NATS Core
   ▼
┌───────────────┐
│               │
▼               ▼
Control      Datalogger
```

For local development, the default configuration is:

```text
NATS_URL=nats://127.0.0.1:4222
NATS_SUBJECT=>
```

On a provisioned robot, the Cockpit, Control, and Datalogger systemd units
receive an authenticated loopback `NATS_URL` from `/etc/robot/nats.env`.
That restricted system file is generated by Cockpit provisioning from ignored
Control deployment configuration. It must not be committed, copied into
documentation, or exposed through Cockpit.

NATS subjects use dot notation.

Any slash notation used by Cockpit dashboard/state keys is an application-level
representation and must be translated by the appropriate adapter rather than
changing the NATS subject convention.

If NATS is unavailable during development startup, Cockpit may remain available
for view-only UI development. Live telemetry and control are unavailable until
NATS becomes available.

Expected NATS connection failures should be represented by a clear Cockpit
warning rather than exposing unnecessary library traceback noise.

### NATS JetStream

**NATS JetStream is explicitly out of scope.**

Do not introduce JetStream for telemetry persistence, recording, or unrelated
functionality without a separate architectural decision.

### MAVLink

**MAVLink is not part of the ROV Cockpit architecture.**

Blue Robotics Cockpit may use MAVLink as part of its own ecosystem, but that is
not applicable to this project.

The equivalent service boundary for this project is NATS Core.

---

## 7. Browser architecture

The operator communicates with Cockpit through a web browser.

Browser preference:

1. Firefox;
2. Chromium-based browsers;
3. Safari.

Browser compatibility should therefore be considered when selecting browser
APIs, media APIs, WebRTC implementations, and frontend libraries.

The browser communicates with Cockpit through:

- HTTP;
- WebSocket;
- WebRTC or other approved browser video mechanisms.

Browser clients must not connect directly to:

- NATS;
- robot hardware;
- Control hardware interfaces;
- Datalogger storage interfaces.

---

## 8. FastAPI and WebSocket architecture

Cockpit is implemented as a FastAPI web application.

The application is served through Uvicorn during development and an appropriate
production service configuration on the Raspberry Pi.

Default development port:

```text
8080
```

Python package entry point:

```text
rov_cockpit.app:app
```

Source tree:

```text
src/rov_cockpit/
```

The browser receives live telemetry through the Cockpit WebSocket.

The intended telemetry flow is:

```text
NATS
  │
  ▼
Cockpit transport/state layer
  │
  ▼
Cockpit WebSocket
  │
  ▼
Browser TypeScript state
  │
  ▼
UI components
```

Transport logic must remain outside presentation components.

---

## 9. Frontend architecture

The incremental TypeScript frontend is maintained in:

```text
frontend/src/
```

and compiled into:

```text
src/rov_cockpit/static/dist/
```

The frontend build runs automatically through the application development and
startup tooling where required.

The compiled output may remain usable when npm is unavailable, provided the
required committed output is present.

The frontend must not contain:

- NATS clients;
- NATS URLs;
- NATS credentials;
- direct broker access;
- physical hardware communication.

### Web Components

The TypeScript Web Component set includes:

- `<rov-battery>`;
- `<rov-network-status>`;
- `<rov-depth>`;
- `<rov-hud>`.

These components consume shared application state.

They must not contain NATS or WebSocket transport logic.

---

## 10. Combined ROV navigation HUD

The intended ROV cockpit navigation instrument is:

```text
<rov-hud>
```

It is a native SVG/CSS virtual-horizon display.

It presents together:

- roll;
- pitch;
- depth;
- heading.

The instrument consumes roll, pitch, depth, and heading values from the shared
TypeScript telemetry state.

It contains no:

- NATS client;
- WebSocket client;
- physical hardware communication;
- transport-specific logic.

Invalid, unavailable, or non-numeric attitude values must be represented as
unavailable rather than replaced with an assumed or fabricated measurement.

### ROV HUD

The ROV profile may additionally use:

```text
<rov-hud>
```

The HUD is a composite ROV-specific navigation presentation containing:

- a central virtual-horizon attitude display;
- depth scales;
- a heading tape.

The HUD consumes shared telemetry state and contains no transport logic.

The HUD does not redefine the underlying attitude telemetry model.

Other robot profiles may omit the ROV HUD entirely.

The live ROV page does not include separate heading-band or depth-meter
widgets. Heading and depth are rendered by the combined HUD only.

The HUD reference presentation is a transparent video overlay with open central
attitude arcs, graduated roll scales on both sides, a right-side depth scale,
and a graduated heading tape along the bottom. A filled dark circular panel is
not the intended primary presentation.

### HUD style editing

The Cockpit provides a reusable instrument-style editor for the ROV HUD. It
currently exposes text colour, line colour, accent colour, and line thickness.
The editor applies CSS custom properties and emits a generic browser event so
the same framework can later style heading bars, depth bars, and other
components. Settings are currently stored in browser local storage using the
active profile and component identity; robot-backed profile persistence remains
planned.

### Development sensor simulator

The `/simulator/` page is always visible in the Cockpit navigation. Slider
changes are sent automatically with a short debounce; no manual send action is
required. A runtime
switch controls whether its sliders may inject fake depth, heading, pitch,
roll, battery voltage, and battery percentage values into the browser telemetry
path. The switch defaults to off on process start unless
`COCKPIT_ENABLE_SIMULATOR=true` is explicitly set. Simulator values do not go
to NATS or Control, and simulator mode must not be enabled for live physical
robot operation.

---

## 11. Current dashboard presentation

### Heading

The ROV combined HUD owns the heading presentation. Its heading tape is a
transparent video overlay positioned along the lower edge of the live view,
above the command dock.

It uses 3-degree minor ticks. The North/0-degree tick is the longest and
heaviest; all other 15-degree divisions use intermediate major ticks. Cardinal
points retain their compass labels but do not alter their tick length.

### Depth

The active depth presentation is the right-side vertical depth scale in the
combined ROV HUD.

It uses:

```text
sensor/water/depth
```

with SI metres as the telemetry and display unit.

Invalid or unavailable depth must be represented explicitly.

The former lower-right Flight Indicator altimeter and top-bar Heading/Depth
presentations are not active dashboard presentations.

### Camera pitch

The live-view bottom dock includes a camera inclination readout that consumes:

```text
sensor/camera/main/pitch
```

The value is expressed in degrees relative to the ROV body, where:

```text
0° = straight ahead
```

The camera-control implementation is responsible for converting its physical
servo home position into this representation.

The relationship between the physical servo position and the reported value
must be bench validated before the value is described as a measured camera
orientation.

The same dock presents the primary ROV light level from `output/lights/left`
as a numeric `0–100 %` value and water temperature from
`sensor/water/temperature` in `°C`. These are presentation-only telemetry
values; Cockpit does not directly drive the light output or camera actuator.

---

## 12. Camera and media architecture

Camera support is a Cockpit responsibility.

Cockpit owns:

- camera inventory;
- camera configuration;
- camera-control presentation;
- media controls;
- recording controls;
- still capture;
- gallery/download presentation;
- Nginx media configuration;
- reverse-proxy configuration related to camera streams.

The original monolithic ROV repository must not contain duplicate Cockpit camera
or Nginx configuration.

### Camera abstraction

Camera sources must be separated from the browser-facing Cockpit UI.

The architecture should support different camera sources without requiring
camera-specific Cockpit UI paths.

Potential sources include:

- CSI cameras;
- USB cameras;
- other supported Linux camera sources.

Camera-specific implementation belongs in the camera/media layer rather than
generic Cockpit presentation components.

---

## 13. Camera processing pipeline

The camera system must support processing between capture and output.

The intended architecture is:

```text
Camera
  │
  ▼
Capture
  │
  ▼
Camera processing pipeline
  │
  ├── lens correction
  ├── dewarping
  ├── optional image processing
  │
  ▼
Canonical processed video
  │
  ├───────────────► WebRTC
  │                    │
  │                    ▼
  │                 Browser
  │
  ├───────────────► Recording
  │                    │
  │                    ▼
  │                   Disk
  │
  └───────────────► Still capture
```

There should be a **single canonical processed video feed**.

The WebRTC stream and saved video should originate from that same processed
feed.

Therefore:

> **The video presented to the operator and the recorded video should
> represent the same post-processing output.**

This avoids displaying corrected video while recording an uncorrected source.

### Lens correction and dewarping

The processing pipeline should support different optical systems, including:

- conventional lenses;
- fisheye lenses;
- panoramic lenses;
- 360° cameras;
- other lenses requiring geometric correction.

Dewarping should occur **before recording** where practical.

The saved recording should therefore normally contain the same corrected video
that the operator sees.

The correction method and parameters should be associated with the camera
configuration rather than embedded into the generic video widget.

---

## 14. WebRTC

WebRTC is the preferred browser-facing live-video transport where it provides
the simplest practical integration with the Raspberry Pi camera/media stack.

The selection of the final implementation must consider:

- Raspberry Pi CPU/GPU capability;
- latency;
- browser compatibility;
- Firefox support;
- Chromium compatibility;
- Safari compatibility;
- local/offline operation;
- multiple video streams;
- recording requirements;
- maintainability.

WebRTC implementation details must remain behind the camera/media abstraction.

The frontend should consume the browser-facing video interface rather than
implementing camera-specific processing.

WebRTC is preferred because it provides an appropriate low-latency browser
transport, but it is not an architectural requirement if a better mechanism
is demonstrated to work with the complete stack.

---

## 15. Video recording

Live video and recorded video should originate from the same canonical
processed video feed.

The intended architecture is:

```text
Camera
   │
   ▼
Capture
   │
   ▼
Processing / Dewarping
   │
   ▼
Canonical video
   ├────────► WebRTC ─────► Browser
   │
   └────────► Recorder ───► Disk
```

This is an explicit architectural requirement.

The system should not normally:

- dewarp only for display;
- record a separate raw stream;
- apply different correction parameters to live and recorded video.

If hardware limitations require a different implementation, that difference
must be explicitly documented and validated.

---

## 16. Nginx and media serving

Nginx provides the required production reverse-proxy and media-serving
functionality.

Camera and media configuration belongs to Cockpit.

The supported repeatable Nginx deployment helper is:

```text
scripts/3_configure_nginx.sh
```

It may require `sudo` because it changes system Nginx and systemd state.

It must:

- back up an existing site configuration before replacement;
- validate Nginx before reload;
- report resulting service state;
- report media/cache state;
- fail safely if validation fails.

---

## 17. Offline-first operation

Cockpit is designed **offline first**.

Internet access is optional.

The robot must remain capable of operating when there is no external network or
Internet connection.

The Raspberry Pi should be capable of providing the local operator network.

The intended network modes are:

### Existing network

```text
Existing network
       │
       ▼
Robot Raspberry Pi
       │
       ▼
Cockpit
       │
       ▼
Operator browser
```

### Standalone robot network

```text
Robot Raspberry Pi
       │
       ├── DHCP
       ├── Gateway/network services
       ├── Wireless access
       └── Local DNS
                │
                ▼
         Operator browser
```

If the robot is not connected to an existing network when it boots, the
Raspberry Pi should be capable of establishing the local network required for
operator access. The deployed hotspot uses NetworkManager shared IPv4 mode on
`192.168.42.1/24`; it supplies DHCP and local DNS. `.42` is a deliberate
reference to *The Hitchhiker's Guide to the Galaxy* and is a locally chosen
convention, not a guarantee against every possible network collision.

A captive portal is not currently implemented and must not be claimed as a
production feature.

The exact network implementation remains a system/networking concern rather
than a browser-UI concern.

Core Cockpit UI assets must be available locally.

Do not introduce mandatory CDN dependencies for core functionality.

---

## 18. Network ownership

Robot network configuration is a system/networking responsibility.

Control remains the owner of robot networking configuration where the deployment
requires:

- NetworkManager;
- hostname;
- SMB;
- Avahi;
- fallback networking;
- related robot network configuration.

Cockpit may orchestrate required deployment steps during provisioning but must
not duplicate network configuration ownership.

The offline-first operator connection model remains a production requirement.

---

## 19. Authentication

Authentication is an architectural requirement but may be implemented later in
the roadmap.

The architecture must allow authentication and authorisation to be introduced
without substantial Cockpit redesign.

The intended access model is:

- view-only functionality can be available without authentication where
  explicitly permitted;
- driver functionality requires appropriate authorisation;
- administrative functionality requires appropriate authorisation;
- privileged operations must not fundamentally depend on anonymous access.

Authentication must eventually be tested as a real security boundary.

A login form or authentication UI alone is not evidence that authentication is
correctly implemented.

Authentication must be integrated with the Cockpit session/request model rather
than scattered throughout individual widgets.

---

## 20. Robot profiles

Robot-specific behaviour is defined through validated profiles.

The initial profiles are:

- ROV;
- K9;
- PiWars.

The profile system allows the same Cockpit, Control, and Datalogger architecture
to operate on different robot types without substantial application-code
changes.

The profile is also intended to allow the services to be deployed on different
devices or configurations without requiring significant application changes.

The repository source of truth is:

```text
configs/profiles/
```

The deployed runtime copy is initially:

```text
/etc/robot/profile.json
```

The profile relationship is:

```text
Repository profile
      │
      │ deployment
      ▼
/etc/robot/profile.json
      │
      ├─────────────┐
      ▼             ▼
   Cockpit       Control
      │             │
      └──────┬──────┘
             ▼
         Datalogger
```

Cockpit, Control, and Datalogger must use the same active profile identity and
configuration hash.

A profile change requires a controlled restart or reboot.

Profiles are not intended to be independently edited by each service.

---

## 21. One Cockpit, multiple robot types

Cockpit should have out-of-the-box support for the configured robot profiles.

The objective is:

```text
             Generic Cockpit
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
       ROV         K9       PiWars
```

The application should not require a separate fork or substantially different
Cockpit code for each robot.

Robot-specific behaviour should be provided through:

- profiles;
- capabilities;
- Views;
- Widgets;
- Actions;
- telemetry/state definitions;
- input mappings.

The same principle should apply to future robot types.

This does **not** mean that one Cockpit instance controls multiple robots
simultaneously.

The production deployment model remains:

> **One robot — one Cockpit.**

---

## 22. Operator input versus hardware control

Robot profiles must preserve the boundary between operator intent and physical
implementation.

Cockpit owns:

- gamepad mapping;
- keyboard mapping;
- operator-facing control configuration;
- operator Actions;
- generation of operator commands.

Control owns:

- physical motor mapping;
- actuator mapping;
- physical direction;
- hardware limits;
- safety;
- physical command execution.

This allows the same operator interface to work with different robot hardware
without embedding hardware-specific motor logic into Cockpit.

---

## 23. CSV and data access

Cockpit provides an operator-facing mechanism to access and download recorded
CSV files.

The `/data/` page reads CSV exports from:

```text
CSV_ROOT
```

with the default:

```text
<project>/data/csv
```

Cockpit does not generate the source CSV files.

Datalogger remains responsible for:

- telemetry recording;
- CSV generation;
- data storage.

Cockpit may provide:

- file selection;
- bounded previews where useful;
- filtering;
- downloads.

Viewing or downloading a CSV must not modify the source recording.

The primary purpose of the Cockpit data interface is operator access to recorded
files.

---

## 24. Customisable operator interface

Customisation is a fundamental Cockpit design requirement.

Cockpit should emulate the configurable operator-interface philosophy
demonstrated by Blue Robotics Cockpit, while adapting it to this project's own
architecture, NATS interfaces, robot profiles, safety model, and offline-first
deployment.

The reference system demonstrates browser-based control, widget-based layouts,
switchable Views, WebRTC video widgets, custom widgets, Actions, shared data,
and configurable joystick inputs. citeturn0search0

Blue Robotics Cockpit is a **design and UX reference only**.

MAVLink is not part of the ROV Cockpit architecture.

The Cockpit architecture is based on:

- FastAPI;
- browser-based operation;
- WebSocket telemetry;
- NATS Core;
- shared TypeScript application state;
- validated robot profiles;
- configurable Cockpit Actions;
- a separate Control service responsible for physical control and safety.

The operator interface should not be a fixed collection of hard-coded screens.

It should provide a configurable system in which robot profiles define the
available capabilities and the operator can arrange those capabilities into
appropriate interfaces.

### Profiles

A profile represents a robot type and its associated Cockpit capabilities.

Profiles may define:

- available Widgets;
- available Views;
- available controls;
- telemetry variables;
- Control-owned hardware adapters, bindings to logical command and telemetry keys, and validated semantic actuator aliases;
- gamepad mappings;
- Actions;
- camera/video configuration;
- robot-specific presentation;
- available capabilities.

### Views

A profile may contain multiple Views.

Views allow different operator layouts to be created for different purposes,
for example:

- normal driving;
- inspection;
- navigation;
- camera operation;
- diagnostics;
- engineering/test operation.

Views should be switchable during operation without requiring the application
to restart.

### Widgets

Widgets are the primary building blocks of the operator interface.

Widgets should support, where appropriate:

- adding and removing;
- moving;
- resizing;
- configuration;
- visibility control;
- shared telemetry/state access;
- robot-profile-specific availability.

Widget categories should include, where appropriate:

- video;
- attitude;
- heading;
- depth;
- battery;
- network status;
- maps;
- telemetry indicators;
- plots;
- status indicators;
- controls;
- diagnostic displays.

Widgets must consume Cockpit's defined state and Action interfaces.

They must not connect directly to NATS or physical hardware.

### Mini-widgets

Compact widgets should be available for areas such as:

- the top bar;
- status areas;
- secondary controls;
- compact telemetry;
- connection status;
- frequently used Actions.

### Input widgets

Cockpit should support configurable operator input widgets including, where
appropriate:

- action buttons;
- switches;
- checkboxes;
- dropdowns;
- sliders;
- dials;
- labels.

Input widgets normally set an operator-facing value or invoke an Action.

They must not bypass the Control service's safety boundary.

### Custom widgets

Cockpit should provide a mechanism for creating custom widgets where practical.

A custom widget should be capable of defining its own:

- presentation;
- styling;
- user interaction;
- application-specific display logic.

Custom widgets should access Cockpit's defined state and Action interfaces
rather than connecting directly to NATS or physical hardware.

The preferred implementation should allow custom widgets to be developed
without requiring changes to the core Cockpit application for every new
visualisation or operator control.

### Shared telemetry and application state

Cockpit should maintain a common application state/data model that can be
consumed by Widgets.

This provides a capability similar in concept to the shared data model used by
Blue Robotics Cockpit, but is implemented using this project's own telemetry,
WebSocket, and NATS architecture. Blue Robotics documents shared data,
custom/compound variables, and Actions as core extensibility mechanisms. citeturn0search0

The state model should expose appropriate:

- robot telemetry;
- Cockpit state;
- camera/video state;
- network state;
- operator state;
- profile state;
- control state;
- derived/compound values.

Custom or derived variables may be supported where there is a clear use case.

Widgets should consume this shared state rather than implementing their own
NATS or WebSocket connections.

The browser must never connect directly to NATS.

### Actions

Cockpit should provide a configurable Action system.

Actions may support operations such as:

- sending an operator command through the Cockpit/Control interface;
- switching Views;
- starting/stopping video recording;
- changing camera behaviour;
- changing UI state;
- setting a Cockpit variable;
- invoking approved application functions.

Actions must remain subject to the Cockpit/Control safety boundary.

An Action must never provide a route around Control's:

- physical safety;
- limits;
- command timeouts;
- emergency-stop behaviour.

Actions should be usable from:

- on-screen controls;
- gamepad/joystick inputs;
- other approved Cockpit events;
- configurable UI elements.

### Gamepad and joystick customisation

Gamepad support should be configurable rather than hard-coded to a single
controller.

The operator should be able to configure:

- buttons;
- axes;
- modifiers;
- dead zones;
- direction/inversion where appropriate;

and map them to Cockpit Actions and operator-input functions.

The resulting operator command must still pass through the Control service,
which remains responsible for physical interpretation and safety.

Blue Robotics Cockpit's configurable joystick model is a design reference for
this capability. citeturn0search0

### Telemetry visualisation

Cockpit should support configurable telemetry presentation rather than
requiring every telemetry value to have a dedicated hard-coded Widget.

Where practical, generic indicators should allow an operator to select a
telemetry/state variable and configure:

- display name;
- unit;
- scaling;
- numerical precision;
- icon;
- presentation style.

Telemetry plotting should also be configurable, allowing an operator to select
variables and configure useful plot parameters.

### Containers and layout

Widgets should be capable of being grouped into configurable containers.

This allows an operator or profile author to create logical groups of:

- controls;
- status indicators;
- telemetry;
- diagnostic information;
- camera controls.

The layout system should support moving and resizing components without
requiring changes to application source code.

The design target is a freeform widget layout rather than a rigid fixed-grid
dashboard. Blue Robotics Cockpit explicitly provides freeform positioning and
resizing of widgets. citeturn0search0

### Video customisation

Cockpit should support configurable video presentation.

Profiles and Views should be able to determine:

- which camera streams are displayed;
- where video Widgets appear;
- the size of video Widgets;
- which camera is associated with a View;
- camera-specific controls where available.

Multiple video streams should be supported where the Raspberry Pi hardware and
media pipeline can sustain them.

All live video presented through Cockpit should use the common camera-processing
pipeline defined elsewhere in this document.

### Attitude and navigation customisation

The ROV HUD and other instruments are configurable Cockpit presentation
components rather than hard-coded requirements for every robot profile.

The ROV profile may provide:

- `<rov-depth>`;
- `<rov-hud>`.

Other robot profiles may select different instruments or omit ROV-specific
navigation displays.

The roadmap includes a reusable depth-scale configuration GUI. It will expose
the depth range, graduation step, visible viewport region, and line length,
then save those values with the active robot profile so
the HUD does not require code changes for routine scale adjustments.

This allows the same underlying Cockpit application to support ROVs, ground
robots, and other platforms without forcing inappropriate instruments onto
their interfaces.

### Import and export

Where practical, profiles, Views, Widget layouts, Actions, gamepad mappings,
and related configuration should support export/import using a portable
representation.

This is important for engineering use because a carefully configured Cockpit
interface should be reproducible across robots and development systems.

Imported configuration must still be validated against the active robot profile
and must not bypass Control safety constraints.

### Interface customisation

Cockpit should eventually support configurable visual presentation, including
where appropriate:

- light/dark presentation;
- robot branding;
- robot name;
- profile-specific visual identity;
- configurable status presentation;
- operator-selected layout preferences.

Custom styling must not compromise readability, status visibility, or safety
critical indications.

### Configuration ownership

Customisation belongs to Cockpit, but robot capability and safety remain
defined by the robot profile and Control service.

The boundary is:

```text
Profile
   │
   ├── declares available capabilities
   │
   ▼
Cockpit customisation
   │
   ├── Views
   ├── Widgets
   ├── Inputs
   ├── Actions
   └── Gamepad mappings
   │
   ▼
Operator command
   │
   ▼
NATS Core
   │
   ▼
Control
   │
   └── physical limits and safety
```

Cockpit customisation determines:

> **How the operator interacts with the robot.**

The Control service determines:

> **What the robot is physically permitted to do.**

Cockpit must never use customisation as a mechanism to bypass Control's
physical safety, limits, command timeouts, or emergency-stop behaviour.

### Design status

The customisation architecture is a design goal informed by the capabilities
of Blue Robotics Cockpit.

Individual customisation capabilities are not considered implemented merely
because they are defined here.

Each capability must be identified as:

- designed;
- planned;
- implemented;
- software-tested;
- bench-tested;
- physically validated;
- production-validated;

according to the project's documentation status rules.

---

## 25. Map support

The map is an optional Cockpit capability.

It should support robot-profile-specific availability.

The map supports optional Raspberry Pi Nginx tile caching through:

```text
MAP_TILE_PROXY=true
```

This is intended for deployments where external map access should be reduced or
controlled.

Local development may use direct provider URLs by default.

Core Cockpit operation must not depend on Internet map access.

---

## 26. Repository layout

The expected Cockpit repository structure is:

```text
src/rov_cockpit/
    Python package
    templates
    static assets

frontend/src/
    TypeScript source
    Web Components
    shared frontend state

configs/
    deployment configuration
    camera configuration
    media configuration
    authentication templates
    reverse-proxy configuration
    profiles/

docs/
    engineering documentation
    operational documentation
    deployment documentation
    robot-profile requirements
    current status

tests/
    application tests
    frontend-related tests
    documentation tests
    deployment/documentation policy tests

scripts/
    development setup
    frontend setup/build
    Raspberry Pi provisioning
    Nginx configuration
    application startup
```

Scripts must derive paths from their own location and must not depend on the
current working directory.

---

## 27. Development environment

Interactive shell examples should be compatible with Zsh.

Shell scripts may use the interpreter specified by their shebang.

Development tooling should avoid unnecessary system-wide changes.

The Windows standalone bootstrap exists to simplify development on engineering
PCs where the user may not have administrator rights.

It must:

- use a project-local Python runtime;
- install project dependencies locally;
- avoid system-wide Python requirements;
- avoid modifying the Windows registry;
- avoid modifying the Windows user/system `PATH`;
- avoid requiring administrator rights unless an explicitly documented
  external dependency requires them.

The Windows bootstrap is not a production Cockpit deployment mechanism.

Linux development tooling should similarly prefer project-local environments and
avoid unnecessary machine-wide modifications.

---

## 28. Frontend build and dependencies

The frontend uses TypeScript.

The frontend helper:

- validates the project-root `package.json`;
- runs npm from the project root;
- propagates npm failures;
- propagates TypeScript failures;
- builds the frontend before application launch where required.

Windows may bootstrap the pinned official Node.js/npm archive into the ignored
project-local:

```text
node-runtime/
```

when required.

Checksum verification must be used for downloaded runtime archives.

The helper may temporarily modify the child-process `PATH` when invoking npm,
but must not persist changes to the user's or system's environment.

Linux development may use an existing npm installation.

Committed frontend output may be used where npm is unavailable and the required
generated files already exist.

---

## 29. Styling

General-purpose styling uses Pico.css.

Cockpit-specific styling is maintained in:

```text
src/rov_cockpit/static/css/cockpit.css
```

The templates use the readable Pico CSS file and Cockpit-specific CSS.

jQuery remains an intentional legacy dependency for Flight Indicator until
that library is isolated or replaced.

Vue 3 is the approved frontend framework for the incremental migration. New
interactive Cockpit surfaces may be implemented as Vue components. Existing
Web Components remain supported during migration so the FastAPI/WebSocket
telemetry contract and deployed pages continue to work while each surface is
ported and tested. The battery status instrument is the first migrated visual
surface; depth, network status, HUD, style editing, and simulator migration
remain staged work.

Third-party frontend components and their attribution obligations are recorded
in `LICENSES.md`. This includes the committed Vue browser runtime, Pico CSS,
Font Awesome, Leaflet, jQuery, Flight Indicators, and Weather Icons. Any
future dependency or bundled asset must be added to that register as part of
the same change.

The documentation currency audit also verifies that `LICENSES.md` exists and
contains the current third-party component entries. Changes to dependency
manifests or bundled frontend assets are documentation-triggering changes and
must update the licence register when applicable.

The shared Vue battery instrument interprets battery telemetry strictly as a
`0–100` percentage. It uses Font Awesome battery-state icons and CSS colour
states: normal above 25 %, low from 11 % to 25 %, and critical at 10 % or
below. Invalid battery telemetry uses the empty icon and `-- %` placeholder;
legacy `0–10` and `0–1` scaling is not supported.

---

## 30. UI layout rules

The desktop top bar uses:

```text
--rov-nav-height: 60 px
--rov-nav-font-size: 0.75 rem
```

Navigation is non-wrapping and supports controlled horizontal scrolling on
narrower desktop viewports.

Heading and network overlays use the same custom-property positioning anchor.

The overlay gap is:

```text
--rov-overlay-gap: 8 px
```

Overlays must remain visually separated from the navigation bar when the
navigation height changes.

The navigation popover is a presentation feature for secondary Cockpit routes.

It must not:

- obscure the primary camera/HUD view unnecessarily;
- become a control-safety mechanism;
- interfere with safety-critical operator actions.

---

## 31. Safety boundary

Cockpit is an operator interface.

It is **not the authoritative safety layer**.

Safety-critical behaviour must remain functional if Cockpit:

- crashes;
- disconnects;
- loses its browser connection;
- loses its WebSocket;
- loses NATS connectivity;
- stops publishing commands.

Control must provide appropriate:

- command timeouts;
- neutral behaviour;
- failsafe behaviour;
- emergency-stop behaviour;
- hardware protection.

Any change affecting control commands must consider:

- lost browser connection;
- lost WebSocket connection;
- lost NATS connection;
- Cockpit process failure;
- stale commands;
- invalid operator input.

---

## 32. Authentication safety boundary

Authentication must not be treated as a substitute for physical safety.

Authentication controls:

- who can access Cockpit;
- who can operate;
- who can administer configuration.

Control remains responsible for:

- whether a command is physically valid;
- whether it is within limits;
- whether a timeout has occurred;
- whether the robot should enter a safe state.

---

## 33. Raspberry Pi provisioning

The supported initial Raspberry Pi provisioning path is:

```text
scripts/0_provision_raspberry_pi.sh
```

It is the canonical initial Raspberry Pi OS provisioner for the co-installed
Cockpit, Control, and Datalogger services. It derives the actual repository
locations and invoking runtime account; deployment units and Nginx are rendered
from templates rather than assuming `/home/pi` paths.

The source checkout must exist before the provisioner can install its full
dependency set. The documented bootstrap therefore installs `git` from the
configured Raspberry Pi OS repository, then uses one of two source routes:

- standard robot installation: read-only public HTTPS clones requiring no
  GitHub credential or write capability;
- Philip's developer installation: SSH clones authenticated by a unique
  Ed25519 key kept on that Pi and authorised on Philip's GitHub account, so it
  can pull branches and push reviewed commits.

Both routes place Cockpit, Control, and Datalogger as sibling repositories
below `~/robots/`. GitHub credentials and private SSH keys MUST NOT be stored
in a repository, profile, Control secrets file, or SMB share. The detailed
first-boot and update commands are maintained in `docs/deployment.md`.

It may install required system packages such as:

- Python;
- Node.js/npm where required;
- Nginx;
- Motion camera/media dependencies;
- NATS;
- NetworkManager and its shared-network dependency;
- Avahi and Samba;
- other explicitly approved production dependencies.

It may:

- create the Cockpit Python environment;
- create the Control and Datalogger Python environments;
- deploy the selected robot profile;
- create the shared Cockpit still, video, and CSV directories;
- install rendered Cockpit, Control, and Datalogger systemd units;
- generate authenticated NATS configuration from ignored Control secrets;
- install Motion configuration and invoke Control-owned network, SMB, and
  Avahi deployment;
- enable/check relevant services;
- configure the production reverse proxy using the deployed Cockpit checkout.

The provisioner requires ignored `ROV---Control/configs/network.env`,
`network.secrets.env`, and `nats.env` files before it starts. The NATS listener
is loopback-only by default; remote NATS access is an explicit authenticated
HiL/SiL configuration and remains subject to Raspberry Pi bench validation.
The secrets file MUST have mode `600` or `400` before provisioning reads it.

It must not silently install software from unverified sources.

If a required package is unavailable from configured trusted repositories,
provisioning must stop and report the condition.

The provisioning process must be safe to rerun where practical.

---

## 34. Nginx deployment

The supported repeatable Nginx deployment path is:

```text
scripts/3_configure_nginx.sh
```

It may require administrator privileges because it changes system Nginx and
systemd state.

It must:

- back up an existing site configuration;
- render and install the supported Cockpit configuration for the real checkout
  path;
- validate Nginx before reload;
- reload only after successful validation;
- report resulting service state;
- report relevant media/cache state;
- preserve useful diagnostic information on failure.

---

## 35. Script engineering standard

Future Windows, PowerShell, Bash, and POSIX scripts should use a deliberately
diagnostic engineering style.

Scripts should:

- derive absolute paths from their own location;
- validate prerequisites;
- check important external-command exit statuses;
- use explicit paths for project tools and native libraries;
- avoid modifying machine-wide environment state;
- be safe to rerun where practical;
- preserve useful diagnostics after failure;
- avoid deleting user data;
- clean temporary files after successful execution;
- preserve failed temporary state where useful for diagnosis;
- verify downloaded files using checksums or trusted manifests;
- report the final environment state.

Diagnostic output should use:

```text
[INFO]
[PASS]
[WARN]
[FAIL]
[SKIP]
```

Failures should identify:

1. the affected component or path;
2. why the failure matters;
3. the practical corrective action.

The final summary must distinguish between:

- detected;
- installed;
- configured;
- available;
- connected;
- bench-tested;
- physically validated.

Vendor drivers, SDKs, and native components may require separate
administrator-approved installation.

Such exceptions must be explicitly documented.

---

## 36. Documentation policy

Documentation is part of the implementation.

A behavioural, interface, driver, deployment, architecture, or validation change
must update the relevant documentation in the same change.

This is a hard completion gate. A change must not be reported as complete while
its documentation is deferred or while obsolete documentation contradicts the
implementation. The author must record the documentation and consistency checks
performed, or the reason they could not be run.

The master context must also be updated when the change materially affects:

- architecture;
- deployment;
- service ownership;
- safety;
- robot profiles;
- camera/media behaviour;
- authentication;
- communication interfaces;
- validation status;
- roadmap priorities.

The authoritative documentation policy is:

```text
docs/documentation-policy.md
```

Contributor guidance is:

```text
CONTRIBUTING.md
```

Current project status is:

```text
docs/status.md
```

Documentation tests and policy checks must pass locally and in CI where
applicable.

---

## 37. Engineering documentation standard

Project documentation uses formal British English.

Use:

- `licence`, not `license`, where referring to the noun;
- `behaviour`;
- `optimise`;
- `centre`.

Use the Oxford comma where it improves clarity.

Write for readers with an engineering degree or equivalent professional
experience.

Prefer:

- clear technical terminology;
- explicit assumptions;
- concise engineering prose;
- SI units;
- measurable statements;
- explicit validation status.

Avoid marketing language unless discussing an external product or design
reference.

---

## 38. Units and numerical notation

Use SI units with a space between the numerical value and the unit:

```text
5 m
12 V
500 mA
100 ms
1 Hz
20 °C
```

Use the degree symbol `°` for angles and temperatures where appropriate.

Use `degC` only where required by a machine-readable field or protocol.

CSV event and metadata timestamps use local time in:

```text
YYYY-MM-DD HH:MM:SS.ffff
```

format.

They contain exactly four fractional-second digits and do not use the previous
ISO `T`, UTC offset, or six-digit precision.

---

## 39. Python and coding standards

Python must follow PEP 8:

https://peps.python.org/pep-0008/

Changes should favour the smallest safe implementation that satisfies the
requirement.

Do not introduce:

- unnecessary frameworks;
- unnecessary dependencies;
- unrelated refactoring;
- duplicate configuration systems;
- new architectural layers without a demonstrated requirement.

---

## 40. Validation status

Every hardware or software status statement must distinguish the actual level
of evidence.

Use terminology such as:

- designed;
- planned;
- implemented;
- simulated;
- software-tested;
- bench-probed;
- bench-tested;
- physically validated;
- production-validated;
- production-proven;
- unverified.

Do not state or imply physical validation when only code, documentation, a
vendor SDK, or a simulator has been used.

Never invent a hardware validation result.

Camera/video performance, WebRTC operation, dewarping, network fallback,
authentication, gamepad behaviour, and hardware interfaces must each be
reported according to their actual validation status.

---

## 41. Current architectural priorities

The current priorities are:

1. Maintain a reliable Raspberry Pi-based Cockpit deployment.
2. Provide a browser-first operator interface.
3. Preserve offline-first operation.
4. Establish a clean Cockpit/Control/Datalogger/NATS boundary.
5. Support robot-specific behaviour through profiles rather than duplicated
   application code.
6. Establish a robust camera/media pipeline.
7. Use WebRTC as the preferred live-video transport where it fits the complete
   stack.
8. Ensure WebRTC and recorded video originate from the same canonical processed
   camera feed.
9. Support lens correction and dewarping before recording where practical.
10. Build a useful ROV attitude instrument and HUD.
11. Provide configurable operator input/gamepad support.
12. Build a genuinely customisable operator interface.
13. Ensure authentication can be introduced without architectural rework.
14. Maintain compatibility with Firefox, Chromium-based browsers, and Safari.
15. Keep the production system maintainable on Raspberry Pi OS.
16. Keep development tooling practical for Windows and Linux engineering
    workstations.

---

## 42. Explicitly out of scope

The following are outside the current Cockpit architecture unless deliberately
reconsidered:

- MAVLink;
- NATS JetStream;
- ROS 2 as a Cockpit dependency;
- HiL/SiL implementation;
- direct hardware communication from Cockpit;
- Cockpit-owned motor/actuator safety;
- Cockpit-owned CSV generation;
- mandatory Internet connectivity;
- mandatory external CDN resources;
- simultaneous multi-robot operation from one Cockpit instance;
- unrelated frontend framework replacement;
- unrelated repository-wide refactoring.

The following are **not** out of scope, but may be roadmap items:

- authentication;
- a library-neutral profile icon schema and locally bundled SVG icon registry,
  with Lucide assessed for new Vue components before any complete Font Awesome
  retirement;
- extensive Widget customisation;
- custom Widgets;
- configurable Views;
- import/export of layouts;
- advanced Actions;
- extensive telemetry plotting;
- multiple camera streams;
- additional lens-correction algorithms.

These must be tracked as planned or implemented rather than being described as
current functionality prematurely.

---

## 43. Blue Robotics Cockpit design reference

Blue Robotics Cockpit is an important design reference for the project.

Relevant concepts include:

- browser-based operation;
- configurable Widget layouts;
- freeform positioning and resizing;
- switchable Views;
- multiple video Widgets;
- WebRTC video;
- video recording;
- custom Widgets;
- a shared data/state model;
- custom and compound variables;
- Actions;
- configurable joystick inputs;
- telemetry visualisation;
- extensibility;
- portable/shareable interface configuration.

These concepts are documented by Blue Robotics as core Cockpit capabilities. citeturn0search0

The project should emulate the **operator experience and extensibility
principles**, not copy Blue Robotics' communications architecture.

In particular:

```text
Blue Robotics Cockpit
        │
        │ design inspiration
        ▼
ROV Cockpit
        │
        ├── FastAPI
        ├── WebSocket
        ├── TypeScript state
        ├── NATS Core
        ├── Robot profiles
        └── Control/Datalogger services
```

MAVLink is not used.

NATS JetStream is out of scope.

---

## 44. AI assistant working rules

When working on Cockpit:

1. Read this file first.
2. Inspect the current implementation when exact behaviour matters.
3. Treat current code and physical evidence as stronger evidence than this file.
4. Distinguish implementation from validation.
5. Never invent a hardware validation result.
6. Identify documentation/code inconsistencies rather than silently choosing one
   interpretation.
7. Preserve established architecture unless the user explicitly changes it.
8. Keep physical hardware communication out of Cockpit.
9. Keep safety-critical behaviour in Control.
10. Keep telemetry recording and CSV generation in Datalogger.
11. Keep camera/media transport behind appropriate adapters and processing
    boundaries.
12. Keep WebRTC and camera-specific processing out of generic presentation
    components.
13. Do not introduce ROS 2 as a Cockpit dependency.
14. Do not introduce NATS JetStream.
15. Do not introduce MAVLink.
16. Preserve offline-first operation.
17. Avoid mandatory Internet/CDN dependencies.
18. Preserve the one-robot/one-Cockpit deployment model.
19. Use robot profiles rather than duplicating robot-specific application logic.
20. Treat authentication as an architectural requirement even where
    implementation is deferred.
21. Treat customisation as a first-class architectural goal.
22. Prefer the smallest safe change.
23. Avoid unrelated refactoring.
24. Update documentation when behaviour or architecture changes.

Before implementing a change, consider:

- Which architectural layer owns this?
- Does it cross the Cockpit/Control/Datalogger boundary?
- Does it affect physical safety?
- Does it affect authentication or authorisation?
- Does it affect offline operation?
- Does it affect the robot profile?
- Does it affect camera/video processing?
- Does it affect browser compatibility?
- Does it affect the shared state model?
- Does it affect configurable Views, Widgets, or Actions?
- Can it be tested without physical hardware?
- Does it introduce a new dependency?
- Does it introduce an Internet dependency?
- Does it require administrator privileges?
- Is it part of the current milestone or future scope?

After implementation:

- run relevant tests;
- check imports;
- check static assets;
- check frontend compilation where applicable;
- verify the WebSocket telemetry path;
- verify relevant NATS behaviour;
- run the application where practical;
- check browser-facing behaviour;
- check Firefox behaviour where practical;
- check Chromium/Safari compatibility where relevant;
- verify deployment scripts where practical;
- update relevant documentation;
- update this master context if architecture or current behaviour changed;
- clearly report known limitations and unverified behaviour.

---

## 45. Architectural summary

The authoritative high-level architecture is:

```text
                         OPERATOR
                            │
                     Firefox preferred
                            │
                  Chromium / Safari also
                            │
                            ▼
                  ┌───────────────────┐
                  │      Cockpit      │
                  │                   │
                  │ FastAPI           │
                  │ WebSocket         │
                  │ TypeScript state  │
                  │ Views             │
                  │ Widgets           │
                  │ Actions           │
                  │ Gamepad mapping   │
                  │ Camera UI         │
                  │ ROV HUD           │
                  └─────────┬─────────┘
                            │
                      NATS Core
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
       ┌──────────────┐           ┌──────────────┐
       │   Control    │           │  Datalogger  │
       │              │           │              │
       │ Hardware     │           │ Recording    │
       │ Safety       │           │ CSV files    │
       │ Actuators    │           │ Telemetry    │
       └──────┬───────┘           └──────────────┘
              │
              ▼
           ROBOT
           HARDWARE


CAMERA PIPELINE

Camera
  │
  ▼
Capture
  │
  ▼
Lens correction / Dewarp
  │
  ▼
Canonical processed video
  ├──────────────► WebRTC ──────► Browser
  │
  └──────────────► Recording ──► Disk


NETWORK

                 Raspberry Pi
                      │
          ┌───────────┴───────────┐
          │                       │
   Existing network          Standalone mode
          │                       │
          │                DHCP / gateway
          │                       │
          │                Captive portal
          │                       │
          └───────────┬───────────┘
                      │
                      ▼
                Operator browser
```

The key architectural principles are:

> **One robot — one Cockpit.**

> **The Raspberry Pi lives in the robot.**

> **The browser is the operator interface.**

> **NATS Core is the internal service boundary.**

> **Control owns physical control and safety.**

> **Datalogger owns recording and CSV generation.**

> **Cockpit owns operator interaction and presentation.**

> **Camera processing produces one canonical video feed for both live WebRTC
> display and recording.**

> **Robot profiles provide robot-specific configuration without duplicating
> the Cockpit application.**

> **Customisation is a first-class design goal.**

> **Blue Robotics Cockpit is design inspiration, not an architectural
> dependency.**

> **MAVLink is not used.**

> **NATS JetStream is out of scope.**

> **Offline-first operation is a production requirement.**

> **Safety must remain effective when Cockpit, the browser, WebSocket, or NATS
> connection fails.**

## Live diagnostics tray

The live view has a reusable left-hand diagnostics tray. It remains collapsed to a small tab by default and expands only within the space between the status bar and bottom dock. The initial item is the estimated browser-to-Cockpit upload/download rate; it is a read-only browser diagnostic, not robot Wi-Fi, Internet, NATS, or Control-health telemetry. Future diagnostic widgets may populate the tray without changing the primary HUD or receiving control authority.

## Browser-assisted system time synchronisation

An RPi without an RTC may start with an invalid clock. When the active robot profile enables `time_synchronisation`, an authenticated Cockpit `driver` or `admin` browser sends its UTC Unix time in milliseconds to Cockpit on page load and then every 60 seconds. Cockpit validates the active profile and relays the message over `<namespace>.cockpit.command.system.time-sync`; the browser never connects to NATS and neither Cockpit nor browser sets the host clock directly.

Control loads the same profile at boot, accepts only the matching profile/subject/`ms` payload within the documented UTC date range, and uses Linux `time.clock_settime` only when its clock differs by at least the profile threshold. Its systemd unit receives the narrowly scoped `CAP_SYS_TIME` capability and reports `adjusted` or `within-tolerance` through `<namespace>.control.status.system.time-sync`. The mechanism is an offline bootstrap aid, not a replacement for trusted NTP, and remains unbench-tested on Raspberry Pi hardware.
## Battery telemetry contract

Battery state-of-charge telemetry is a numeric percentage in the inclusive
`0–100` range. Legacy `0–10` and `0–1` scaling is not supported.
All Cockpit HTML pages use the shared `templates/base.jinja` shell and
`templates/header.jinja` navigation. Page-specific templates must not recreate
the document head or primary navigation; they provide content and scoped
scripts through Jinja blocks. The FastAPI page renderer injects the active
robot profile explicitly into every page context, so these shared templates
can safely use the profile identity without relying on mutable Jinja globals.
The shared header is a compact translucent operator shell: it contains the ROV
identity, a status/alert surface, battery percentage, voltage, a browser-local
24-hour clock with a 1 Hz flashing colon, and a `Link` indicator for the Cockpit browser WebSocket. The central alert surface obtains read-only state from `/api/system/status`: `Simulation mode` takes precedence, `NATS offline` is displayed while the server-side NATS client is disconnected, and `No recent alerts.` is used otherwise. Navigation is
provided through its hamburger-triggered translucent popover. The hamburger button remains geometrically centred while its three-bar glyph has a small independent downward optical adjustment to align it with the otter/ROV identity lock-up without changing the hit area. `Link` is not a
claim of NATS broker health. The shared header does not show temperature,
heading, depth, or uptime; these remain in the appropriate live HUD and
telemetry/data views.
The live ROV page also has a translucent bottom dock. Its implemented metrics
are read-only camera, depth, heading, roll, pitch, primary-light percentage,
camera tilt, and water-temperature presentation. Future
profile-defined controls may occupy the dock only after they have an authorised
Cockpit-to-Control command contract; the dock must never become an implicit
owner of arming, actuator, or safety behaviour.
The HUD heading tape centres the current heading beneath its amber marker and
centres each tick before applying its relative bearing offset. Its 3-degree
minor ticks, intermediate 15-degree ticks, and the largest North/0-degree tick
share that coordinate system, keeping labels readable while the heading changes.
