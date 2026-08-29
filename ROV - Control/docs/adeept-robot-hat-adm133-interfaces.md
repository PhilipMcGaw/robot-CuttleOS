# Adeept Robot HAT ADM133 port interfaces

## Status and purpose

This guide explains how Control can interface with the connectors and integrated
devices on an Adeept Robot HAT ADM133 (V3.3 family). It is a design and
bring-up reference, not hardware-validation evidence. The fitted board's
silkscreen, revision marking, and vendor resource archive remain authoritative
when they disagree with this document.

The board has the Raspberry Pi's I2C, UART, SPI, and GPIO facilities, a PCA9685
PWM controller for servos and motors, an ADS7830 analogue-to-digital converter
(ADC), and dedicated sensor/lighting connectors. This guide takes its port map
from the current [manufacturer V3 example repository](https://github.com/adeept/Adeept_Robot_HAT-V3), including the supplied archive, and uses
[Philip's ADM133 board notes and annotated photographs](https://philipmcgaw.com/adeept-robot-hat-for-raspberry-pi/)
for the board-level connector inventory and power observations. The
manufacturer also publishes a [V3 resource archive](https://www.adeept.com/learn/detail-84.html).

All physical access is a Control responsibility. Cockpit publishes only the
logical NATS topics defined in [the ADM133 topic map](adeept-robot-hat-adm133.md).

## Interface-selection rule

Use the dedicated HAT connector and a Control driver when the board provides
one. The 40-pin header is a Raspberry Pi pass-through, not a replacement for a
dedicated connector and not a source of arbitrary remote GPIO commands.

| Requirement | Correct Control interface | Do not do this |
| --- | --- | --- |
| Position servo or continuous-rotation servo | PCA9685 through the `servo` adapter | Generate software PWM from a random Pi GPIO. |
| DC drive motor | HAT motor adapter using its PCA9685 channel pair | Publish a physical H-bridge/PWM channel through NATS. |
| I2C sensor, OLED, or MPU6050 | I2C bus 1 through a device-specific driver | Use a raw I2C NATS command. |
| Ultrasonic range | Dedicated ultrasonic connector and range driver | Connect it to the I2C connector or assume an arbitrary GPIO layout. |
| Line or light tracking | Dedicated sensor connector and digital-input/ADC driver | Treat an active-low signal as active-high without a recorded polarity check. |
| RGB/WS2812 indication | Dedicated LED driver with a profile-defined effect | Permit a Cockpit client to toggle GPIO pins directly. |
| Extra serial device | UART driver using `/dev/serial0` after deployment verification | Hard-code a Raspberry Pi UART device name or expose raw UART transfers. |

## Integrated I2C devices

The PCA9685 and ADS7830 are devices on Raspberry Pi I2C bus 1. Use the Linux
I2C device interface through a Control driver. The I2C connector and MPU6050
connector are also bus-1 connections, so every attached device must have a
unique I2C address.

| Device | Interface | Reference address | Control use | Verification required |
| --- | --- | --- | --- | --- |
| PCA9685 | I2C bus 1 | `0x5f` in Adeept's current V3 examples | Servo and DC-motor PWM | Scan bus 1 and verify the response before enabling any output. The PCA9685 default is often `0x40`; do not substitute it for the fitted board's measured address. |
| ADS7830 | I2C bus 1 | `0x48` in the current V3 examples | Six ADC channels, including battery and light-tracking inputs | Identify every connected input, measure the divider/calibration, and verify that each result is within the ADC's safe input range. |
| MPU6050 module | I2C bus 1, dedicated connector | `0x68` in the current V3 example | Accelerometer and gyroscope | Scan, read the chip identity, confirm mounting axes, then perform bias and orientation calibration. |
| Additional I2C module | I2C bus 1, I2C connector | Device-specific | Dedicated sensor/display driver | Confirm its voltage, address, bus pull-ups, cable length, and collision-free address. |

Enable I2C on the deployed Raspberry Pi, then, with motors and servos made
safe, inspect the bus:

```zsh
sudo i2cdetect -y 1
```

Record the observed addresses in the robot's commissioning record. Do not
write test values to an unknown I2C address.

## Ports and connection method

### Servo ports 0–15

The 16 servo headers are driven by the PCA9685, not by individual Raspberry Pi
GPIO pins. Adeept's servo guidance uses `50 Hz` and a three-wire arrangement:
ground, supply, and signal. The board markings and the servo's data sheet are
authoritative for wire orientation; common hobby-servo colours are brown/black
for ground, red for supply, and yellow/orange/white for signal.

The V3 sample configures the PCA9685 at `50 Hz` and uses `500–2400 µs` as the
example pulse range for channel 0. Control shall use a profile-selected logical
actuator with a calibrated home position, range, direction, and
speed/acceleration policy. A 180-degree servo uses a position contract in
degrees; a continuous-rotation servo uses a signed speed contract and has no
meaningful position topic. Do not reuse the sample's pulse range or a generic
`0–180` degree assumption for every servo.

### Stable servo-port aliases

Control SHALL identify a physical ADM133 servo connection as `servo-00` through
`servo-15`, where the suffix is the zero-padded PCA9685 channel. A robot
profile assigns a separate semantic alias to the selected port, for example
K9 `head-pan` → `servo-00`. This distinguishes a reusable HAT location from
the purpose assigned by one robot; do not invent position names such as
`front-left` for an unverified board connector.

| Physical port alias | PCA9685 channel | Motor-sample reservation |
| --- | ---: | --- |
| `servo-00` | `0` | Not used by the current motor sample. |
| `servo-01` | `1` | Not used by the current motor sample. |
| `servo-02` | `2` | Not used by the current motor sample. |
| `servo-03` | `3` | Not used by the current motor sample. |
| `servo-04` | `4` | Not used by the current motor sample. |
| `servo-05` | `5` | Not used by the current motor sample. |
| `servo-06` | `6` | Not used by the current motor sample. |
| `servo-07` | `7` | Not used by the current motor sample. |
| `servo-08` | `8` | M4 `IN1`. |
| `servo-09` | `9` | M4 `IN2`. |
| `servo-10` | `10` | M3 `IN2`. |
| `servo-11` | `11` | M3 `IN1`. |
| `servo-12` | `12` | M2 `IN1`. |
| `servo-13` | `13` | M2 `IN2`. |
| `servo-14` | `14` | M1 `IN2`. |
| `servo-15` | `15` | M1 `IN1`. |

The reservation column records the vendor motor sample, not a bench-proven
electrical-sharing result. Until the board has been commissioned, Control
SHALL reserve `servo-08` through `servo-15` whenever the corresponding motor
function is enabled. A profile MAY allocate `servo-00` through `servo-07` to
semantic actuators after normal servo commissioning.

### Motor ports M1–M4

Each motor port is a two-wire H-bridge output. Direction is determined by the
polarity of the controlled pair; never use a power reversal at the connector as
the first attempt to fix direction. The current vendor V3 sample maps motor
outputs to PCA9685 channel pairs as follows:

| Motor port | PCA9685 `IN1` / `IN2` channels in the vendor sample |
| --- | --- |
| M1 | `15` / `14` |
| M2 | `12` / `13` |
| M3 | `11` / `10` |
| M4 | `8` / `9` |

These channel pairs are an adapter implementation detail. Control maps logical
`drive.throttle` and `drive.steering` demands to them only after profile
validation, neutral-output validation, and a propulsion-safe bench test.

### Ultrasonic connector

The V3 vendor example uses BCM GPIO `23` for trigger and BCM GPIO `24` for
echo. Its code configures a `gpiozero.DistanceSensor` with a maximum measured
distance of `2 m`; Control must instead publish metres and make maximum range a
profile setting.

Use only the dedicated connector and its expected sensor module. The connector
power and signal conditioning must be confirmed on the actual ADM133 before
attaching another ultrasonic module: an unconditioned `5 V` echo signal must
never be connected directly to a Raspberry Pi GPIO.

### Three-channel line-tracking connector

The current V3 line-tracking sample assigns BCM GPIO `22`, `27`, and `17` to
the left, middle, and right inputs respectively. Control shall sample the three
inputs as left, centre, and right only after recording their physical connector
order and active polarity for the fitted sensor. This source-code mapping is
not evidence that a particular plugged-in sensor has the same electrical
polarity.

The PiWars profile currently maps them to `line_left`, `line_centre`, and
`line_right`. The topic value is boolean or `0`/`1`; it is not a distance or a
calibrated reflectance measurement.

### ADC inputs, battery measurement, and light tracking

The six-channel ADS7830 ADC is integrated on the HAT. The supplied V3 samples
read battery voltage from ADC channel 0 and light level from ADC channel 1.
For battery, the sample assumes a `5 V` ADC reference, a `3 kΩ` / `1 kΩ`
divider (ratio `0.25`), and a nominal `6.0–8.4 V` two-cell range. Those are
sample assumptions, not a calibrated battery model. Control must record the
actual input circuit, divider ratio, reference voltage, sampling/filtering
policy, and valid range before publishing `V` or deriving battery percentage.

The `battery_percentage` topic is always a bounded `0–100 %`. Control must
clamp and validate the result, then calculate it from a documented battery
model rather than copying a raw ADC count or the vendor sample's unclamped
linear calculation. The board's visual battery indicator is not a telemetry
device and has no command topic. Raw ADC counts are diagnostics only.

### I2C and MPU6050 connectors

The manufacturer’s Robot HAT guide describes the I2C connector as the Raspberry
Pi I2C bus: `3.3 V`, ground, BCM GPIO `3` (SCL1), and BCM GPIO `2` (SDA1).
The MPU6050 connector is another connection to the same bus. Confirm this on
the ADM133 silkscreen before wiring. Use `3.3 V` I2C logic only unless the
fitted HAT explicitly includes a tested level shifter.

The MPU6050 provides acceleration and angular-rate data. A driver may publish
roll and pitch after calibration and sensor fusion. It does not provide a
magnetic heading by itself, so it must not be treated as a compass.

### UART connector

The UART connector exposes BCM GPIO `14` (transmit) and BCM GPIO `15`
(receive). Control shall use the stable `/dev/serial0` alias and configure the
baud rate, parity, stop bits, flow control, cable/level standard, and framing
in the attached device's driver. UART console configuration must be disabled
or otherwise deliberately managed before the port is used for a controller.

UART is a physical integration boundary. The attached device gets semantic NATS
topics defined by its Control driver; no raw serial bridge is exposed to
Cockpit.

### WS2812, RGB, single-colour LED, infrared, and buzzer interfaces

These are low-level device interfaces and must be used only through a
Control-owned adapter. The following mappings come from the supplied current
V3 samples. They still require a board-level polarity, current-budget, and
connector-orientation check before activation.

| Function | Current V3 sample mapping | Control implementation notes |
| --- | --- | --- |
| WS2812 chain | SPI0 MOSI, BCM GPIO `10`, through `/dev/spidev0.0` | The sample emits WS2812 timing over SPI at `6.4 MHz`. It demonstrates eight LEDs; Philip's board notes record two onboard LEDs plus an extension connector, so LED count must be profile/configuration data. Enable SPI before use. |
| RGB left | Red GPIO `13`, green GPIO `19`, blue GPIO `0` | The two RGB connectors are common-anode according to Philip's board notes. Use inverted PWM values as in the vendor sample. GPIO `0` is an ID-bus pin: reserve it and verify compatibility with the Raspberry Pi/overlay before use. |
| RGB right | Red GPIO `1`, green GPIO `5`, blue GPIO `6` | GPIO `1` is also an ID-bus pin. Do not assume independent RGB operation until it is bench-tested. |
| Single-colour LED/switch ports | GPIO `9`, `25`, `11` | The V3 LED sample calls these LED1–LED3. GPIO `9` and `11` are SPI0 MISO/SCLK, so these ports and SPI0/WS2812 must be treated as mutually exclusive unless the fitted board is shown to support their simultaneous use. |
| Passive buzzer | GPIO `18` | The V3 sample uses a tonal buzzer. Expose only named, duration-limited notification patterns. |
| Infrared receiver | GPIO `12` | The V3 sample reads it as a button-style input. A receiver-code encoding and repeat policy must be documented before a topic is enabled. |

## 40-pin pass-through and pin ownership

The HAT exposes the Raspberry Pi 40-pin header. Before using any pass-through
pin, reserve it in the active profile and check it is not already used by the
HAT, an overlay, or another connected device. The current known or likely
allocations are:

| Facility | BCM pins or controller | Status |
| --- | --- | --- |
| I2C bus 1 | GPIO `2` / `3` | Shared by PCA9685, ADS7830, MPU6050 connector, and I2C expansion. |
| UART | GPIO `14` / `15` | Dedicated UART connector. |
| Ultrasonic | GPIO `23` / `24` | Confirmed by current vendor V3 sample. |
| SPI0 / WS2812 | GPIO `10` (MOSI) | Vendor V3 WS2812 sample; reserve all SPI0 pins when this output is enabled. |
| Line tracking | GPIO `22` / `27` / `17` | Current V3 sample left / middle / right mapping; verify connector order and sensor polarity. |
| RGB left | GPIO `13` / `19` / `0` | Vendor V3 red / green / blue mapping; GPIO `0` requires compatibility verification. |
| RGB right | GPIO `1` / `5` / `6` | Vendor V3 red / green / blue mapping; GPIO `1` requires compatibility verification. |
| Single-colour LED/switch ports | GPIO `9` / `25` / `11` | Vendor V3 LED1–LED3 mapping; GPIO `9` and `11` conflict with SPI0 use. |
| Buzzer / infrared receiver | GPIO `18` / `12` | Current V3 samples. |
| Servo and motor PWM | PCA9685 at measured I2C address | Do not allocate Pi PWM pins for these functions. |

Do not connect a new HAT or add a GPIO overlay without reviewing this table and
the installed board's schematic or vendor archive first.

## Power and safe commissioning

`Vin`, the battery connector/charger, USB-C power/charging interface, switch,
and power/battery LEDs are electrical interfaces, not software-controlled
ports. Philip's board notes record that USB-C powers the HAT and Pi while also
charging the connected 2S1P battery, and that the charge LED is red while
charging and green when disconnected or full. Verify this power behaviour and
the exact battery chemistry/connector on the fitted board before relying on
it. Use one reviewed power scheme; never rely on a software command to make
work on a live motor supply safe.

For initial commission:

1. Photograph the board labels and record its exact revision.
2. With the Pi unpowered, verify connector orientation, ground, and supply
   rails with the vendor material and a meter.
3. Start with motors disconnected and servos unloaded.
4. Enable I2C, scan the bus, and confirm each expected address.
5. Test one sensor class at a time, recording polarity, scaling, and invalid
   behaviour.
6. Test one output at a time with a current-limited supply and a physical
   emergency stop available.
7. Record the resulting channel/pin map, calibration, and evidence before
   changing any capability from `planned-unverified`.

Control must remain safe if the HAT is absent, an I2C device is missing, a
sensor gives an invalid value, or NATS commands stop arriving.
