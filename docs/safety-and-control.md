# Safety and control behaviour

> **Status:** Architectural guidance for CuttleOS Control and robot-specific
> safety implementations.
>
> This document records principles informed by ArduSub. It does not require
> MAVLink, Pixhawk, ArduPilot, or BlueOS. Physical implementation remains
> authoritative in robot-NautiPi, and simulation remains authoritative in
> robot-SquidLink for simulated behaviour.

## 1. Safety objective

Control must place the robot in a known, bounded state when the operator,
network, software, sensor, power, or hardware path becomes unavailable or
invalid. Safety must not depend solely on the browser, Cockpit, NATS, or
Datalogger remaining functional.

A safety response must identify which outputs are affected, how quickly the
response occurs, whether the response is local or system-wide, and what action
is required before operation can resume.

## 2. Vehicle states

The common state model is:

```text
Initialising
    ↓ checks and hardware discovery
Not ready
    └── a required check fails
Ready but disarmed
    └── outputs inhibited, configuration limited
Armed
    └── commands accepted within limits and freshness window
Emergency stop
    └── propulsion stopped immediately
Failsafe
    └── configured response to a detected fault
Maintenance mode
    └── configuration and updates allowed only when disarmed
```

The exact states and names may vary by robot profile, but transitions must be
explicit, observable, logged, and tested. A robot must not become armed merely
because a service restarted or a network connection returned.

## 3. Pre-operation checks

Control should complete the relevant checks before allowing propulsion to arm.
The profile should identify which checks are required, optional, or unavailable
for the vehicle.

Checks may include:

- active profile identity and configuration validation;
- actuator mapping and resource-conflict validation;
- hardware-node discovery, identity, revision, and heartbeat;
- sensor presence, calibration state, range, and data freshness;
- battery voltage, current, capacity estimate, and low-battery thresholds;
- leak, pressure, and temperature status;
- communications path and command-source authentication;
- emergency-stop state and physical power-cutoff availability;
- safe neutral output and actuator direction verification;
- camera, media, storage, and clock status where required by the mission.

A failed check should provide a clear reason and a recovery action. Checks may
be bypassed for controlled bench testing only when the bypass is explicit,
logged, time-limited, and physically safe. Production operation must not depend
on skipped checks.

## 4. Arming, disarming, and emergency stop

Arming enables propulsion. It should require an explicit authenticated action,
valid pre-operation checks, neutral input, and a clear physical operating area.

Disarming prevents propulsion from operating and returns outputs to the defined
safe state. An emergency stop is a separate, faster action that inhibits
propulsion immediately. It should remain effective if Cockpit or normal command
processing is unavailable, where the hardware permits.

The emergency-stop path should define:

- which outputs are stopped;
- whether servos, lights, pumps, or payloads remain available;
- whether the action is latched;
- how it is reset;
- whether re-arming requires the full pre-operation checks again.

A convenient UI control must not be the only emergency-stop mechanism. ROV
hardware should retain an independent physical power cutoff where practical.

## 5. Command freshness and deadman behaviour

Every motion command must have a freshness rule. Control should apply neutral
outputs when commands are stale, malformed, unauthorised, or absent for longer
than the configured timeout.

The implementation should consider a deadman or hold-to-run action for manual
propulsion. A released control, lost browser, lost NATS connection, or stale
heartbeat must not leave the last motor demand active.

After a communication failsafe, the robot should remain in the failsafe state
until an explicit recovery action has occurred. Reconnection alone must not
silently re-enable propulsion.

## 6. Layered failure responses

Failures should be handled independently where their risks differ. The profile
or safety policy should define warning, degraded operation, controlled response,
and propulsion-stop actions for each class.

| Failure | Possible response |
| --- | --- |
| Operator input lost | warn, neutralise propulsion, enter failsafe |
| NATS or network command path lost | neutralise propulsion and record loss |
| Hardware node lost | stop affected outputs and apply vehicle response |
| Battery low | warn, limit demand, or begin configured recovery |
| Battery critical | stop propulsion or use a verified recovery action |
| Leak detected | warn, stop affected equipment, and use a verified recovery action |
| Pressure or temperature out of range | warn, limit operation, or stop propulsion |
| Invalid or stale sensor data | reject dependent control mode and fall back safely |
| Control service restart | initialise outputs safe and require explicit re-arm |
| Watchdog or processor fault | use the lowest-level available safe state |

For an ROV, “surface” or “return” must be treated as a conditional, verified
vehicle response. It may be unsafe or impossible with a snagged tether, an
obstruction, a manipulator payload, or insufficient buoyancy. No automatic
recovery action should be enabled until its physical behaviour has been tested.

## 7. Control modes and capabilities

Operating modes should be profile capabilities rather than a fixed list shown to
every robot. Examples include manual drive, stabilised drive, depth hold,
heading hold, position hold, surface recovery, and maintenance.

A mode must declare its required sensors and fail safely when those sensors are
missing, stale, uncalibrated, or outside their valid range. Testbot may begin
with manual differential drive. The ROV may later add stabilisation or depth
control when the relevant sensors and control laws are commissioned.

Mode changes should be authenticated where appropriate, visible to the
operator, recorded in the event log, and rejected while emergency stop or an
incompatible maintenance state is active.

## 8. Limits, calibration, and tuning

Control should enforce configured limits independently of Cockpit. These may
include maximum demand, acceleration or ramp rate, actuator range, attitude,
depth, speed, battery current, and payload-specific limits.

Calibration and tuning data must be versioned and associated with the hardware,
profile, and software revision that used them. Changes should be made while
disarmed where practical, with the previous known-good configuration retained
until the new values pass testing.

## 9. Hardware and local safety

A hardware node should establish safe outputs during power-up, reset, lost
communications, and watchdog expiry. Local protection complements, but does not
replace, Control's system-level policy.

The physical design should consider:

- motor or thruster guards and safe handling during bench work;
- current limiting, fusing, polarity, and brown-out behaviour;
- actuator back-drive and unexpected restart;
- independent power isolation;
- leak and pressure protection;
- connector retention, strain relief, and ingress protection;
- payload effects on buoyancy, trim, clearance, and entanglement risk.

## 10. Observability and records

Control should publish current safety state, readiness, active failsafe, reason,
command-source health, node health, and sensor validity through the documented
status subjects. It should log arm, disarm, emergency stop, failsafe, mode
change, configuration change, and recovery events with timestamps and relevant
identities.

A warning is not evidence that a physical response occurred. Records should
distinguish designed, simulated, software-tested, bench-tested, commissioned,
and production-validated behaviour.

## 11. Safety test matrix

Safety testing should progress from no hardware to controlled physical tests:

1. validate state transitions and pre-operation check failures in unit tests;
2. test malformed, unauthorised, stale, and conflicting commands;
3. test command, NATS, network, node-heartbeat, and watchdog loss;
4. test limits, ramps, neutral output, restart, disarm, and emergency stop with
   propulsion disconnected or mechanically restrained;
5. test sensor-invalid and calibration-invalid mode rejection;
6. test battery, leak, pressure, and temperature thresholds with safe test
   signals;
7. test dry integrated behaviour with physical power isolation available;
8. perform shallow-water ROV tests only after seals, penetrators, leak
   detection, tether, and recovery procedures pass;
9. record the hardware, firmware, profile, software revision, operator,
   conditions, expected response, observed response, and result.

Simulation and software tests can establish logical behaviour. They cannot by
themselves establish that a physical motor stopped, a leak was detected, or an
ROV reached the surface.