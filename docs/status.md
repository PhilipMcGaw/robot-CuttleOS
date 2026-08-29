# Cockpit current status

## Architecture

The application layer is FastAPI served by Uvicorn. NATS is accessed only by the server; the browser receives telemetry through `/ws/telemetry`. The TypeScript telemetry layer is under `frontend/src` and its browser output is under `src/rov_cockpit/static/dist`. The ROV navigation display is the combined `<rov-hud>` Web Component; shared status instruments remain separate components.

## Implemented behaviour

- FastAPI startup with optional server-side NATS connectivity and read-only operation when NATS is unavailable.
- Browser telemetry through the FastAPI WebSocket endpoint.
- TypeScript state, topic mapping, parsing, and reconnecting WebSocket adapter.
- Independent `<rov-depth>` Web Component consuming shared cockpit state.
- Vue-rendered battery status instrument consuming shared cockpit state.
- Shared translucent operator shell on every page: compact status bar, browser-WebSocket link indicator, 24-hour local clock with a 1 Hz flashing colon, and a hamburger-triggered navigation popover.
- The central shared-header status shows `Simulation mode` while simulation is enabled, `NATS offline` when the server-side NATS client is disconnected, and `No recent alerts.` otherwise.
- Collapsible left-hand live-view diagnostics tray. It currently holds the read-only estimated browser-to-Cockpit network transfer rate and leaves the primary flight display uncluttered.
- Vue-rendered live-view bottom dock presenting the selected camera and live depth, heading, roll, pitch, primary-light percentage, camera tilt, and water temperature without sending control commands.
- The HUD depth scale retains only its graduations and centre read-off line; live numeric depth is presented once in the bottom dock.
- Battery-percentage contract enforced as numeric `0–100` percent; legacy `0–10` and `0–1` scaling is not supported. Missing or invalid percentage telemetry uses the empty battery icon and `-- %` placeholder.
- Independent `<rov-network-status>` and `<rov-depth>` Web Components consuming shared cockpit state until their Vue ports are completed.
- ROV combined `<rov-hud>` instrument presenting roll, pitch, depth, and heading in one navigation overlay. This is the intended navigation instrument for the ROV cockpit.
- The former standalone heading band and depth meter have been removed; heading and depth are rendered only within the combined HUD.
- The HUD presentation has been rebuilt toward the reference design: transparent central attitude arcs, side roll scales, a right-side depth scale, and a bottom heading tape. Heading marks are projected relative to the live heading in 3-degree increments: North/0° uses the largest tick, all other 15-degree divisions use an intermediate tick, and the remaining divisions use minor ticks, with a fixed centre pointer.
- Reusable HUD style editor with live colour and line-thickness controls; settings currently persist in browser local storage.
- Development sensor simulator page with runtime enable/disable control and slider-driven browser telemetry injection.
- Profile-driven browser-assisted time relay: an authenticated driver/admin page publishes UTC Unix milliseconds to the active profile's Cockpit NATS subject on load and every 60 seconds; Control remains the sole service permitted to alter the RPi clock.
- K9/profile-enabled right-edge soundboard drawer. It displays the active profile's sound labels and lets an authenticated driver or administrator publish the validated selected ID to the profile-owned `sound.play` NATS command. ROV and PiWars profiles do not render this drawer.
- Shared-profile validation of Control-owned hardware adapters. K9 and PiWars now bind selected Adeept Robot HAT ADM133 functions to logical command and telemetry keys. K9 additionally maps the semantic aliases `head-pan` and `head-tilt` to stable `servo-00` and `servo-01` port aliases. The Control driver and all physical HAT behaviour remain planned and unbench-tested.
- Canonical Raspberry Pi provisioning for the co-installed Cockpit, Control, and Datalogger services. It renders service, Motion, and Nginx templates for the actual checkout paths; installs authenticated NATS configuration; invokes Control-owned network, SMB, and Avahi deployment; and creates the shared media/CSV directories.
- Canonical first-boot instructions with two source-installation routes: a
  read-only HTTPS route for normal robots, and Philip's Pi-specific GitHub SSH
  route for developer pull/push work. Both produce the same sibling checkout
  layout before Cockpit provisioning begins.
