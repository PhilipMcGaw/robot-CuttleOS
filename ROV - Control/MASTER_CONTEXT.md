# ROV Control — Master Context

> **Role of this file:** Compact, persistent project context for humans and AI assistants working on ROV Control.
>
> **Authority rule:** Current code + physical bench evidence > current status/roadmap > this file > older documentation/chat recollection.
>
> **Maintenance rule:** Update this file whenever a significant architecture decision, physical validation result, safety behaviour, deployment mechanism, interface contract, or roadmap priority changes.

---

## Purpose

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

---

## Robot architecture

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
      └── telemetry and event recording
```

The services communicate through **NATS Core**.

```text
                         NATS Core
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
       Cockpit           Control          Datalogger
          │                 │                 │
     operator UI      physical hardware    recording
```

Control is the authority for physical hardware.

Cockpit is the authority for operator interaction.

Datalogger is observational and must not block or destabilise Control.

NATS JetStream is outside the current architecture and scope.

---

## Runtime boundary

The documented Linux development convention is to clone this repository as:

```text
~/robots/ROV---Control
```

alongside the other ROV repositories.

On macOS, use a user-selected workspace beneath the home directory, for example:

```text
~/Projects/ROV/ROV---Control
```

This is a documented convention only. Scripts must derive paths from their own location so that the repository remains movable.

The production runtime is Raspberry Pi OS, based on the Raspberry Pi Foundation's supported Debian-based operating system. The selected baseline is Raspberry Pi OS Trixie Lite 64-bit (`arm64`) on a Raspberry Pi 3B+ or newer 64-bit model. This headless baseline preserves the Pi 3B+'s 1 GB RAM for the co-installed robot services. It is an intended, unbench-tested baseline until clean-image and physical commissioning evidence is recorded. Legacy 32-bit is a temporary compatibility fallback only when a specific verified dependency cannot use Trixie 64-bit.

Windows and macOS are development environments. They are not the production hardware-control target.

The Control service must remain capable of being developed and tested without physical hardware where practical, but hardware and Raspberry Pi behaviour are authoritative.

---

## Communication architecture

NATS Core is the selected inter-service middleware.

The deployed local NATS server is authenticated and defaults to:

```text
nats://<configured-user>:<configured-password>@127.0.0.1:4222
```

The Cockpit provisioner derives the robot-service URL from ignored Control
secrets and installs it in the root-readable systemd environment file:

```text
/etc/robot/nats.env
```

`configs/nats.env` controls whether the NATS listener remains loopback-only or
is opened, with authentication, for an explicitly trusted HiL/SiL network.

Control consumes logical actuator demands and publishes hardware and sensor telemetry through NATS.

Cockpit must never communicate directly with physical hardware.

The logical communication path is:

```text
Cockpit
   │
   │ logical actuator demand
   ▼
NATS Core
   │
   ▼
Control
   │
   │ physical mapping, mixing,
   │ limits and safety
   ▼
Hardware
```

Telemetry follows the reverse path:

```text
Hardware
   │
   ▼
Control
   │
   ▼
NATS Core
   │
   ├── Cockpit
   └── Datalogger
```

Control must not require an acknowledgement from Cockpit or Datalogger before processing an actuator demand.

Datalogger failure must never block the control path.

---

## Command model

Cockpit sends **logical motion and actuator demands** rather than directly commanding physical motor outputs.

Control owns the conversion from logical demands to physical actuator commands.

For a multi-thruster or multi-motor robot, the intended architecture is:

```text
Logical motion demand
        │
        ▼
     Control
        │
        ├── mixing
        ├── direction
        ├── scaling
        ├── limits
        ├── neutral
        └── timeout/safety
        │
        ▼
