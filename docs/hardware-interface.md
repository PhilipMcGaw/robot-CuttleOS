# CuttleOS Hardware Interface Architecture

> **Status:** Architectural authority for the software-facing hardware boundary.
>
> Physical implementation remains authoritative in robot-NautiPi. Cross-repository
> system architecture remains authoritative in
> [`system-architecture.md`](system-architecture.md).

## 1. Purpose

This document defines the boundary between CuttleOS Control and distributed
physical hardware.

The design separates application intent, robot control, physical transport, and
embedded hardware implementation.

```text
Application intent
       ↓
     NATS
       ↓
    Control
       ↓
Hardware interface
       ↓
 Physical bus
       ↓
 Embedded node
       ↓
 Local I/O
```

## 2. Hardware nodes

The robot may use distributed microcontroller nodes for motors, sensors,
lighting, leak detection, and other physical I/O.

A node SHOULD have:

- an immutable manufacturer/device identity;
- a configured operational bus address;
- a documented hardware revision;
- a defined firmware revision;
- a documented set of capabilities;
- defined startup and fault behaviour.

The application MUST NOT depend on a particular microcontroller model unless
that dependency is genuinely part of the hardware contract.

## 3. Identity versus address

A manufacturer's unique microcontroller identifier is useful as a persistent
identity, but SHOULD NOT be used as the normal operational bus address.

The intended model is:

```text
Manufacturer UID
      ↓
Immutable node identity
      ↓ provisioning
Configured bus address
      ↓
Normal bus communication
```

This permits an address to be changed without changing the identity of the
physical node and allows commissioning software to detect an unexpected or
replacement device.

The exact UID mechanism and address-assignment procedure are hardware-specific
and belong with the relevant NautiPi and embedded implementation documentation.

## 4. RS-485

RS-485 is the intended physical communications medium for the majority of
distributed robot nodes where its electrical and performance characteristics are
appropriate.

RS-485 is a physical-layer choice. It does not define the CuttleOS application
protocol.

The bus implementation MUST address:

- termination;
- biasing/failsafe requirements;
- node loading;
- cable topology and length;
- baud rate;
- framing;
- collision/turnaround behaviour;
- error detection;
- retry behaviour;
- loss-of-node behaviour;
- electrical isolation where required.

Actual values and topology are engineering decisions to be verified against the
physical design and test evidence.

## 5. Layering

The hardware interface is deliberately layered:

```text
CuttleOS application contract
             ↓
          NATS Core
             ↓
           Control
             ↓
   hardware abstraction
             ↓
       RS-485 protocol
             ↓
       embedded node
             ↓
       physical hardware
```

Hardware transport details MUST NOT leak into Cockpit's logical command model.

Conversely, the embedded node SHOULD NOT need to understand browser, FastAPI,
Vue, NATS, or other application-layer implementation details.

## 6. Node commissioning

A node commissioning process SHOULD establish and record:

- manufacturer/device UID;
- assigned bus address;
- hardware revision;
- firmware revision;
- capabilities;
- calibration data where applicable;
- installation location or function;
- test evidence.

Address allocation and hardware identity should be recorded so that a physical
replacement can be distinguished from an unexpected device.

## 7. Bus loading and performance

Bus utilisation is an engineering parameter and SHOULD be measurable during
integration testing.

Assessment should consider:

- number of nodes;
- message sizes;
- update rates;
- request/response overhead;
- retries;
- worst-case arbitration/turnaround;
- required control-loop timing;
- telemetry traffic.

The bus MUST be engineered so that control traffic remains within its timing
requirements without depending on optimistic average traffic.

## 8. Safety boundary

Loss or corruption of communication with a hardware node MUST have a defined
response.

Where appropriate, local hardware safety mechanisms SHOULD provide an
independent last line of defence, while Control remains responsible for the
system-level safety policy.

A communications failure MUST NOT leave an actuator in an uncontrolled state.

## 9. Ownership

- **CuttleOS:** application-facing contract, Control integration, logical
  hardware abstraction, and software validation.
- **NautiPi:** schematics, PCB, mechanical implementation, physical bus design,
  embedded hardware, and physical evidence.
- **SquidLink:** simulation of the hardware-facing behaviour where required.

Changes that cross these boundaries MUST be reflected in the appropriate
repositories and their validation evidence.
