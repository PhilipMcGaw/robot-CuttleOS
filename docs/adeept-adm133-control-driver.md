# Adeept ADM133 Control driver

## Purpose

The Adeept Robot HAT V3.1 is a commercially available hardware adapter that can provide a common starting point for Testbot and K9, and potentially selected ROV configurations. CuttleOS Control should own the ADM133 driver and expose its functions through the existing profile-defined logical interface.

The ADM133 is not a reason to copy robot-specific hardware code into Cockpit. Cockpit publishes authenticated logical commands; Control validates safety, applies the active profile, drives the adapter, and publishes validated telemetry.

## Repository boundaries

- robot-CuttleOS owns the Control-driver contract, profile bindings, safety behaviour, and software validation.
- robot-NautiPi owns the physical board, wiring, connector, CAD, and bench evidence.
- robot-SquidLink may model the resulting logical robot behaviour, but does not define the physical ADM133 wiring.

The [ADM133 interface reference](adeept-robot-hat-adm133.md) records the board capability inventory and source references. The [Testbot profile](../configs/profiles/testbot.json) records the current selected functions and resource reservations.

## Board functions to support

| Function | Logical profile mapping | Initial use | Status |
|---|---|---|---|
| DC motor H-bridges | `drive.throttle`, `drive.steering` | Testbot M1/M2; K9 as required | Planned, unverified |
| PCA9685 servo outputs | Robot-specific commands such as `camera.pitch` | Testbot camera tilt; K9 head/actuators | Channel 0 camera servo bench-tested; driver unimplemented |
| Battery ADC | `battery_voltage`, `battery_percentage` | Testbot and K9 | Planned, unverified |
| WS2812 LEDs | `indicator.status.set` | Testbot and K9 status indication | Planned, unverified |
| Passive buzzer | `notification.buzzer.pattern` | Testbot horn and K9 notifications | Planned, unverified |
| UART | Dedicated Control device interface | Only when a profile requires it | Planned |
| I²C expansion | Dedicated Control sensor driver | MPU6050 and other modules | Planned |
| Ultrasonic input | `distance_front` | Optional Testbot module | Planned, unverified |
| Line-tracking input | `line_left`, `line_centre`, `line_right` | Optional Testbot module | Planned, unverified |
| Light-tracing input | `light_tracking_level` | Optional Testbot module | Planned, unverified |
| IR receiver | `ir_code` | Optional future use | Planned, unverified |
| RGB LED ports | Profile-defined indicator function | Optional future use | Planned, unverified |

A board capability is not automatically an enabled robot capability. A profile must select the function, define its logical mapping, and reserve any shared physical resources.

## PCA9685 resource reservations

The ADM133 V3.1 motor example uses the PCA9685 for H-bridge control as well as servo outputs:

| Motor port | Reserved PCA9685 channels |
|---|---:|
| M1 | 15, 14 |
| M2 | 12, 13 |
| M3 | 11, 10 |
| M4 | 8, 9 |

Testbot uses M1 and M2, so channels 12–15 are reserved. Its camera servo uses channel 0. Channels 1–7 are candidate servo channels, subject to physical board, power, and wiring confirmation. The Control driver must reject conflicting profile allocations before enabling outputs.

## Logical command and telemetry contracts

The driver must preserve the active profile’s namespace. For Testbot, the initial subjects are:

```text
testbot.command.drive.throttle
testbot.command.drive.steering
testbot.command.camera.main.pitch
testbot.command.notification.buzzer.pattern
testbot.command.indicator.status.set
testbot.telemetry.power.battery.voltage
testbot.telemetry.power.battery.percentage
testbot.telemetry.system.network.status
```

Commands must be validated for profile identity, range, freshness, authentication, and safety state. The driver must not expose raw GPIO, PCA9685 channel, or motor-driver commands at the application boundary.

### Buzzer

The buzzer accepts named, duration-limited patterns. The initial Testbot horn contract is:

```json
{
  "profile": "testbot",
  "pattern": "horn",
  "duration_ms": 250
}
```

The driver must reject arbitrary tones, excessive durations, and unknown patterns. A buzzer fault must not prevent motor safety handling.

### Status LEDs

The two onboard WS2812 LEDs should use semantic states shared by the robot and Cockpit:

| Colour | Meaning |
|---|---|
| Red | Alarm or unsafe state |
| Amber | Attention or degraded state |
| Green | Ready and healthy |
| Blue | Connected or active information state |

The driver owns LED output. Cockpit should display the same semantic state from the profile and status telemetry; it should not send raw LED colour values merely to mirror its own UI.

## Control-driver responsibilities

The ADM133 adapter implementation should:

- initialise the board into a safe, non-driving state;
- verify the expected I²C devices and configured board resources;
- apply motor direction, inversion, ramping, neutral, timeout, and emergency-stop behaviour;
- prevent PCA9685 channel conflicts;
- apply servo limits and safe startup positions;
- scale, filter, clamp, and label battery ADC readings;
- emit named buzzer patterns with duration limits;
- drive profile-defined status effects with brightness and rate limits;
- publish adapter health and fault details on the profile-defined status subject;
- stop outputs safely on shutdown, communication loss, or configuration error; and
- keep physical device selection and recovery out of Cockpit.

## Implementation stages

1. Create a hardware-independent adapter interface and mock implementation.
2. Add ADM133 discovery and I²C health checks.
3. Implement buzzer and WS2812 outputs.
4. Implement battery ADC telemetry.
5. Implement PCA9685 servo output, starting with Testbot channel 0.
6. Implement one motor channel with the wheels raised or disconnected.
7. Implement M1/M2 differential drive and command timeout.
8. Add optional sensor drivers one at a time.
9. Reuse the adapter with K9 after Testbot evidence is complete.
10. Assess ROV suitability separately, including power, isolation, environmental protection, and failure modes.

## Evidence requirements

Each function must have its own record:

| Evidence level | Meaning |
|---|---|
| Planned | Intended, but not implemented or tested |
| Automated-test verified | Software contract or mock behaviour passes repeatable tests |
| Bench-tested | Physical function works under controlled conditions |
| Production-validated | Function works in its intended robot installation with recorded evidence |

A successful software test does not establish that the board, wiring, motor, servo, sensor, or power system is physically safe. A successful Testbot test does not automatically validate K9 or ROV installation.

## Current status

The profile contract and channel reservations are documented. The camera servo has been operated on PCA9685 channel 0. The shared Control-side ADM133 driver, physical motor control, battery calibration, WS2812 output, buzzer output, and optional sensor drivers remain planned or unverified.