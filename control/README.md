# ROV control service

`src/rov_control/main.py` is the hardware-facing Python service. It reads NATS demands, drives servo and H-bridge outputs, samples analogue channels, and publishes telemetry to NATS.

Run locally on macOS/Linux with:

```bash
./run.sh
```

The service is run as the `rov_control` package and expects the project `.venv`, a reachable NATS Core server, and target hardware. Windows/macOS development should use mock or disconnected hardware; GPIO, I2C, SPI, PWM, and serial behaviour is Raspberry Pi/Linux-specific.

Do not run this service against connected propulsion hardware without following `docs/testing.md`. The control service must remain independent from Cockpit so a web or database failure cannot directly stop or destabilise the hardware loop.

## Browser-assisted clock synchronisation

For an RPi without an RTC, Control can accept an authenticated Cockpit browser's UTC time through the active profile's namespaced NATS contract. Only Control can call Linux `time.clock_settime`; its deployed systemd service receives the narrow `CAP_SYS_TIME` capability required for that action. See [the NATS contract](../docs/nats.md#browser-assisted-time-synchronisation) and [deployment guidance](../docs/deployment.md#browser-assisted-clock-synchronisation). The mechanism is implemented but has not yet been bench-tested on an RPi.
