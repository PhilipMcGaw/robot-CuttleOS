# Robot Profile Framework Requirements

## Purpose

The Cockpit and Controller shall use one common, versioned framework across the ROV, K9, PiWars, and future robot projects. Robot-specific behaviour shall be expressed through a validated profile and Controller configuration rather than duplicated application code.

## Deployment model

Each robot shall have its own Raspberry Pi for the foreseeable future. Cockpit, Controller, and Datalogger are separate repositories and services, but are installed together on that robot Pi and shall use one active robot profile. They exchange commands, telemetry, status, and logging data through NATS Core. HiL/SiL is separate: it runs in a virtual machine and connects to a headless robot or headless robot services through the same application-facing interfaces.

Profile selection is an installation or maintenance operation performed over SSH, not an operator UI function. Git is the source of truth for framework code, profiles, schemas, and documentation. A deployment shall record the robot name, profile name, framework Git revision, profile revision or commit, configuration hash, and deployment date.

Profiles shall be loaded and validated during system boot before Cockpit, Controller, or Datalogger is allowed to start. Profile changes shall require a controlled service restart or reboot; live profile replacement is not required.

## Profile format and scope

At present, robot profiles shall live in the Cockpit repository under `configs/profiles/`. The Cockpit repository is the source of truth for the profile files. The active profile shall be made available to Control and Datalogger through the robot deployment path without creating independently edited copies. All robot profiles shall use the same JSON format and schema. The profile shall be validated before activation and shall include a schema version. Profiles may define robot identity, an `identity_icon` from the approved Font Awesome `fa-*` icon class set, branding, enabled capabilities, namespaced telemetry and logical command subjects, SI units, raw-value scaling, display precision, unavailable-value behaviour, dashboard layout, cameras, media, operator input mappings, and Control-owned hardware adapters. A planned schema migration will replace library-specific values with neutral icon IDs resolved through a locally bundled registry; Lucide is the candidate for new Vue components, but Font Awesome remains current until the complete migration is implemented.

An adapter declaration under `hardware.adapters` identifies a Control driver and binds each board function to profile `commands` and `telemetry` keys. The subject text remains defined once in those command and telemetry objects; adapter bindings refer to the logical keys and Cockpit validates every reference at start-up. Cockpit does not use the adapter declaration to access hardware. Control resolves the bound logical topics to its drivers, physical channels, calibration, and safety limits.

Where an adapter has named physical actuator ports, a profile may also define
`actuators`. Each entry has a robot-purpose alias, such as `head-pan`, and
maps it to a stable Control port alias and logical command. For the ADM133,
the canonical physical aliases are `servo-00` through `servo-15`, matching
PCA9685 channels `0` through `15`. Zero-padding prevents `servo-10` from
sorting between `servo-01` and `servo-02`.

```json
"actuators": {
  "head-pan": {
    "port_alias": "servo-00",
    "pca9685_channel": 0,
    "command": "head.pan"
  }
}
```

The purpose alias is specific to the robot; the port alias is stable across
robots. Cockpit validates that the port alias matches the declared channel,
that the command exists, that it is bound to the adapter's servo function, and
that a channel is not allocated twice. The declaration remains Control-owned
configuration: Cockpit MUST NOT use it to drive a servo. Control MUST also
reject an allocation that conflicts with an enabled motor channel or fails
commissioning.

On the Raspberry Pi, the active profile shall be installed at a shared deployment path, initially `/etc/robot/profile.json`. Cockpit, Control, and Datalogger shall all read this same file at boot.

Profiles may enable browser-assisted clock synchronisation for Raspberry Pi hardware without an RTC. The `time_synchronisation` object defines the namespaced Cockpit command subject, Control status subject, synchronisation interval, and minimum adjustment threshold. The browser sends UTC Unix time in milliseconds only through Cockpit; it never connects directly to NATS or changes the system clock. Control validates the active profile identity and owns the actual Linux clock adjustment.

The profile may define the robot hostname and unique fallback network identity. The current fallback network convention is `192.168.42.0/24`; fallback addresses must remain unique when multiple robots share a wired network.

Each profile shall define one default camera and support any number of additional cameras. Camera device paths and stream endpoints shall be configuration data, not hard-coded application assumptions.