Physical actuator demands
```

This keeps robot-specific physical behaviour out of Cockpit.

Examples of logical demands may include:

```text
surge
sway
heave
yaw
camera pitch
other configured actuator functions
```

The exact command vocabulary remains subject to the shared robot-profile and NATS interface documentation.

---

## Control loop

A fixed control-loop rate has **not yet been selected**.

The control-loop rate must be established from the requirements of the actual actuator hardware, sensor update rates, command timeout requirements, and Raspberry Pi implementation.

Do not invent or prematurely standardise a control-loop frequency.

Once selected, document:

- nominal loop rate;
- maximum acceptable loop latency;
- actuator update rate;
- sensor sampling/update rate;
- command timeout;
- behaviour when the loop overruns;
- behaviour when hardware communication is delayed or lost.

---

## Safety

Control owns physical actuator safety.

The Cockpit must not be the only propulsion safety layer.

The intended eventual safety architecture includes:

- physical emergency stop;
- software emergency stop;
- command timeout;
- safe startup;
- neutral on communication loss;
- actuator limits;
- configured direction limits;
- controlled hardware enable/disable behaviour.

The physical emergency-stop architecture is a future production requirement and must not be described as physically validated until it has been implemented and tested.

### NATS / command-link loss

If NATS connectivity or the command path is lost, Control must apply **neutral**.

Control must not continue applying the last received propulsion demand indefinitely.

The exact timeout value remains to be established.

The safe-state behaviour belongs entirely within Control and must not depend on Cockpit remaining operational.

### Startup

Control must start in a non-driving safe state.

Hardware outputs must not become active merely because the service has started.

Control must validate its configuration and hardware requirements before enabling normal actuator operation.

### Testing

Hardware testing must be performed with propulsion:

- disconnected;
- disabled;
- mechanically restrained; or
- otherwise rendered safe.

Physical power isolation must remain available during every hardware test.

Never claim hardware validation based solely on software tests, simulation, documentation, or expected hardware behaviour.

---

## Hardware architecture

Control uses a hardware-abstraction structure so that hardware-specific implementation remains separate from command handling and safety logic.

The intended structure is:

```text
Control
│
├── NATS
│
├── profile
│
├── safety
│
├── command handling
│
├── mixer
│
└── hardware
      ├── motors / thrusters
      ├── servos
      ├── sensors
      ├── GPIO
      ├── I2C
      ├── SPI
      ├── PWM
      ├── serial
      └── RS-485
```

Most distributed robot hardware is expected to communicate through RS-485.

RS-485 is not exclusive. Hardware directly attached to the Raspberry Pi may use GPIO, I²C, SPI, PWM, serial, or another appropriate interface.

Hardware communication belongs in drivers.

Engineering intent belongs in the higher-level Control logic and robot profile.

Do not place hardware-specific implementation in Cockpit.

---

## Planned Adeept Robot HAT ADM133 adapter

Control will provide a shared hardware adapter for the Adeept Robot HAT
ADM133 (V3.3 family) used by K9 and PiWars. This is a Control responsibility:
Cockpit publishes logical commands and must not access the board directly.

The active robot profile will select the adapter and define its confirmed
channel assignments and safe operating configuration. The exact board map,
electrical connections, output directions, limits, and bench validation have
not yet been established. This work remains planned and unverified.

The adapter consumes and publishes only profile-bound logical NATS commands
and telemetry. Its full capability-to-topic contract is in
`docs/adeept-robot-hat-adm133.md`; raw GPIO, I2C, PWM-channel, and
motor-channel NATS subjects are prohibited.

`docs/adeept-robot-hat-adm133-interfaces.md` is the port-level interface and
commissioning guide. It distinguishes vendor-sample pin mappings from mappings
that must still be verified on the fitted ADM133 board. Its source inventory is
the supplied manufacturer V3 archive and Philip's ADM133 board notes; neither
replaces recorded board-level commissioning evidence.

ADM133 servo channels use stable physical aliases `servo-00` through
`servo-15`. Robot profiles map semantic aliases, such as K9 `head-pan`, to
those ports. The aliases are Control configuration, not Cockpit commands, and
the vendor motor sample reserves channels `8–15` whenever the matching motor
function is enabled.

---

## RS-485 architecture

RS-485 is the preferred physical communication bus for most distributed robot nodes.

A typical architecture is:

```text
Raspberry Pi
     │
     │ RS-485
     │
     ├── node
     ├── node
     ├── node
     └── node
```

The exact electrical implementation, baud rate, termination, biasing, protocol timing, and node count remain hardware-design decisions and must not be invented in this context until confirmed.

### Node identity

Each microcontroller node has a manufacturer-programmed factory UID.

The factory UID provides a persistent physical hardware identity.

The RS-485 bus address is a separate commissioned identity.

The intended model is:

```text
MCU node
│
├── factory UID
│     └── permanent hardware identity
│
└── internal EEPROM / non-volatile memory
      └── commissioned RS-485 address
