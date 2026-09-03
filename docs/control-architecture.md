# CuttleOS Control Architecture

> **Status:** Architectural authority for the CuttleOS Control service.
>
> Cross-repository system architecture remains authoritative in
> [`system-architecture.md`](system-architecture.md).

## 1. Purpose

Control is the robot-side hardware-facing service responsible for command
validation, safety behaviour, actuator control, sensor handling, and hardware
communication.

Control is deliberately separated from Cockpit and Datalogger. Operator-interface,
media, authentication, visualisation, and recording failures MUST NOT directly
create uncontrolled actuator behaviour.

## 2. Control path

The production command path is:

```text
Operator intent
      ↓
   Cockpit
      ↓
     NATS
      ↓
   Control
      ↓
Validation and safety
      ↓
Mixing / control law
      ↓
Hardware interface
      ↓
Physical actuator
```

Cockpit expresses logical intent. It does not select GPIO pins, generate motor
PWM directly, or implement the robot's safety policy.

## 3. Safety ownership

Control owns, or delegates to an appropriate lower hardware layer, the safety
functions required to place the robot in a known safe state.

These include:

- command validation;
- actuator limits;
- command timeouts;
- neutral behaviour;
- loss-of-communications handling;
- actuator and sensor fault handling;
- startup and restart behaviour;
- emergency-stop behaviour where implemented in software;
- hardware watchdog or node-level safety interactions.

A safety mechanism MUST NOT depend solely on the browser or Cockpit remaining
functional.

## 4. Failure behaviour

The design goal is fail-safe behaviour rather than merely fault reporting.

Examples:

| Failure | Required architectural response |
|---|---|
| Browser disconnects | Control continues independently and applies its command timeout |
| Cockpit stops | Control remains responsible for actuator safety |
| Datalogger stops | Control remains operational and does not depend on logging |
| Camera/media failure | Control is unaffected |
| NATS connection is lost | Control enters its defined safe communication state |
| Hardware node disappears | Control detects the fault and applies the defined safe response |
| Control restarts | Actuators MUST return to a defined safe startup state before accepting commands |

The exact timeout values and hardware-specific responses are configuration and
implementation matters and MUST be verified by tests before production use.

## 5. Logical commands

Application commands describe operator or system intent rather than physical
implementation.

For example:

```text
set light level = 50 %
```

is preferable to exposing:

```text
GPIO 17 = PWM 128
```

The mapping from logical intent to physical implementation belongs below the
application boundary.

## 6. Actuator control

Control applies robot-profile configuration, validates the command, performs
any required mixing or control-law processing, enforces limits, and sends the
result to the hardware interface.

The actuator path MUST remain deterministic enough for the selected control
requirements. The final control-loop rate is an engineering parameter and is
not fixed by this document until measured requirements establish it.

## 7. Distributed hardware

Physical I/O is expected to be distributed across hardware nodes where useful.
Control is responsible for communicating with those nodes and interpreting
reported state, while the embedded node remains responsible for its own local
hardware interface and any explicitly delegated local safety mechanism.

The software-facing application contract MUST remain independent of the
underlying bus implementation.

## 8. Testing

Control safety shall be verified progressively:

1. unit and static tests;
2. malformed and invalid-command tests;
3. communications-loss and timeout tests;
4. actuator-limit tests with actuators disconnected where appropriate;
5. dry integration tests;
6. hardware bench tests;
7. commissioning tests;
8. production validation.

Simulation evidence and software tests MUST NOT be described as physical
validation.

## 9. Open engineering parameters

The following remain engineering parameters until verified:

- control-loop rate;
- command timeout values;
- hardware-node watchdog values;
- actuator ramp limits;
- exact emergency-stop implementation;
- fault-recovery policy for individual hardware nodes.
