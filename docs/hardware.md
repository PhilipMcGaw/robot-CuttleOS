# Hardware interfaces

The ROV electronics, mechanical and BOM archive is maintained in the sibling `robot-NautiPi` project. The historical `Pins.md` material there is a physical-reference starting point only. The relevant KiCad project and the fitted-board commissioning record are authoritative for board-level connectivity. Do not treat a root pin table as an approved Control allocation.

## Interfaces in use

- UART serial links to navigation and attached controllers.
- I2C for sensors, analogue input, PWM output, and EEPROM devices.
- SPI for selected IMU and magnetometer devices.
- GPIO for status, leak detection, and control signals.
- PWM through PCA9685 or board-specific outputs.

## RS485 microcontroller links

Control owns communication with RS485-attached microcontrollers. Cockpit must not open serial devices or implement RS485 framing. Control shall translate validated NATS commands into the microcontroller protocol and publish validated microcontroller telemetry back to namespaced NATS subjects.

The implementation must document the selected electrical interface and transceiver, UART device, baud rate, parity, stop bits, bus termination and biasing, node addressing, frame format, payload encoding, CRC or checksum, half-duplex direction control, response timeout, retry policy, startup discovery, and behaviour when a node becomes unavailable. Until these details are confirmed against the hardware, the RS485 interface is planned and must not be described as bench-tested or production-ready.

The bus design should avoid multiple transmitters speaking at once. Control remains the bus coordinator unless the selected protocol explicitly provides another arbitration method. A lost or malformed RS485 response must not bypass Control safety limits or prevent the hardware loop from entering its safe state.

## Hardware safety

- Disconnect or inhibit thrusters before software changes are tested.
- Start actuator demands at zero and verify that command direction is correct.
- Test lights, servos, and H-bridges unloaded before wet testing.
- Verify battery voltage, current limits, fusing, polarity, and leak detection independently.
- Never rely on a browser control timeout as the only motor safety mechanism.

## Command and actuator boundary

Cockpit maps human inputs to namespaced logical robot commands such as `drive.forward` or ROV motion axes. Control is responsible for converting those logical commands into physical actuator demands. Direction, inversion, motor mixing, channel assignment, limits, ramps, neutral output, command timeouts, and emergency-stop handling must remain in Control and its robot-specific configuration. Hardware wiring must never be encoded in Cockpit input mappings.

Example:

```text
Cockpit: left-stick-y → drive.forward = 0.7
Control: drive.forward = 0.7 → left motor = 0.7, right motor = 0.7
```

The second mapping is illustrative only; actual values and signs must come from the active robot hardware configuration and must be verified with propulsion disabled.

## Hardware-dependent paths

Historical code uses Raspberry Pi device paths such as `/dev/serial/by-id/...`. These are machine-specific and should be discovered and documented on the deployed Pi rather than copied blindly from an old test script.

## Planned Adeept Robot HAT ADM133 adapter

Control will provide the hardware adapter for the Adeept Robot HAT ADM133
(V3.3 family) intended for both K9 and PiWars. It is a Control-owned shared
driver, rather than a Cockpit feature or a separate robot-specific driver.

The active robot profile will select the adapter and describe the confirmed
channel assignments and safe operating configuration for that robot. Cockpit
will continue to publish only logical commands. It must not access the HAT's
GPIO, I2C, PWM, motors, servos, sensors, buzzer, or lighting functions.

The exact installed-board map, electrical connections, output directions,
limits, and emergency-stop behaviour have not yet been confirmed. The adapter
is therefore planned and unverified: it must be tested with motors and other
actuators made safe before it is described as bench-tested.

The complete logical NATS topic map is maintained in
[Adeept Robot HAT ADM133](adeept-robot-hat-adm133.md). It maps board functions
to profile-owned logical command and telemetry identifiers, not to raw pins or
physical motor channels.