```

The RS-485 address is stored in the **microcontroller's own EEPROM or equivalent non-volatile memory** during commissioning.

A separate external EEPROM is not required merely to store the bus address.

The factory UID must not normally be used as the runtime RS-485 address.

### Commissioning

During commissioning:

1. identify the physical MCU using its factory UID;
2. assign a unique RS-485 address;
3. write that address to the MCU's internal EEPROM/NVM;
4. verify that the node responds using the assigned address;
5. record the physical-node identity and logical function;
6. verify that the bus contains no duplicate addresses.

The commissioned RS-485 address is hardware configuration.

The robot profile describes the logical function of a node and its required capabilities; it must not become a database of factory MCU UIDs.

This separation allows the same robot profile to be reused across multiple physical robots.

---

## Hardware drivers

Hardware drivers must isolate physical interfaces from the rest of Control.

A driver should expose a stable application-level interface rather than requiring the rest of the service to know about GPIO registers, serial framing, RS-485 transactions, PWM implementation, or specific MCU details.

Drivers must:

- validate inputs;
- enforce hardware-safe ranges;
- report communication failures;
- expose hardware status;
- avoid silently substituting invalid values;
- provide deterministic failure behaviour;
- be mockable for software tests where practical.

Hardware drivers must not contain operator-interface or browser logic.

---

## Servo and camera control

Camera pitch is treated as a generic actuator capability rather than a special-case Cockpit function.

The robot profile defines the physical mapping, including relevant:

- actuator identity;
- home position;
- direction;
- limits;
- scaling;
- logical range.

Control publishes:

```text
sensor/camera/main/pitch
```

when the camera servo demand is applied.

The value represents the **commanded servo angle relative to the 90° home position**, with:

```text
0° = camera straight ahead
```

This value is command-derived rather than physical feedback.

It must therefore not be described as measured camera orientation until physical feedback and/or bench validation establishes that correspondence.

---

## Robot profiles

Robot profiles allow the same Cockpit, Control, and Datalogger architecture to support different robot types without requiring major changes to the services.

Current intended profiles include:

```text
ROV
K9
PiWars
```

Additional robot types may be added later.

The profile separates:

- robot type;
- robot capabilities;
- logical actuator functions;
- physical actuator mappings;
- sensor configuration;
- hardware requirements;
- limits;
- servo configuration;
- network-related robot settings where appropriate.

One robot profile may be deployed to multiple individual robots.

### Robot identity

Robot **type** and robot **identity** are separate concepts.

For example:

```text
robot_type = rov
robot_id   = rov-001
```

This allows multiple physical robots to use the same profile while retaining distinct identities.

Individual robot identities will be useful for:

- PiWars;
- telemetry;
- logging;
- commissioning;
- network identification;
- future multi-robot development;
- fault and maintenance records.

The exact identity format remains to be finalised.

---

## Profile source of truth

Robot profiles currently originate in the Cockpit repository under:

```text
configs/profiles/
```

Cockpit is the source of truth for the shared profile definitions.

Control consumes the deployed active profile.

Control must not maintain an independently edited copy of the physical mapping.

The shared runtime profile is initially installed at:

```text
/etc/robot/profile.json
```

on the robot Raspberry Pi.

Cockpit, Control, and Datalogger use the same active profile identity and configuration.

A profile change requires a controlled restart or reboot.

Profiles are not applied live.

---

## Profile validation

Control must validate the active robot profile during boot before enabling normal hardware outputs.

Validation must cover the requirements necessary for safe operation, including where applicable:

- profile syntax;
- profile identity;
- robot type;
- required hardware;
- actuator mappings;
- configured limits;
- required node addresses;
- supported driver types;
- required configuration values.

If profile validation fails:

```text
Control starts
      │
      ▼
Profile validation fails
      │
      ▼
Remain in safe non-driving state
      │
      ▼
Report clear error
      │
      ▼
Configuration must be corrected
```

Control must **not silently run with an incomplete or incompatible profile**.

If required hardware is missing or the profile does not match the installed hardware, Control must flag an error and request that the configuration be corrected.

Optional hardware must be explicitly represented as optional rather than inferred from missing hardware.

---

## Networking

Control owns the robot's network configuration and network runtime state.

Control is responsible for:

- network-link status;
- NATS connectivity;
- reconnect behaviour;
- safe handling of command-link loss;
- deployment of the approved Raspberry Pi network configuration.

Cockpit and Datalogger must not be required to configure or maintain the robot network.

### Network startup

The preferred network sequence is:

```text
Robot boot
   │
   ▼
Attempt configured Wi-Fi client connection
   │
   ├── success ──► normal network operation
   │
   └── failure
          │
          ▼
     fallback hotspot
          │
          ├── DHCP
          ├── gateway
          └── local DNS
