# CuttleOS System Architecture

> **Status:** Architectural authority
>
> This document defines the system-level architecture shared by robot-CuttleOS,
> robot-SquidLink, and robot-NautiPi. Repository-specific implementation details
> remain authoritative in their respective repositories.

## 1. Scope and authority

CuttleOS is the software system for the robot runtime. The wider project is
split across three repositories with deliberately separate responsibilities:

| Repository | Authority |
|---|---|
| **robot-CuttleOS** | Robot software, runtime architecture, application interfaces, NATS contracts, robot profiles, media architecture, deployment, and software validation |
| **robot-SquidLink** | ROS 2/Gazebo simulation, SiL/HiL implementation, simulation scenarios, and the NATS/ROS 2 bridge |
| **robot-NautiPi** | Physical hardware designs, PCB/CAD archives, embedded hardware, and hardware-specific evidence |

CuttleOS is the **single source of truth for cross-repository system
architecture and application-level interfaces**. SquidLink and NautiPi must not
redefine those interfaces; they implement or exercise them within their own
boundaries.

The authority hierarchy is:

1. Current code and physical bench evidence;
2. Current status and roadmap;
3. This system architecture and repository-specific authoritative documentation;
4. Older documentation and chat recollection.

Designed, simulated, or software-tested behaviour must never be described as
physically or production validated without evidence.

## 2. Repository boundaries

### robot-CuttleOS

CuttleOS owns the robot's production software stack:

- Cockpit — operator-facing web application;
- Control — hardware-facing control and safety service;
- Datalogger — telemetry and event recording;
- NATS Core messaging;
- robot profiles and application configuration;
- common media acquisition/distribution/recording architecture;
- deployment and provisioning;
- software tests and integration contracts.

### robot-SquidLink

SquidLink owns the simulation and integration-test environment:

- ROS 2;
- Gazebo;
- simulated vehicles, sensors, and environments;
- SiL and future HiL scenarios;
- ROS 2 nodes and simulation-specific models;
- the NATS/ROS 2 bridge;
- repeatable simulation and integration-test scenarios.

ROS 2 and Gazebo are implementation details of SquidLink. CuttleOS does not
become ROS-dependent merely because SquidLink uses ROS internally.

### robot-NautiPi

NautiPi owns physical hardware:

- PCB and schematic designs;
- mechanical/CAD designs;
- embedded hardware designs;
- hardware component and assembly records;
- physical test and commissioning evidence.

NautiPi does not become the authority for the CuttleOS software architecture.

## 3. Runtime architecture

The normal production deployment is one robot with one Raspberry Pi running the
CuttleOS services and NATS Core:

```text
                         Operator
                            │
                     HTTP / WebSocket
                            │
                            ▼
                       ┌─────────┐
                       │ Cockpit │
                       └────┬────┘
                            │
                       NATS Core
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
          ┌────────┐   ┌──────────┐   Other services
          │ Control│   │Datalogger│
          └───┬────┘   └──────────┘
              │
              ▼
        Physical hardware
```

Cockpit, Control, and Datalogger are separate services. Failure of Cockpit,
media, authentication, visualisation, or the Datalogger must not directly stop
or destabilise the safety-critical control path.

The browser never connects directly to NATS or physical hardware.

## 4. Application messaging

NATS Core is the selected application middleware. JetStream is explicitly out
of scope for the current architecture.

Application-level subject names, payload schemas, units, ranges, timestamps,
and failure semantics are defined by CuttleOS and must be consumed consistently
by Control, Cockpit, Datalogger, and SquidLink.

The NATS contract is an application boundary, not a simulation-specific API.
SquidLink's bridge adapts the application contract to ROS 2 topics without
creating a second authoritative contract.

## 5. Robot profiles

Robot-specific behaviour is declared through validated robot profiles rather
than duplicated application implementations.

Profiles define capabilities and configuration such as:

- robot identity and namespace;
- telemetry and command mappings;
- gamepad configuration;
- camera and media capabilities;
- enabled features;
- hardware and deployment parameters where applicable.

The authoritative profile requirements and schema are maintained in
`docs/robot-profile-requirements.md` and the profile files under
`configs/profiles/`.

## 6. Command and control path

The operator expresses logical intent through Cockpit. Control receives logical
commands through NATS, validates them, applies robot-profile configuration,
performs actuator mixing and control-law processing, enforces limits and
timeouts, and communicates with physical hardware.

```text
Browser
  │
  ▼
Cockpit
  │
  │ logical command / NATS
  ▼
Control
  │
  ├── validation
  ├── safety limits
  ├── timeout / neutral behaviour
  ├── mixing / control law
  └── hardware drivers
       │
       ▼
    Hardware
```

Safety-critical behaviour belongs in Control or the appropriate hardware layer,
not in the browser.

## 7. Telemetry and data path

