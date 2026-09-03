# CuttleOS NATS Contract

> **Status:** Architectural contract for application-level messaging.
>
> The concrete subject set and payload schemas are maintained by the current
> CuttleOS implementation and robot-profile requirements. This document defines
> the contract principles and layering rules.

## 1. Purpose

NATS Core is the application integration boundary between CuttleOS services and
between CuttleOS and SquidLink.

NATS is not the hardware bus protocol, the browser transport, or the simulation
API.

## 2. Layering

```text
Cockpit ────────┐
                ↓
             NATS Core
                ↓
             Control
                ↓
          hardware interface
                ↓
             RS-485
                ↓
          embedded hardware

SquidLink ──────┘
                ↓
        NATS/ROS 2 bridge
                ↓
              ROS 2
                ↓
             Gazebo
```

The NATS application contract is common to real and simulated systems. SquidLink
translates that contract to ROS 2 rather than creating a competing application
interface.

## 3. Middleware

- NATS Core is the selected live application middleware.
- NATS JetStream is explicitly out of scope for the current robot architecture.
- The browser MUST NOT connect directly to NATS.
- Persistent operational recording belongs to Datalogger and its SQLite store.

NATS Core is therefore primarily a live transport and integration mechanism,
not the authoritative historical data store.

## 4. Subject naming

Subjects are namespaced by robot/application context and are defined by the
current CuttleOS application contract and robot profiles.

The exact subject catalogue MUST NOT be duplicated independently in SquidLink
or NautiPi.

Subject names should represent application semantics rather than physical
implementation details.

Prefer:

```text
<namespace>.command.light.level
```

over an implementation-specific subject such as:

```text
<namespace>.gpio.17.pwm
```

when the latter is merely an implementation detail.

## 5. Payload requirements

Messages carrying physical quantities SHOULD define, explicitly or through the
contract:

- quantity meaning;
- unit;
- scale;
- valid range;
- timestamp/timebase;
- source where relevant;
- failure or invalid-state representation.

Payloads MUST NOT rely on a unit being inferred from a UI label alone.

## 6. Commands

Commands represent logical intent. Control is responsible for validating and
interpreting commands before they affect hardware.

A NATS message arriving successfully does not, by itself, imply that the command
is safe, valid, or executable.

Control MUST retain independent safety mechanisms, including command timeout and
neutral behaviour as defined by its control architecture.

## 7. Telemetry

Telemetry is published by the authoritative producer and may be consumed by
Cockpit, Datalogger, SquidLink, or other permitted consumers.

Consumers MUST NOT modify an authoritative telemetry message and republish it as
though it were the original source.

## 8. Datalogger boundary

Datalogger observes agreed NATS subjects and records them. It MUST NOT intercept,
modify, delay, acknowledge on behalf of, or become a dependency for control
messages.

The raw recorded message and its provenance should remain available for later
analysis.

## 9. Simulation boundary

SquidLink MUST use the same application-facing NATS contracts as the real robot.
The NATS/ROS 2 bridge owns transport and translation between NATS and ROS 2.

ROS 2 topic names, message types, and Gazebo interfaces are internal to
SquidLink and do not redefine the CuttleOS application contract.

## 10. Change control

Changes to subjects, payload schemas, units, ranges, timestamps, or failure
semantics are system-level interface changes.

Such changes MUST update the relevant CuttleOS documentation, robot-profile
requirements, implementation, and tests, together with affected SquidLink or
hardware integration documentation where applicable.