```

The robot should first attempt to attach to the configured local Wi-Fi network.

If that is unavailable, it should fall back to a Raspberry Pi-hosted wireless network.

The fallback network provides:

- DHCP;
- gateway capability;
- access to the Cockpit;
- local DNS.

The hotspot provides NetworkManager shared-mode DHCP, local DNS, and a path
into Cockpit. A captive portal is not implemented.

The client-preferred/hotspot-fallback behaviour is configured but requires
physical validation on Raspberry Pi hardware.

### Fallback network

The current fallback convention is:

```text
network: 192.168.42.0/24
robot:   192.168.42.1
DHCP:    NetworkManager shared-mode allocation within the subnet
```

The `.42` choice is intentional: it references *The Hitchhiker's Guide to the Galaxy* and was selected because this private range is not used elsewhere in the current environment. It is a convention, not a guarantee of conflict-free use on every network; deployments must avoid overlapping networks.

The exact implementation remains subject to validation against Raspberry Pi OS and NetworkManager behaviour.

### Network services

Control may deploy or orchestrate:

- NetworkManager configuration;
- hostname;
- Avahi/Zeroconf;
- Samba prerequisites where required by the robot deployment.

SMB access must be authenticated and limited to the intended media directory.

Cockpit remains responsible for its application and media behaviour.

---

## Network deployment

The initial deployment helper is:

```text
scripts/0_deploy_network.sh
```

It uses NetworkManager and:

```text
configs/network.env
configs/network.secrets.env
configs/nats.env
```

where the secrets file is ignored by version control.

The deployment supports:

- wired DHCP;
- wired static addressing;
- multiple prioritised Wi-Fi client profiles;
- a lower-priority hotspot fallback profile;
- authenticated NATS configuration through the Cockpit provisioner;
- authenticated SMB/Avahi media sharing.

The Wi-Fi profiles use NetworkManager auto-connect priorities to prefer known
networks before the hotspot. This is implemented configuration, not yet
Raspberry Pi physically validated. Wired operation remains deliberately either
DHCP or static; automatic wired DHCP-to-static failover and a wired DHCP server
are not implemented. The deployment helper starts NetworkManager before it
changes profiles, then reloads the connection definitions without restarting the
daemon, so it does not intentionally terminate an SSH deployment session. A
reboot, link reconnect, or explicit reviewed profile activation is required for
an immediate address change. A wired static interface MUST NOT use the wireless
hotspot subnet while the hotspot can be active. The `--dry-run` mode validates
the configuration contract without querying live NetworkManager state; the
non-dry run validates the named interfaces on the robot.

---

## Credentials and secrets

For development, reproducible test Wi-Fi and NATS credentials may be committed where necessary to make repositories easy to move between development machines.

Before robot or shared-network deployment:

- regenerate development credentials;
- copy real values into ignored Control secrets files;
- protect secrets with restrictive permissions;
- never commit real deployment secrets;
- never place service tokens or API keys in the shared robot profile.

Example configuration files must contain safe placeholders only.

---

## Remote SSH verification access

Remote command access is an optional operational aid for an active Codex task,
not a route to unattended robot control. The maintained procedure is:

```text
docs/remote-ssh-access.md
```

When configured, each robot SHALL have a unique Zeroconf hostname, dedicated
`codex` account, and unique Ed25519 SSH key. The key name and local SSH alias
MUST identify the robot unambiguously, for example `k9` and
`codex_robot_k9`. The private key MUST remain on the trusted operator computer
and MUST NOT be committed, copied to SMB, or shared in chat.

The `codex` account MUST use public-key authentication and begin without
`sudo` authority. Routine actions are read-only checks. State-changing actions,
including service restarts, network deployment, profile changes, and hardware
access, require explicit operator authorisation. Direct public-Internet SSH
exposure is prohibited; remote access requires a separately secured private
network if needed.

This access pattern is documented but has not been configured or Raspberry Pi
bench-validated for a robot.

---

## Production platform

The production target is:

```text
Raspberry Pi
+
Raspberry Pi OS
+
NATS Core
+
ROV Control
+
ROV Cockpit
+
ROV Datalogger
```

Control must be designed around the actual Raspberry Pi hardware and Linux runtime.

Windows and macOS are development platforms only.

Windows development scripts are useful for standalone development and testing, but Windows is not expected to provide equivalent physical hardware functionality.

Hardware-specific imports must not prevent sensible software-level testing where they can reasonably be isolated.

---

## Development

Install the repository requirements into a project environment, then run:

```bash
PYTHONPATH=src python -m rov_control.main
```

On the deployed Raspberry Pi, use the service launcher and systemd configuration provided by the repository.

The service requires NATS Core to be available before normal actuator operation.

The exact service files and paths are authoritative in the current repository.

---

## Repository layout

The expected repository structure is:

```text
src/rov_control/
    live Python package