Hardware and Control publish telemetry through NATS. Cockpit consumes the
required telemetry for operator presentation, while Datalogger observes and
records agreed subjects without intercepting, modifying, delaying, or becoming
a dependency for control messages.

SquidLink may generate simulated telemetry through the same application
interfaces used by a real robot.

## 8. Media architecture

Media is a common CuttleOS capability. The detailed architecture is maintained
in [`docs/media-architecture.md`](media-architecture.md).

The media architecture separates acquisition, distribution, recording,
presentation, and authoritative data. Recording is independent of whether an
operator is currently viewing a live stream.

Where stereo cameras are used, synchronised left/right imagery is retained as
the authoritative recording rather than making a presentation format such as
anaglyph the master. Live video should be on demand, and video traffic must not
starve control or telemetry.

Video, audio, telemetry, and command/control records use a common time reference
where practical so that recorded media can be correlated with robot behaviour.

## 9. Simulation and HiL/SiL boundary

SquidLink exercises CuttleOS through the same application-facing interfaces as
the real robot.

```text
CuttleOS application contract
          │
        NATS
          │
          ▼
   SquidLink bridge
          │
       ROS 2
          │
       Gazebo
          │
 simulated sensors / actuators
```

The bridge owns transport and message translation. It must not duplicate or
replace CuttleOS Control's production safety policy.

SiL validates software integration against simulation. HiL additionally
introduces real hardware into the simulation/test loop. Neither constitutes
physical production validation unless the relevant hardware test evidence exists.

## 10. Hardware/software boundary

CuttleOS defines the software-facing application contracts required to operate
and observe the robot. NautiPi defines the physical implementation of those
contracts.

Hardware-specific transport details may be required by Control, but they must
not leak into Cockpit's operator-facing command model.

Where a hardware node has its own embedded protocol, that protocol belongs to
the hardware/control boundary and is documented with the relevant hardware and
Control implementation.

## 11. Time and provenance

Recorded data should retain enough provenance to reconstruct the conditions
under which it was produced. Where applicable this includes:

- robot identity and profile;
- CuttleOS revision;
- configuration revision or hash;
- hardware revision;
- camera and stereo-calibration identifiers;
- recording start time and timebase;
- source identifiers;
- relevant telemetry and command-record identifiers.

Raw video and raw NATS telemetry/control logs are authoritative masters. Derived
visualisations, telemetry overlays, exports, and reports are secondary products.

## 12. Configuration and deployment

Production deployment is centred on the Raspberry Pi inside the robot. The
active robot profile and protected runtime configuration are provisioned onto
the robot, while the source-of-truth configuration remains version controlled
in CuttleOS.

Simulation configuration and scenarios remain in SquidLink. Hardware design
files remain in NautiPi.

## 13. Validation and evidence

Each repository must distinguish clearly between:

- designed;
- simulated;
- software-tested;
- bench-tested;
- commissioned;
- production-validated.

A successful SquidLink simulation does not prove physical behaviour. A hardware
CAD design does not prove assembly or commissioning. A CuttleOS software test
does not prove hardware performance.

Evidence belongs with the activity that generated it, while cross-repository
claims should reference the relevant evidence explicitly.

## 14. Source-of-truth matrix

| Subject | Authoritative repository |
|---|---|
| Overall robot system architecture | robot-CuttleOS |
| CuttleOS runtime behaviour | robot-CuttleOS |
| Application/NATS contracts | robot-CuttleOS |
| Robot profiles | robot-CuttleOS |
| Media architecture | robot-CuttleOS |
| Production deployment | robot-CuttleOS |
| ROS 2 architecture | robot-SquidLink |
| Gazebo models and simulation | robot-SquidLink |
| SiL/HiL scenarios | robot-SquidLink |
| NATS/ROS 2 bridge implementation | robot-SquidLink |
| PCB/schematic/CAD design | robot-NautiPi |
| Embedded hardware design | robot-NautiPi |
| Physical hardware evidence | robot-NautiPi or the dedicated test record |

When a repository needs information owned by another repository, it should link
to that repository's authoritative document rather than copying the definition.

## 15. Architectural change control

A change that crosses repository boundaries must update the CuttleOS system
architecture and the affected repository-specific documentation and tests.

In particular, changes to application interfaces, NATS subjects or schemas,
robot-profile capabilities, media contracts, or safety boundaries must be
reviewed as system changes rather than isolated implementation changes.

Repository-specific implementation changes that do not alter the shared
contract should remain within that repository.

## 16. Related documentation

- [`MASTER_CONTEXT.md`](../MASTER_CONTEXT.md) — CuttleOS architectural and engineering context
- [`docs/robot-profile-requirements.md`](robot-profile-requirements.md) — profile requirements
- [`docs/media-architecture.md`](media-architecture.md) — media architecture
- [`ROADMAP.md`](../ROADMAP.md) — planned work
- **robot-SquidLink** — simulation and SiL/HiL implementation
- **robot-NautiPi** — physical hardware designs and evidence
