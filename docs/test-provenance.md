# CuttleOS Test Provenance and Execution Evidence

> **Status:** Architectural guidance for test, validation, SiL, HiL, and commissioning evidence.
>
> This document records patterns identified during review of Test in a Box (TiaB). It does not make CuttleOS dependent on TiaB.

## 1. Purpose

CuttleOS test evidence shall make it possible to determine what was tested,
with which software and configuration, against which robot or simulated system,
and what happened during the run.

The goal is reproducibility and traceability rather than the creation of a
laboratory test-management system inside CuttleOS.

## 2. Test-run identity

A test run should have a unique run identifier and retain, where applicable:

- run start and finish timestamps;
- run status;
- test or scenario identifier;
- robot identity;
- active robot profile;
- CuttleOS software revision;
- relevant configuration revision or hash;
- hardware identity and revision;
- SiL, HiL, bench, commissioning, or production context;
- operator or initiating system identity where appropriate.

The run identifier should be propagated through test-related events so that
telemetry, control records, faults, media, and derived reports can be correlated
without relying solely on wall-clock time.

## 3. Provenance

TiaB demonstrates the value of recording both human-readable summaries and a
machine-readable manifest. Its implementation hashes canonicalised JSON for
configuration and mapping, hashes the generated procedure, records software
identity, and captures instrument identity where available. CuttleOS should use
the same principle while adapting it to the robot's distributed architecture.

For a CuttleOS test run, provenance should identify, where applicable:

- CuttleOS revision;
- SquidLink revision and scenario revision;
- robot profile revision;
- relevant configuration snapshots and hashes;
- hardware node manufacturer UID, hardware revision, and firmware version;
- test procedure or scenario revision;
- calibration identifiers where relevant;
- media configuration and camera/calibration identifiers;
- timebase and synchronisation information.

A hash identifies the exact content used for a run. A version number alone is
not sufficient when mutable configuration can exist outside the versioned
source tree.

## 4. Test and cycle markers

Tests should emit explicit lifecycle events rather than requiring later
inference from telemetry timestamps.

The preferred conceptual lifecycle is:

```text
run.start
  test.start
    step.start
      cycle.start
      cycle.end
    step.end
  test.end
run.end
```

Only the levels required by a particular test need to be emitted.

A marker should carry enough context to identify the run and its position in the
procedure. Repeated cycles should include a cycle number. Recovery attempts
should be distinguishable from normal execution.

These events are temporal anchors for:

- telemetry;
- command/control records;
- faults and diagnostics;
- video and audio;
- simulated state;
- operator actions;
- derived reports.

This is preferable to trying to reconstruct test boundaries retrospectively
from unrelated measurements.

## 5. Application event contract

Test lifecycle events are application semantics and therefore belong at the
CuttleOS NATS boundary. They must not depend on ROS 2 terminology or a
simulation-specific protocol.

The event payload should contain, as applicable:

```text
schema_version
run_id
test_id
step_id
cycle_number
recovery_attempt
timestamp
timebase
source
status
```

Fields shall only be included where their meaning is defined. Exact subject
names and payload schemas remain part of the CuttleOS application contract and
must be added to the authoritative NATS schema when implementation begins.

## 6. Hardware capability and identity

TiaB's `CapabilityDescriptor` and `DiscoveredInstrument` abstractions provide a
useful pattern for CuttleOS hardware discovery.

CuttleOS should distinguish between:

1. **Identity** — which physical node is this?
2. **Address** — how is it reached on the current bus configuration?
3. **Capability** — what can it do?
4. **State** — what is it currently reporting?

The manufacturer's immutable UID identifies the physical hardware. The
configured operational address is not the identity and may change.

A hardware capability description should expose engineering functions rather
than transport details, for example:

```text
thruster_output
battery_voltage
battery_current
temperature
imu
leak_detection
```

It should also define the relevant quantity, unit, valid range, and failure
semantics where applicable.

## 7. Safe-state evidence

TiaB's driver-level `safe_state()` pattern is useful, but CuttleOS requires a
stronger safety boundary.

Control remains responsible for robot-level safety. A hardware node may provide
its own local safe-state or watchdog mechanism, but a test tool, Datalogger,
Cockpit, or NATS transport must not become the sole safety mechanism.

Where a test can command an actuator, evidence should distinguish:

- safe state requested;
- safe state acknowledged or verified;
- safe state failed or could not be confirmed.

A software request to enter a safe state must not be treated as physical proof
that the hardware is safe.

## 8. Authoritative data and derived reports

Raw telemetry, control records, and source media remain authoritative. Test
summaries, CSV exports, plots, WebVTT overlays, and other reports are derived
products.

A derived report should retain enough provenance to identify the source run and
source records from which it was generated.

This prevents a polished report from becoming the only surviving evidence when
the underlying event or telemetry record contains information that the report
does not show.

## 9. Multi-DUT and multi-node correlation

TiaB's DUT-to-position mapping is useful as a general traceability pattern, even
though CuttleOS is not a laboratory instrument framework.

Where a test involves multiple physical items, the evidence model should retain
the relationship between:

- run;
- robot or hardware assembly;
- physical node UID;
- logical role;
- physical position where relevant;
- measurement or event.

Do not collapse these relationships into display labels that cannot be traced
back to physical hardware.

## 10. Validation state

Test evidence shall retain the distinction between:

- designed;
- simulated;
- software-tested;
- bench-tested;
- commissioned;
- production-validated.

A test-run manifest should record the applicable test context so that evidence
cannot later be mistaken for a stronger validation level.

## 11. Relationship to existing CuttleOS architecture

This document extends, rather than replaces:

- `system-architecture.md` for cross-repository architecture;
- `control-architecture.md` for safety and control ownership;
- `hardware-interface.md` for hardware identity and addressing;
- `nats-contract.md` for application messaging;
- `robot-profile-requirements.md` for profile structure;
- `sil-hil.md` for SiL and HiL definitions.

TiaB remains an independent project. The patterns recorded here are architectural
inspirations derived from its implementation and engineering workflow, not
shared runtime dependencies.