Battery state-of-charge telemetry shall use the namespaced battery-percentage topic and a numeric value in the inclusive `0–100` range, expressed as percent. `0` means empty and `100` means full. Control publishers, simulator inputs, Datalogger records, and Cockpit displays shall use this contract; legacy `0–10` and `0–1` scaling is not supported.

Camera sources shall pass through an extensible processing pipeline before reaching the common Nginx stream endpoint. The pipeline shall support source adapters for Raspberry Pi CSI, USB, and ROS 2 virtual cameras, with optional processing stages such as lens de-warping. Processing stages shall be profile-configurable so they can be introduced without changing the Cockpit camera UI or Nginx routing.

## Namespace and control boundary

Every robot shall have a distinct namespace, such as `rov`, `k9`, or `piwars`. Command and telemetry subjects shall be distinct and shall be defined by the profile. Profile validation shall reject duplicate or ambiguous mappings.

The framework's profile-defined NATS subjects are dot-separated `<robot-namespace>.command.<function>` and `<robot-namespace>.telemetry.<function>`. Service-owned status subjects use `<robot-namespace>.<service>.status.<function>`. Structured commands and telemetry use JSON payloads; NATS transport payloads remain arbitrary bytes for explicitly documented binary subjects.

The standard time-synchronisation subjects are `<namespace>.cockpit.command.system.time-sync` and `<namespace>.control.status.system.time-sync`. The command payload uses `value` as UTC Unix time in `ms`, includes `profile`, and is emitted once on an authenticated driver/admin page load and then every 60 seconds. Control may report `adjusted` or `within-tolerance` status; this is observability, not an acknowledgement required by Cockpit.

The Cockpit may map operator inputs to logical robot commands. It shall not map logical commands to individual motors, thrusters, or physical actuator channels. The Controller owns motor direction, mixing, inversion, limits, ramps, neutral behaviour, timeouts, emergency stop, and all hardware mappings.

### Command mapping flow

Command mapping is deliberately split into two stages:

```text
Gamepad / keyboard input
        ↓
Cockpit input mapping
        ↓
Namespaced logical command
        ↓ NATS Core
Controller command handling and robot-specific mixer
        ↓
Physical motor, thruster, servo, or actuator demands
```

For example, Cockpit may map a gamepad axis to `drive.forward` with a dead zone, scale, and inversion setting. It must not decide which physical motor receives that value. Control interprets `drive.forward` using the active robot's drive type and hardware mapping. An ROV may instead expose semantic axes such as `surge`, `sway`, `heave`, `yaw`, `pitch`, and `roll`; Control performs the thruster mix.

Logical command messages shall be namespaced, use SI units where applicable, and carry a value plus the command/profile identity needed for validation. Control shall reject unknown, stale, out-of-range, or unsafe commands and shall apply neutral, timeout, and emergency-stop behaviour independently of Cockpit.

Control also owns deployment of the approved Raspberry Pi robot-network configuration and runtime network/NATS health. Network-link loss and NATS command loss shall be handled safely by Control and shall not depend on Cockpit or Datalogger.

During development, reproducible test credentials may be committed to Git to make the services easy to move between development machines. Before a robot or shared network is used, credentials must be regenerated, the real values moved to ignored local secrets files, and those files protected with restrictive permissions. Real deployment credentials must not be stored in the shared robot profile or committed to Git. Example templates shall document the required fields without containing real deployment values.

## Example profiles

The framework shall provide functional ROV, K9, and PiWars profiles. K9 shall include its optional soundboard capability, a `sound.play` command on `<namespace>.command.sound.play`, and a soundboard list of stable IDs, operator labels, and Control-resolved file names. Cockpit shall expose this list only through a K9/profile-enabled drawer and shall publish an authenticated selected ID; it shall not control speaker hardware or serve the sound files. K9 and PiWars shall declare their shared ADM133 adapter and bind its currently selected board functions to profile topic keys. PiWars shall support configurable competition-oriented controls and sensors. Where physical hardware is not yet available, the examples shall run against mock or simulated Controller behaviour and shall label unverified or planned capabilities explicitly.

## Consistency and maintenance

Common framework improvements shall be made to shared code and tested against all example profiles. Robot-specific differences shall not be implemented by copying or permanently forking the Cockpit. Profile, schema, interface, safety, deployment, and documentation changes shall be reviewed together.

Every behaviour-affecting change shall update the relevant `MASTER_CONTEXT.md`, `README.md`, and `docs/` page. Automated documentation and profile-validation checks shall run locally and in CI.