- Canonical Raspberry Pi provisioning installs Zsh, HyFetch, and Oh My Zsh for the selected runtime user, selects the `clean` theme, and adds an interactive-login greeting. It also creates a `visudo`-validated, passwordless-sudo policy for that user; this is intentional for a trusted robot/development machine, not evidence of a hardened multi-user host.
- Existing instruments, camera handling, media capture/download, CSV access, authentication, and Gamepad API support remain part of the application.

## Automated-test verification

The standard-library documentation audit is implemented in `tests/test_documentation.py`. `tests/test_raspberry_pi_provisioning.py` statically checks the provisioner's Zsh, HyFetch, Oh My Zsh, and validated-sudo-policy contract, and checks Bash syntax when Bash is available. Python source compilation and the documentation audit can run without application dependencies. The TypeScript source and generated browser artefacts are checked during development; a complete browser build requires the frontend toolchain.

## Bench-tested and Production-validated status

The current repository state is not recorded as bench-tested or production-validated against a physical ROV. Camera devices, sensors, propulsion hardware, the production NATS link, and reverse-proxy deployment require separate evidence before those statuses may be claimed.

## Planned or unverified

- Profile-driven selection of instrument modules beyond the current ROV HUD and shared status instruments.
- Robot-backed persistence for instrument visual settings.
- Profile-defined live-dock controls, including properly authorised arm/mode/camera actions and live Control status.
- Alert and NATS-health summaries for the shared status bar; the current `Link` indicator intentionally represents only the browser WebSocket.
- A depth-scale configuration GUI, with robot-backed minimum, maximum, graduation-step, visibility-window, and presentation settings.
- CSS Grid, Pico.css, Vue component migration, and complete TypeScript frontend migration.
- A profile-compatible icon-system migration: introduce library-neutral icon IDs and a locally bundled, curated SVG registry for new Vue components; assess Lucide as the preferred candidate, then retire Font Awesome only after all remaining template and legacy-component uses have migrated.
- Reproducible TypeScript generation in every supported development environment.
- Complete production authentication and authorisation hardening.
- Raspberry Pi bench validation of browser-assisted clock synchronisation, including the deployed `CAP_SYS_TIME` systemd capability and NATS status result.
- Raspberry Pi 3B+ Trixie Lite 64-bit bench validation of the canonical provisioner, NATS service override, Wi-Fi/hotspot failover, SMB share, Motion camera configuration, and co-installed service restart behaviour.
- Raspberry Pi bench validation of the runtime-user shell, Oh My Zsh installation, HyFetch greeting, and passwordless-sudo policy on a clean target image.
- Control-side K9 sound-file resolution and speaker playback. The Cockpit drawer publishes the logical request, but it does not yet prove that a robot sound was produced.

## Important references

- `MASTER_CONTEXT.md`
- `docs/documentation-policy.md`
- `docs/development.md`
- `docs/deployment.md`
- `docs/testing.md`
- `tests/documentation_change_policy.py`
- `tests/documentation_change_policy.json`
- `frontend/src/transport/telemetry-websocket.ts`
- `frontend/src/telemetry/store.ts`
- `frontend/src/components/instruments/rov-depth.ts`
- `src/rov_cockpit/static/dist/main.js`
- `src/rov_cockpit/static/dist/components/rov-depth.js`
- `configs/nats.env.example`
- `scripts/0_provision_raspberry_pi.sh`
- `tests/test_raspberry_pi_provisioning.py`
- `tests/test_k9_soundboard.py`
- `scripts/1_install_dependencies.bat`
- `scripts/2_start_app.bat`