configs/
    service and hardware configuration

docs/
    engineering, deployment, hardware,
    interface, and testing documentation

tests/
    automated tests

scripts/
    deployment and development helpers
```

The actual current repository structure is authoritative.

Do not preserve obsolete repository paths merely because they appear in older documentation.

---

## Windows development support

Windows development uses:

```text
scripts/1_install_dependencies.bat
scripts/2_start_app.bat
```

These scripts use project-local portable Python and do not use `uv`.

They must not require administrator rights for normal application development.

They must not modify the Windows system or user `PATH`.

Hardware functionality requiring Raspberry Pi Linux, GPIO, physical RS-485, or other Linux-specific facilities cannot be fully validated on Windows.

Windows support exists to make development and software-level testing convenient, not to redefine the production platform.

---

## Shell and scripting standard

Interactive command examples assume Zsh.

Shell scripts may use the interpreter declared by their shebang. Documentation must keep interactive commands Zsh-compatible and identify script-specific interpreter requirements.

Windows batch, PowerShell, Bash, and other scripts must use a deliberately verbose diagnostic style suitable for engineering environments.

Scripts should use:

```text
[INFO]
[PASS]
[WARN]
[FAIL]
[SKIP]
```

status labels where appropriate.

Scripts must:

- derive paths from their own location;
- use project-relative or explicit paths;
- validate prerequisites;
- check important command exit statuses;
- fail clearly when prerequisites are missing;
- preserve useful diagnostic information;
- avoid unnecessary system changes;
- avoid modifying PATH;
- be safe to rerun where practical;
- distinguish detected, installed, configured, connected, bench-tested, and physically validated states;
- finish with a clear environment summary.

The Raspberry Pi deployment scripts may require `sudo` where they modify system services or network configuration. Such requirements must be explicit.

Downloads must use checksums or a trusted manifest where available.

Vendor drivers, SDKs, and native libraries remain separate deployment dependencies where required.

---

## Testing and validation

Control is a hardware-facing service.

Testing must distinguish clearly between:

- designed;
- planned;
- implemented;
- unit-tested;
- integration-tested;
- simulated;
- bench-tested;
- physically validated;
- production-proven.

Software tests must not be described as hardware validation.

Hardware validation must be performed on Raspberry Pi hardware with the actual relevant interfaces.

Where possible, the same Control logic should support mocked hardware drivers for software testing.

HiL/SiL and simulation are secondary validation mechanisms. They must not become the authoritative definition of physical hardware behaviour.

---

## Documentation quality standard

The enforceable documentation policy is:

```text
docs/documentation-policy.md
```

Contributor guidance is:

```text
CONTRIBUTING.md
```

Current status is maintained in:

```text
docs/status.md
```

Documentation checks include:

```text
tests/test_documentation.py
tests/documentation_change_policy.py
tests/documentation_change_policy.json
```

Documentation is part of the implementation.

Whenever behaviour, an interface, driver, deployment rule, safety rule, configuration format, or validation result changes, update the relevant documentation and this `MASTER_CONTEXT.md` in the same change.

Every change must include a consistency check of this file.

If the file does not accurately describe current behaviour, correct it immediately rather than knowingly leaving it stale.

Use formal British English throughout project documentation.

Use terminology such as:

- `licence`;
- `behaviour`;
- `optimise`;
- `centre`.

Write for a reader with an engineering degree or equivalent professional experience.

Retain technical precision and define project-specific terminology where required.

Avoid unexplained marketing language.

Use clear, direct prose and explicit assumptions.

Where SI units are used, place a space between the numerical value and the unit symbol:

```text
5 m
12 V
20 °C
100 ms
1 Hz
```

Use the degree symbol `°` for angles where practical.

---

## Change-control rules

Before implementation:

1. Read this file.
2. Inspect the existing implementation.
3. Identify the architectural layer that owns the requested change.
4. Check the relevant documentation and current status.
5. Check safety implications.
6. Check whether the change affects NATS contracts or robot profiles.
7. Check whether the change affects hardware validation or traceability.

During implementation:

- make the smallest safe change;
- preserve working behaviour;
- avoid unrelated refactoring;
- introduce no unrequested framework or dependency;
- keep hardware communication inside drivers;
- keep physical safety inside Control;
- keep operator-interface behaviour inside Cockpit.

After implementation:

1. Run relevant automated tests.
2. Run the application where practical.
3. Check imports and configuration.
4. Check relevant NATS communication paths.
5. Check hardware-driver behaviour where hardware is available.
6. Check safe-state behaviour.
7. Update relevant documentation.
8. Update this master context if architecture or behaviour changed.
9. Clearly report known limitations and validation status.

Never invent a physical validation result.

If current implementation and documentation disagree, identify the discrepancy explicitly and resolve it using the project authority hierarchy.

---

## Architectural principles

The following principles are considered fundamental:

1. **Control owns physical hardware.**
2. **Control owns propulsion safety.**
3. **Cockpit does not directly control hardware.**
4. **Datalogger is observational.**
5. **NATS Core is the inter-service middleware.**
6. **NATS JetStream is out of scope.**
7. **Logical commands are separated from physical actuator mapping.**
8. **Robot profiles are shared configuration, not independently maintained per service.**
9. **Robot type and individual robot identity are separate.**
10. **RS-485 is the preferred distributed hardware bus, but Pi-local interfaces remain supported.**
11. **RS-485 node addresses are commissioned into MCU internal EEPROM/NVM.**
12. **Factory MCU UID and commissioned RS-485 address are separate identities.**
13. **Profile/hardware mismatches produce an error and require configuration correction.**
14. **NATS command-link loss results in neutral.**
15. **The physical emergency stop is ultimately part of the production safety architecture.**
16. **Production Raspberry Pi hardware is the primary target.**
17. **Simulation and HiL/SiL are secondary validation mechanisms.**
18. **Camera pitch is a generic actuator capability, not a Cockpit-specific hardware special case.**
19. **The robot should attempt normal Wi-Fi before falling back to its own hotspot.**
20. **The fallback hotspot provides DHCP, gateway functionality, captive-portal configuration, and Cockpit access.**
21. **Documentation must accurately reflect implementation and validation state.**

---

## Quick start for a new AI conversation

When this file is supplied to a fresh AI conversation, assume:

- this is the ROV's production hardware-control service;
- the service runs on a Raspberry Pi inside the robot;
- Raspberry Pi OS is the production operating system;
- Windows and macOS are development environments;
- NATS Core is the inter-service middleware;
- NATS JetStream is out of scope;
- Cockpit sends logical commands;
- Control performs physical mapping and mixing;
- Control owns propulsion safety;
- Datalogger is observational;
- most distributed hardware communicates over RS-485;
- Pi-local GPIO, I²C, SPI, PWM, and serial hardware is also permitted;
- RS-485 addresses are stored in MCU internal EEPROM/NVM during commissioning;
- MCU factory UID is the persistent physical hardware identity;
- robot profiles are shared across Cockpit, Control, and Datalogger;
- robot type and individual robot identity are separate;
- profile/hardware mismatches must be reported and corrected rather than silently ignored;
- NATS command-link loss results in neutral;
- the control-loop frequency is not yet selected;
- physical emergency-stop hardware is an eventual production requirement;
- camera pitch is treated as a generic servo/actuator capability;
- the Pi attempts configured Wi-Fi before falling back to its own hotspot;
- the fallback hotspot provides DHCP, gateway, captive-portal configuration, and Cockpit access;
- production hardware is the primary target;
- simulation is secondary;
- no hardware validation may be invented.

Before making a change, inspect the current implementation and relevant documentation rather than relying on old chat history.

## Browser-assisted system time synchronisation

An RPi without an RTC can start with an invalid clock. The active shared profile may enable a time-synchronisation contract. An authenticated Cockpit driver/admin browser provides UTC Unix milliseconds on page load and every 60 seconds; Cockpit relays the message on `<namespace>.cockpit.command.system.time-sync`. The browser does not access NATS or Linux hardware.

Control reads the same profile at boot and accepts only the configured subject, profile identity, `ms` unit, and an accepted UTC date range. It permits a large first adjustment because an RTC-less Pi may begin near 1970, avoids changes within the configured tolerance, and emits `adjusted` or `within-tolerance` on `<namespace>.control.status.system.time-sync`. Only Control calls `time.clock_settime`; its systemd service is granted `CAP_SYS_TIME`, rather than being run as root. This is an offline bootstrap mechanism, not a trusted NTP replacement, and is implemented but not Raspberry Pi bench-tested.
