# Test procedure

Run tests in increasing order of risk. Record the date, software revision, hardware revision, and test result for each session.

## 1. Static checks

```bash
python -m py_compile src/rov_cockpit/app.py src/rov_cockpit/auth.py
python tests/test_status_instruments.py
python tests/test_raspberry_pi_provisioning.py
```

Confirm that the changed KiCad files open without recovery warnings and that firmware compiles for the selected board.

## 2. NATS and web smoke test

Start NATS Server, then start Cockpit. Verify:

```bash
curl http://127.0.0.1:8080/
curl http://127.0.0.1:8080/json/
```

Publish a harmless test value and confirm it appears in the Cockpit dashboard:

```bash
nats pub system.uptime '0 00:00:01'
nats sub system.uptime --count=1
```

Also verify `/ws/telemetry` in the browser, `/api/session` before and after login, anonymous view-only access, and Login/logout navigation state.

With NATS stopped, confirm that the central header status becomes `NATS offline`.
On `/simulator/`, enable simulation and confirm that the same surface changes immediately to `Simulation mode`; disable it and confirm that the status returns to the current NATS state.

## 3. Serial protocol test

Connect the Cockpit to a test NATS server with actuators disabled. Confirm that telemetry is displayed, malformed payloads do not crash the web service, and browser WebSocket reconnect behaviour is visible.

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

## Browser-assisted time synchronisation test

Perform this only on a development RPi with propulsion disabled. Install the active profile and updated Control unit, then run `sudo systemctl daemon-reload` and restart Control. Sign in to Cockpit as a driver or administrator and open a page. Confirm a message on `<namespace>.cockpit.command.system.time-sync`, then inspect `<namespace>.control.status.system.time-sync` and `journalctl -u rov-control` (or the deployed Control unit name). Check `date --iso-8601=seconds` before and after only when it is safe to alter the development clock. Do not use a browser-supplied time source as production evidence of time accuracy; compare it with a trusted time source and record the result.

## Live diagnostics tray test

Open the live Cockpit page and use the left-edge diagnostics tab. Confirm that the tray expands between the top status bar and lower dock, displays estimated browser-to-Cockpit upload and download rates, and closes using its close control. The rate is diagnostic-only: it must not claim robot network health, alter Control behaviour, or overlap the primary HUD or command dock.

## K9 soundboard drawer test

On a development system, start Cockpit with `ROBOT_PROFILE=k9` and use a test
NATS server with no live actuator hardware. Confirm that the right-edge
soundboard tab is present, lists the three K9 profile sound labels, and opens
and closes without affecting the diagnostics tray. Confirm that a viewer sees
disabled buttons, then sign in as a driver or administrator. Select one sound
and verify exactly one message on `k9.command.sound.play` with its configured
sound ID as `value`, the profile ID `k9`, and source
`cockpit-sound-drawer`. An accepted Cockpit request does not demonstrate audio
playback: record separate Control and speaker bench evidence before claiming
that a K9 sound was heard.
# Documentation currency audit

Run `python tests/test_documentation.py` before submitting changes. The check is intentionally independent of application dependencies so that documentation drift can be detected on a clean or locked-down workstation. CI runs the same command.
