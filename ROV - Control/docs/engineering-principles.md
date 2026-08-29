# Engineering principles

These principles are adapted from the Test-in-a-Box project and apply to future ROV work.

## Separate intent from hardware

Operator and test workflows should describe what the ROV should do—such as set a light level, request a motor speed, or record depth—not how a particular GPIO chip or serial port implements it.

## Hardware independence

Do not embed COM names, transient USB paths, or board-specific commands in Cockpit pages or operator procedures. Use logical device IDs and keep the physical mapping in configuration.

## Mock-first development

Every hardware-facing capability should have a safe mock, replay, or disconnected-hardware path where practical. Windows and macOS development should be useful without the Raspberry Pi connected.

## Units first

Every telemetry value and demand should have an explicit unit and scaling rule. Do not make the operator infer whether a value is volts, decivolts, metres, decimetres, degrees, or a percentage.

## Honest validation status

Document whether a feature is simulated, bench tested, wet tested, or production proven. Keep unsupported platform combinations visible.

## Reproducibility and provenance

Record software revision, hardware revision, configuration, topic mappings, and test conditions for commissioning results. Prefer stable configuration files over undocumented manual changes.

## Safety before convenience

Web configuration must not become the only motor safety mechanism. Changes to camera, power, actuator, or service configuration should be reviewable, reversible, and tested with propulsion disabled first.
