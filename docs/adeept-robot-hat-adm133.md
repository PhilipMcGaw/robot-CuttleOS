# Adeept Robot HAT ADM133 topic map

## Status and scope

The Adeept Robot HAT ADM133 is planned as a shared Control hardware adapter
for K9 and PiWars. The board inventory and annotated photographs are cross-checked against [Philip McGaw's ADM133 V3.1 reference](https://philipmcgaw.com/adeept-robot-hat-for-raspberry-pi/). That reference records the fitted board as providing 2S1P 18650 battery support, four DC motor ports, 16 PCA9685 servo channels, six ADC inputs, two onboard WS2812 LEDs, and the expansion interfaces listed below. This document defines the logical NATS contract before the
driver is implemented. It is not evidence of a working board, wiring map, or
safe motor operation.

The manufacturer's current Robot HAT V3.3 material lists four DC-motor
drivers, 16 PCA9685 servo outputs, six analogue-to-digital converter (ADC)
inputs, a three-channel line sensor port, ultrasonic and MPU6050 ports, light
tracking, infrared receiver, RGB/WS2812 lighting, a buzzer, UART, and I2C.
See the [official product specification](https://www.adeept.com/adeept-robot-hat-v30-for-raspberry-pi_p0429.html)
and [official tutorial and code archive](https://www.adeept.com/learn/detail-84.html).
The exact revision fitted to a robot must be confirmed before deployment.
The companion [port-interface guide](adeept-robot-hat-adm133-interfaces.md)
explains the board connectors, Linux buses, vendor-sample pin map, and safe
commissioning procedure. It is cross-referenced with
[Philip's ADM133 board notes](https://philipmcgaw.com/adeept-robot-hat-for-raspberry-pi/)
and the supplied manufacturer V3 examples; source-code mappings remain
unbench-tested until the fitted board is commissioned.

## Boundary

Cockpit publishes and presents only logical profile topics. Control validates
them, applies its safe state, limits, calibration, mixing, and channel mapping,
then drives the ADM133. No client may publish any of the following:

- raw GPIO writes;
- raw I2C or UART transfers;
- PCA9685 channel numbers or pulse widths;
- DC motor-channel demands;
- direct battery-charger or power-control demands.

The active profile binds a board function to named entries in its `commands`
and `telemetry` objects. The subject itself appears only in that canonical
entry, preventing a second, conflicting topic definition.

```json
{
  "hardware": {
    "adapters": [{
      "id": "main-hat",
      "driver": "adeept-robot-hat-adm133",
      "model": "ADM133",
      "validation_status": "planned-unverified",
      "bindings": {
        "dc-motor-drive": { "commands": ["drive.throttle", "drive.steering"] },
        "adc-battery": { "telemetry": ["battery_percentage", "battery_voltage"] }
      },
      "actuators": {
        "head-pan": {
          "port_alias": "servo-00",
          "pca9685_channel": 0,
          "command": "head.pan"
        }
      }
    }]
  }
}
```

Control must reject an incomplete, unknown, stale, or unsafe command. The
adapter must leave motor outputs neutral until Control has completed profile
validation and entered an explicitly safe enabled state.

## Logical topic map

`<namespace>` is the active profile namespace, for example `k9`, `piwars`, or `testbot`.
The exact logical keys that are enabled for a robot are profile configuration;
unneeded capabilities are not exposed merely because the HAT has a connector.

| ADM133 function | Profile binding and resolved topic | Value contract and Control responsibility |
| --- | --- | --- |
| Up to four DC-motor drivers | `drive.throttle`, `drive.steering` → `<namespace>.command.drive.throttle`, `<namespace>.command.drive.steering` | `-100–100 %` logical demands. Control performs drive mixing, direction, ramping, channel assignment, neutral, timeout, and emergency-stop behaviour. |
| PCA9685 channel allocation | The ADM133 V3.1 motor example reserves channels 15/14 for M1, 12/13 for M2, 11/10 for M3, and 8/9 for M4. These channels must not also be assigned to independent servos. When all four motor ports are used, channels 0-7 remain for other PCA9685 outputs, subject to board-level confirmation. | The channel map is taken from Adeept's V3 example code and must be treated as a profile resource reservation. |
| PCA9685 servo outputs | Robot-specific actuator commands, such as K9 `head.pan`, `head.tilt` → `<namespace>.command.animatronics.head.pan`, `<namespace>.command.animatronics.head.tilt` | Degrees relative to the configured logical home. Each selected channel uses a stable physical alias, `servo-00` through `servo-15`, plus a robot-purpose alias such as `head-pan`. Control applies servo calibration and physical limits, and may publish an explicitly documented commanded-position telemetry value. |
| ADC battery measurement | `battery_voltage`, `battery_percentage` → `<namespace>.telemetry.power.battery.voltage`, `<namespace>.telemetry.power.battery.percentage` | Voltage is `V`; state of charge is bounded `0–100 %`. The current V3 sample uses ADS7830 channel 0; Control owns ADC scaling, calibration, filtering, clamping, and battery safety thresholds. |
| Other ADC inputs | A configured logical sensor, for example `analogue.<id>.voltage` → `<namespace>.telemetry.sensors.analogue.<id>.voltage` | `V` after Control calibration. Raw ADC counts are diagnostic-only and, if published, use `count` with a documented ADC resolution. |
| Three-channel line sensor | PiWars `line_left`, `line_centre`, `line_right` → `<namespace>.telemetry.sensors.line.left`, `.centre`, `.right` | Boolean or `0`/`1` detection values. The current V3 sample assigns left / centre / right to GPIO `22` / `27` / `17`; the profile must document active polarity before enabling autonomous behaviour. |
| Ultrasonic range sensor | `distance_front` → `<namespace>.telemetry.sensors.distance.front` | Metres. Control validates timeout and out-of-range readings; it must not report an invalid reading as a valid obstacle distance. |
| MPU6050 accelerometer/gyroscope port | Optional `attitude.roll`, `attitude.pitch` → `<namespace>.telemetry.navigation.attitude.roll`, `.pitch` | Degrees after sensor fusion and installation calibration. The MPU6050 has no magnetometer, so this board function alone must not publish a heading. |
| Light-tracking sensor | Optional `light_tracking_level` → `<namespace>.telemetry.sensors.light-tracking.level` | The current V3 sample reads ADS7830 channel 1. Publish a calibrated level or `count` diagnostic with its unit/resolution; derive a boolean detection value only from a profile-defined, documented threshold. |
| Infrared receiver | Optional `ir_code` → `<namespace>.telemetry.inputs.ir.code` | A profile-approved, explicitly documented code encoding. No receiver code is defined until the receiver and library are selected. |
| RGB LED ports and WS2812 outputs | Optional `indicator.<id>.set` → `<namespace>.command.indicator.<id>.set` | A JSON colour/effect request defined by the profile. Control limits brightness, pattern rate, and output count; it does not accept a raw GPIO/PWM demand. |
| Buzzer | Optional `buzzer.pattern` → `<namespace>.command.notification.buzzer.pattern` | A profile-approved named pattern. It is a short notification device, not K9's sound-file speaker; `sound.play` remains a separate audio contract. |
| UART and I2C expansion ports | No raw bus topic | A dedicated Control driver for each attached device defines its own semantic command and telemetry topics. |
| Battery charger and power input | No control topic | They are electrical safety functions, not remotely commandable interfaces. Power-state monitoring may be exposed only through validated telemetry. |

Control may publish the adapter's health on
`<namespace>.control.status.hardware.adeept-robot-hat`. The status object must
identify the active profile and report safe initialisation, missing hardware,
and communication/configuration faults without exposing a direct actuation
path.

## Related comparison reference

Philip McGaw’s [Adeept versus Navigation Raspberry Pi HAT comparison](https://philipmcgaw.com/adeept-vs-navigation-raspberry-pi-hats/) is a useful secondary reference when considering Blue Robotics Navigation Hat or BlueOS compatibility. It compares the two boards across UART, I²C, NeoPixel and status LED outputs, RGB and line-tracking interfaces, leak and ultrasonic inputs, ADC devices, IMU and magnetometer options, and PWM/PCA9685 resources.

The comparison is an integration-planning note, not a replacement for the ADM133 V3.1 schematic or a bench measurement. Its pin and device mappings must be checked against the fitted board revision before they are copied into a CuttleOS profile or a BlueOS configuration. In particular, shared GPIO, I²C, PWM, motor-driver, and status-indicator resources must be represented as explicit reservations so that two functions cannot be enabled accidentally at the same time.
## Initial profile bindings

The current shared profiles validate only the functions selected for their
robots:

- K9: DC drive, head pan/tilt servos, and battery measurement.
- PiWars: DC drive, battery measurement, all three line-sensor channels, and
  front ultrasonic range.
- Testbot: DC drive, battery measurement, a camera-tilt servo, onboard WS2812
  status indication, and a buzzer horn. These bindings remain planned and
  unbench-tested; the servo channel and board-level LED details still require
  confirmation.

These bindings are configuration contracts, not an ADM133 driver
implementation. Testbot's camera servo has been operated on PCA9685 channel 0, as recorded in the linked reference. Adeept's motor example reserves PCA9685 channels 15/14 for M1, 12/13 for M2, 11/10 for M3, and 8/9 for M4; Testbot therefore reserves channels 12-15 for its fitted M1/M2 H-bridges and keeps channel 0 for the camera servo. The remaining Testbot functions are not yet bench-tested. No other channel allocations have been recorded and no electrical,
motor, servo, sensor, or power behaviour is bench-tested.

## Required bring-up evidence

Before changing the status, record the board revision, Raspberry Pi model and
operating system, wiring/channel map, power source and fusing, calibration,
input polarity, software revision, and test results. Begin with motors
disconnected or mechanically made safe. Test one output and one sensor class at
a time, verify neutral and timeout behaviour, then test the physical emergency
stop before a robot is operated.
