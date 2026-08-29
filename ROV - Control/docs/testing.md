# Test procedure

Run tests in increasing order of risk. Record the date, software revision, hardware revision, and test result for each session.

## 1. Static checks

```bash
python -m py_compile src/rov_control/main.py
```

Confirm that the changed KiCad files open without recovery warnings and that firmware compiles for the selected board.

## 2. NATS and web smoke test

Start NATS Core, then start Cockpit. Verify:

```bash
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/json/
```

Publish a harmless test value and confirm it appears in the Cockpit dashboard:

```bash
nats pub rov.telemetry.system.uptime '{"value":1,"units":"s","profile":"rov"}'
nats sub rov.telemetry.system.uptime --count 1
```

Also verify `/ws/telemetry` in the browser, `/api/session` before and after login, anonymous view-only access, and Login/logout navigation state.

### Browser-assisted time synchronisation

Perform this only on a development RPi with propulsion disabled. Install the profile and `configs/python.service`, run `sudo systemctl daemon-reload`, and restart Control. Sign in to Cockpit as a driver or administrator and open a Cockpit page. Observe the configured `<namespace>.cockpit.command.system.time-sync` command and `<namespace>.control.status.system.time-sync` result with `nats sub`. Compare `date --iso-8601=seconds` with a trusted source before and after the change. Record the profile revision, systemd unit revision, observed offset, and result. Do not describe this feature as bench-tested until that evidence exists.

## 3. Serial protocol test

Connect one controller with actuators disabled. Confirm that startup identification and heartbeat records are received, that malformed records do not crash the control loop, and that Adler-16 IDs match the documented topic.

## 4. Sensor test

With propulsion still disabled, verify system uptime/time, battery telemetry, water sensors, AHRS values, and leak status. Compare displayed units with the raw NATS payloads.

## 5. Actuator bench test

With thrusters physically disconnected or mechanically restrained, issue one output command at a time. Verify zero, positive, negative, range limits, stop behavior, and restart behavior.

## 6. Dry integration test

Connect the full electronics stack without placing the vehicle in water. Verify network, NATS, cameras, Cockpit routes, board heartbeats, power telemetry, and emergency-stop behaviour.

Verify Motion recording, still capture, gallery display, download links, configured recording duration, and free-space retention using a non-production media directory.

## 7. Wet test

Only after the dry test passes: inspect seals and penetrators, perform a tethered shallow-water test, check leak detection continuously, and keep a physical power cutoff available.

## Current limitations

The repository does not currently contain a comprehensive automated test suite. Existing files named `test*` are historical/integration experiments, not a reliable acceptance suite.
