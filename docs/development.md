# Development setup

## Prerequisites

- Python 3.11 or newer.
- `uv` for macOS/Linux dependency and environment management.
- PowerShell and internet access for the Windows WinPython bootstrap.
- A reachable NATS Core server for telemetry-backed runs.
- Linux/Raspberry Pi hardware for GPIO, serial, I2C, SPI, and PWM behavior.
- A Bluetooth or USB HID gamepad is optional for controller testing.

## Windows setup

The Windows frontend helper validates the project-root `package.json`, changes to the project root for npm operations, and propagates npm/TypeScript failures. A successful launcher message therefore indicates that the frontend build command actually completed successfully.

Windows development deliberately follows the Test-in-a-Box portable-runtime pattern. Run:

```bat
scripts\1_install_dependencies.bat
scripts\2_start_app.bat
```

The installer downloads 64-bit WinPython into `runtime\` when required, verifies its SHA-256 checksum, and installs the shared `requirements.txt` with that runtime's `pip`. It does not use `uv`. The scripts reject UNC paths; copy the repository to a local drive or map the share to a drive letter first.

### Windows design decisions

- **UNC paths are rejected** because portable Python, package installation, subprocess working directories, and browser launchers can behave inconsistently when the project is run from `\\server\share\...`. A local drive or mapped drive gives the bootstrap stable filesystem semantics.
- **Portable Python is used** so the project does not depend on a pre-existing system Python installation, registry configuration, administrator-managed PATH entries, or a particular Python version. The runtime is kept in the project and reused on later runs.
- **`uv` is intentionally not used on Windows**. The Test-in-a-Box Windows pattern uses portable Python plus `pip`, which removes an extra bootstrap dependency and keeps installation self-contained. `uv` remains useful on macOS/Linux, where the shell workflow already expects it.
- **No administrator rights are required** for the Windows bootstrap. WinPython, packages, and project environments are installed below the project directory. The user only needs write access to the project folder and normal outbound access to the download/package hosts.
- **Checksum verification is required** before the portable runtime is extracted, so a partial or altered download is not silently used.

## macOS and Linux setup

The shell scripts create a **unified monorepo-level Python virtual environment** and install all service dependencies:

```bash
./scripts/1_install_dependencies.sh
./scripts/2_start_app.sh
```

**Virtual environment location:** `.venv/` at the monorepo root

**What gets installed:**
- All Cockpit (FastAPI) dependencies
- All Control (hardware) dependencies
- All Datalogger (telemetry) dependencies
- Development tools (pytest, black, ruff, mypy)

**Note:** The `pyproject.toml` file is used for dependency management rather than package installation. The installation script installs dependencies directly without attempting to install the monorepo as a Python package, which better fits the multi-service architecture.

### Running individual services

Each service's `run.sh` script uses the monorepo venv automatically:

```bash
# From the monorepo root:
./cockpit/run.sh       # Start Cockpit (web app)
./control/run.sh       # Start Control (hardware)
./datalogger/run.sh    # Start Datalogger (telemetry logger)
```

Or start from VS Code debug menu (F5) using the configured launch configurations.

### Installing a single service's dependencies

If you only need a specific service (e.g., Datalogger on a production robot), run that service's installer:

```bash
./datalogger/scripts/1_install_dependencies.sh  # Installs only Datalogger deps
```

This still uses the monorepo-level `.venv/` but skips unnecessary dependencies.

## Cockpit

```bash
cd Cockpit
../.venv/bin/python app.py
```

The application listens on `0.0.0.0:8080` by default. Use `APP_HOST`, `APP_PORT`, and `APP_RELOAD=true` to override local behavior. The production-style command is:

```bash
../.venv/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8080
```

### Cockpit access modes

The Cockpit provides anonymous view-only access. Driver and administrator actions require login:

- `viewer` is the anonymous default and can view telemetry, video, media, and downloads.
- `driver` is authenticated and is intended for gamepad and vehicle-control functions.
- `admin` is authenticated and is intended for configuration, Motion, media, and system administration.

The Login link changes to the signed-in username with a Font Awesome logout icon. Drivers can change their own password at `/account/`; administrators can change their own and other configured accounts. User accounts are stored in `Configs/users.json` as PBKDF2 password hashes. Set a strong `COCKPIT_AUTH_SECRET` before using authentication beyond local development.

Useful routes:

- `/` — main dashboard.
- `/map/` — map view.
- `/3d/` — 3D view.
- `/files/` — placeholder files page.
- `/json/` — dashboard-oriented NATS snapshot.
- `/docs` — FastAPI-generated API documentation.

### Additional Cockpit interfaces

The Cockpit also exposes `/login`, `/logout`, `/account/`, `/ws/telemetry`, and `/api/session`. `/docs` is the FastAPI-generated API documentation route. Anonymous viewers can use the dashboard; driver/admin authentication is required for the account page.

## Control service

```bash
cd Control
../.venv/bin/python main.py
```

This process expects the target hardware and a reachable NATS Core server. Do not run it against connected propulsion hardware without first following the staged test procedure.

## Configuration

The Cockpit NATS connection uses `NATS_URL` and `NATS_SUBJECT`, defaulting to 
ats://127.0.0.1:4222` and `>`. Browsers receive telemetry through the Cockpit WebSocket and do not connect directly to NATS.

### Browser-assisted Raspberry Pi clock synchronisation

The active robot profile is loaded once at Cockpit start-up. Production uses `/etc/robot/profile.json`; local development falls back to `configs/profiles/$ROBOT_PROFILE.json` when the deployed file is absent. Cockpit supplies that non-optional profile context to every rendered page, so the shared title and header identity cannot diverge or fail when a page is rendered. When its `time_synchronisation` object is enabled, an authenticated `driver` or `admin` browser page sends its UTC time to `POST /api/system/time-sync` on page load and every 60 seconds. Cockpit validates and relays a JSON message over the profile-defined NATS subject; it does not set the host clock itself.

When the active profile enables `soundboard`, the live page adds a translucent
right-edge soundboard drawer modelled on the diagnostics tray. K9 currently
enables it. The drawer lists only the profile-defined labels and sends an
authenticated `driver` or `admin` selection to `POST /api/soundboard/play`.
Cockpit validates the selected ID and publishes it as `value` on the
profile-defined `<namespace>.command.sound.play` subject; it does not expose or
play the sound file in the browser. Control must resolve the ID to the
profile-defined sound file and operate the speaker hardware. Control-side
playback remains planned and unbench-tested.

The payload uses UTC Unix time in milliseconds and the active profile identity. Control validates the message, then applies it only on Linux with `CAP_SYS_TIME`. A viewer session cannot request clock changes. This is intended to correct an RPi without an RTC after it gains Cockpit access; it is not an NTP replacement and has not yet been bench-tested on an RPi.

The TypeScript telemetry layer is authored under `frontend/src/` and receives browser state from `/ws/telemetry`. The no-bundler build emits browser modules into `cockpit/src/rov_cockpit/static/dist/`. Telemetry values are normalised so numeric strings from NATS or the simulator become numbers before instruments consume them. NATS logic remains exclusively in FastAPI; browsers never connect directly to the broker.

The launcher calls `scripts/build_frontend.bat` on Windows or `scripts/build_frontend.sh` on macOS/Linux before starting the application. These scripts compile TypeScript into `cockpit/src/rov_cockpit/static/dist/` when npm is available. If npm is unavailable, they report a warning and retain the existing compiled output so the Cockpit can still start.

The depth top-bar display is now implemented as `<rov-depth>`. It consumes the typed `sensor/water/depth` state without opening a WebSocket or knowing about NATS.

The live ROV page does not render the former standalone heading band or depth meter. These values are owned by the combined `<rov-hud>` instrument.

The HUD is a transparent video overlay. Its reference presentation uses open central attitude arcs, roll scales on both sides, a right-side depth scale, and a graduated heading tape along the bottom. The heading tape follows the upstream CompassHUD approach: 3-degree marks are projected relative to the current heading, a +/-75-degree region is retained, North/0° has the largest tick, and 15-degree divisions have intermediate ticks. The video remains visible through the instrument; the HUD must not use a filled dark panel as its primary background.

### HUD interface details

The attitude meter is the combined `<rov-hud>` instrument. It is centred in the usable viewport between the top status bar and bottom command dock. The two open white arcs and their horizontal reference lines rotate together around the attitude centre when roll changes. The reference lines start at the outside edges of the arcs and use clean square ends; there is no amber aircraft marker inside the arcs. The live roll value is shown above the meter and the live pitch value below it. If attitude telemetry is missing, the geometry remains visible and the readouts show `--`.

The pitch ladders are drawn in the same transformed coordinate system as the attitude arcs, so they respond to both pitch and roll. Positive pitch graduations appear above the zero line and negative graduations below it. The ladders include `+/-10`, `+/-20`, `+/-30`, `+/-40`, and `+/-50`, with dotted minor lines and solid zero lines. Labels are outside the markings and the ladders remain outside the arcs with a deliberate gap; they do not have bent ends. At zero pitch and roll, both zero lines align with the attitude centre. The ladder range is clipped to the middle portion of the viewport to prevent unrelated off-screen labels from appearing.

The depth gauge is on the right and shares the attitude centreline. At zero depth, its `0 m` graduation is level with the attitude centre, while the live numeric depth is shown separately below the scale and in the bottom command dock. The gauge uses 5 m graduations around the current depth and keeps the scale readable for positive and negative values. The bottom dock shows depth, water temperature, light percentage, camera tilt, and the selected camera without sending control commands.

The heading tape is centred on the current heading and uses 3-degree marks. It retains a +/-75-degree window, with the centre heading shown above the amber marker. North/0 degrees uses the largest tick; 15-degree divisions use intermediate ticks; other marks use short ticks. The tape is raised above the dock and its labels are centred on their tick positions.

HUD text, line, accent, and line-width values are configurable through the HUD style editor and persist in browser local storage per profile/component. The default HUD uses white text and lines with amber heading/readout accents. The status dock uses amber for live instrument icons and disarmed state, green/amber/red battery state colours, and muted text for unavailable values.

## HUD style editor

The main Cockpit page includes a reusable `rov-instrument-style-editor` for the ROV HUD. It provides live controls for text colour, line colour, accent colour, and line thickness. Values currently persist in browser local storage under a profile- and component-specific key; robot-backed profile persistence is planned.

## Development sensor simulator

The `/simulator/` page is always available from the main navigation. Its runtime switch is off by default unless `COCKPIT_ENABLE_SIMULATOR=true` is set. When enabled, slider changes automatically send depth, heading, pitch, roll, primary-light percentage, camera tilt, water temperature, battery voltage, and battery percentage values into the Cockpit browser telemetry path; no send button is required. The simulator roll and pitch controls are limited to `-45°` to `+45°` for convenient testing, while both telemetry contracts accept the full `-90°` to `+90°` range. Camera tilt is `-90°` to `+90°`, light percentage is `0–100 %`, and water temperature is in `°C`. Simulation injection broadcasts each submitted topic directly to connected WebSocket clients before the request completes, so the HUD and status instruments update together. The simulator does not publish to NATS or Control and must not be enabled during live physical robot operation.
All pages use a shared compact operator shell from `templates/header.jinja`: a translucent top status bar, a centred alert surface, and a hamburger-triggered translucent navigation popover. The hamburger button stays geometrically centred; its three-bar glyph has an independent, small downward optical adjustment so it aligns with the adjacent otter/ROV identity lock-up without moving the button or its hit area. The browser-local 24-hour clock, battery percentage, and voltage appear in that bar. The clock inherits the surrounding status typography and flashes only its colon at 1 Hz; reduced-motion preferences disable the flash. The centred alert surface polls the read-only `/api/system/status` endpoint every 5 seconds: it shows `Simulation mode` whenever simulation is enabled, otherwise `NATS offline` when the server-side NATS client is disconnected, otherwise `No recent alerts.`. Simulation takes precedence over the NATS state, and a simulator toggle refreshes the label immediately. Its `Link` indicator reports the Cockpit browser WebSocket state only; it is deliberately not presented as a NATS broker-health indicator. The header intentionally does not display temperature, heading, depth, or uptime. Heading and depth belong in the combined live HUD; temperature and uptime remain available through the telemetry/data views.

The live view has a reusable left-hand diagnostics tray. It is collapsed to a small diagnostics tab by default and expands within the area between the status bar and bottom dock. Its first read-only item is the estimated browser-to-Cockpit upload and download rate; it is not a measurement of the robot's Wi-Fi or Internet throughput. Additional diagnostic widgets may use the tray without changing the primary flight display or gaining control authority.

The live page adds a translucent bottom command dock rendered by the frontend cockpit source. It displays the selected front-camera view and live depth, heading, roll, pitch, primary-light percentage, camera tilt, and water temperature from the shared telemetry store. Light level uses `output/lights/left` as the currently selected primary ROV light and is numeric `0–100 %`. Camera tilt uses `sensor/camera/main/pitch`, in degrees relative to the ROV body (`0°` is straight ahead); a plus sign is shown for a positive angle. Water temperature uses `sensor/water/temperature` in `°C`. The right-hand control area is an explicit read-only placeholder for future profile-defined commands: it does not arm, change mode, or send a control message. That safety boundary remains owned by Control. The live page is fixed to the viewport, with the camera vertically centred in the space between the top bar and dock; it must not introduce a document scroll bar. Secondary pages retain normal document scrolling below the fixed shared header.

### Shared status and sound assets

The shared header uses live telemetry-aware custom elements for battery and voltage. Battery percentage is treated as numeric `0-100` percent and displays a Font Awesome empty, quarter, half, three-quarter, or full battery icon. The icon and value use green for normal operation (50-100%), amber for low charge (25-49%), red for critical charge (1-24%), and muted grey when unavailable or at 0%. Voltage uses a bolt icon and displays the numeric value in volts.

The NATS indicator is separate from the browser WebSocket indicator. It polls `/api/system/status` and shows a normal link icon when the server-side NATS client is connected, or a red link-off icon and red `NATS` label when NATS is offline. The central alert reports `NATS offline` when appropriate, while the simulator state takes precedence and reports `Simulation mode`.

K9 sound files are stored in `assets/robots/k9/audio/`, outside the
configuration directory. `configs/profiles/k9.json` currently defines 58
profile-specific sound IDs and maps them to `.mp3` files in that directory.
Future robot-specific assets belong under `assets/robots/<profile_id>/`,
grouped into typed directories such as `audio/`, `images/`, `models/`, and
`ui/`; shared assets belong under `assets/common/`. Runtime-generated stills
and recordings remain under `media/`. K9 speech that has no pre-recorded
clip is generated by `assets/robots/k9/tools/k9-say.sh`; pre-recorded clips
remain under the K9 audio directory. Cockpit publishes only the validated
logical sound ID; Control remains responsible for resolving and playing the
file on the robot.

#### K9 generated speech helper

The K9 speech helper is located at `assets/robots/k9/tools/k9-say.sh`. It
converts supplied text into a K9-style voice and plays it immediately through
the Raspberry Pi audio output. It does not currently save an audio file.

Usage:

```bash
bash assets/robots/k9/tools/k9-say.sh "text for K9 to speak"
bash assets/robots/k9/tools/k9-say.sh -p calm "Correct, mistress"
bash assets/robots/k9/tools/k9-say.sh --preset alert "Scanning for hostiles"
bash assets/robots/k9/tools/k9-say.sh -p alarm "Danger! Danger!"
```

The options are:

- `-p` or `--preset` selects the voice treatment.
- 
ormal` is the default preset.
- `calm` uses a slower, softer delivery.
- `alert` uses a faster, brighter delivery.
- `alarm` uses the fastest and most aggressive delivery.

The command accepts the remaining arguments as the text to speak. Text is
required; calling it without text prints the usage message and exits with an
error. An unrecognised preset currently falls back to 
ormal`.

The helper requires `espeak-ng`, `sox`, and `alsa-utils`. The Raspberry Pi
provisioner installs these automatically when `ROBOT_PROFILE=k9` is selected.
It can be used manually on an already-provisioned K9 with:

```bash
sudo apt install espeak-ng sox alsa-utils
```

The current Cockpit soundboard publishes logical pre-recorded sound IDs. K9
generated speech is a separate helper until Control-side playback and a
profile-defined generated-speech command are implemented.

### USB microphone and live audio streaming

The Raspberry Pi provisioner installs shared `alsa-utils` support for every
robot profile. A USB microphone can therefore be discovered with `arecord -l`
or `arecord -L` after it is connected. The current repository does not yet
capture or stream microphone audio through Cockpit; it only provides the ALSA
utilities needed for future capture and audio playback.

The planned design is profile-driven, initially enabling K9 and optionally ROV
with capabilities such as `microphone` and `audio_stream`. A robot-side ALSA
capture service would encode the microphone stream and expose it to the
operator through the existing Nginx boundary. HTTP Opus is the initial simple
option; WebRTC should be evaluated if lower latency is required. The stream
must be authenticated or otherwise restricted, support device selection and
reconnection, and provide a clear privacy/status indicator. The microphone
must never become part of the hardware-control safety path.

The Windows dependency and launcher batch files print their failure reason, why it matters, and corrective action, then pause before exiting so errors remain visible in a terminal window.

## Camera media

Motion is configured for 30-minute rolling MP4 recordings by default under its target directory. The Cockpit `/files/` page can change the segment length in minutes, lists recordings, provides download links, and can capture the current high-resolution Motion frame as a still image. Restart Motion after changing the setting. Set `MEDIA_ROOT` and `MEDIA_MIN_FREE_GB` when deploying the Cockpit; the media maintenance path removes the oldest recordings when the free-space floor is reached.

## Gamepad development

The Windows frontend build automatically bootstraps the pinned official Node.js/npm archive into the project-local 
ode-runtime/` directory when required. It verifies the archive against `SHASUMS256.txt`, requires no administrator rights, does not modify PATH, and rejects direct UNC execution. Linux `scripts/1_install_dependencies.sh` installs distribution 
odejs` and 
pm` packages through `apt-get` and `sudo` when absent. macOS deliberately does not install Node.js; it uses available npm, while the committed compiled output remains the fallback when npm is unavailable.

General-purpose page styling now uses the readable Pico CSS file from the frontend dependency `@picocss/pico`. It is served as `cockpit/src/rov_cockpit/static/css/pico.css`; Cockpit-specific variables and compatibility classes are maintained in `cockpit/src/rov_cockpit/static/css/cockpit.css`. The frontend build refreshes this file from the package when npm is available.

The Browser Gamepad API works with standard HID controllers on Windows and macOS in current Edge, Chrome, and Firefox releases; Safari is supported on macOS. Pair the controller in the operating system before opening `/gamepad/`. Firefox may require a button press before it reports the controller.

Use `localhost` or `127.0.0.1` for local development. A deployed Cockpit should use HTTPS. Settings on `/gamepad/` are stored in the browser and can be adjusted without changing Python code. Test with propulsion disabled until the control mapping, arm button, dead-man button, neutral-on-disconnect behavior, and timeout handling have been verified.
Vue status instruments require `window.rovCockpitTelemetry` to be assigned before their mount lifecycle runs; the frontend bootstrap preserves that ordering so migrated instruments receive the initial telemetry snapshot.
Battery state-of-charge telemetry shall be numeric percent in the inclusive `0–100` range. The shared header mounts a telemetry-aware custom battery element; the old inline battery renderer and legacy `0–10` conversion are removed. Values are interpreted strictly as percentages, so `10` means 10 % and `100` means 100 %.
The battery element selects the Font Awesome full, three-quarter, half, quarter, or empty battery icon according to the percentage and applies normal, low, or critical CSS colours. Invalid telemetry displays the empty icon and the compact placeholder `-- %`, matching the other telemetry values.
The shared voltage instrument displays the bolt icon followed directly by the voltage value, rounded to one decimal place; it does not repeat the word `Voltage`. The live Cockpit background uses `cockpit/src/rov_cockpit/static/background.jpg`.
The HUD heading tape keeps the current heading centred beneath its amber marker. It uses 3° tick spacing and retains a ±75° window around the current heading, matching the Blue Robotics reference renderer. North/0° has the longest, heavier tick; every other 15° division uses the intermediate major tick; all 3° divisions between them use the minor tick. Cardinal headings retain their compass labels but do not increase the tick length. The current numeric heading is displayed above the fixed amber centre marker, while the lower scale provides the corresponding cardinal or degree graduation. The tape uses the configurable HUD text colour and a dark text shadow for contrast over live video. On the live page, it is raised above the command dock. Its horizontally clipped label lane is 2.65rem high so tick labels are fully visible without allowing out-of-window ticks to appear. Roll is displayed above the attitude instrument and pitch below it. Each heading tick is centred on its own position before the relative bearing offset is applied, preventing heading labels and tick marks from overlapping.
The attitude renderer follows the uploaded Blue Robotics implementation pattern: pitch marks are drawn in the attitude coordinate system, roll rotates that system, and pitch translates it. The project keeps its own telemetry topics and styling controls.
The attitude reference geometry is drawn when the HUD mounts, even if telemetry is unavailable; unavailable roll and pitch values do not collapse the instrument layout. Roll and pitch labels sit just outside the upper and lower arc ends rather than at the outer canvas edges.
The attitude arcs and their solid centre lines form one fixed viewport-centred roll layer. The centre lines remain attached to the outside of the arcs and rotate around the viewport centre with roll. No amber or yellow aircraft reference marks are drawn inside the arcs. The outside roll scales keep their `0` lines aligned and translate together with pitch.

The pitch scale labels are positioned outside their markings: labels sit to the left of the left-hand lines and to the right of the right-hand lines.
Positive pitch values are above the centre line; negative pitch values are below it.
Both outside scales remain fixed on their respective sides of the HUD and rotate in place around their own centres. Their static vertical centring is applied outside the roll/pitch transform, so roll cannot make the scale groups drift.
After pitch and roll are applied, the scale’s continuous pitch position is explicitly aligned with the extension of the attitude centre line on both sides. This is not limited to visible graduations, so the scales continue to move correctly beyond `±30°`.
The alignment keeps that pitch position at a constant radial distance from the attitude-circle centre as roll changes, preventing the outside scales from appearing to pull away from the central instrument.
At zero pitch and zero roll, the `0°` line on both outside scales aligns horizontally with the centre of the attitude arcs.
The attitude arc canvas is fixed exactly at the viewport centre (`50%` / `50%`) and is not vertically offset by pitch.
The outside pitch scales use 50% increased spacing between markings and show `50, 40, 30, 20, 10, 0, -10, -20, -30, -40, -50`. Changing pitch translates both scales together using the rendered marker spacing, so the corresponding value (for example, `-10°` or `+10°`) aligns with the solid attitude centre line. Individual markings are hidden outside the middle 60% of the viewport (20% to 80%) and reappear when pitch and roll bring them back into that region.
The depth scale is also centred vertically on the viewport at zero depth; its read-off line remains centred while the scale translates with depth.
The depth scale and simulator control use `+10 m` down to `-150 m`; the simulator defaults to `0 m`. The scale shows 5 m graduations around the current depth and uses the same middle-60% visibility window as the pitch scales. The reusable depth range is defined in the `DEPTH_SCALE` configuration object in the frontend cockpit source; changing its `min`, `max`, and `step` values regenerates the markings and alignment limits together.
Because the depth range is asymmetric, the scale is explicitly offset so its `0 m` marking—not the list midpoint—aligns with the viewport centre at zero depth.
The live depth value is displayed separately below the right-hand scale and in the bottom command dock; it does not overlap the scale graduations. Depth translation directly aligns the nearest labelled graduation to the fixed centre line, so values such as `-70 m` and `+10 m` select the correct markings across screen sizes. Depth graduation lines are half the previous length.
Pitch translation of the outside scales is applied in the roll-rotated coordinate system, keeping pitch markings aligned with the attitude centre line when pitch and roll are both active. The attitude centre lines use butt caps so their ends remain clean and square.
The attitude centre-line reach is constrained to the canvas’s inscribed circle, preventing clipping and keeping both lines the same rendered length at every roll angle.
All HTML pages extend `templates/base.jinja`. The base template owns the document shell, shared styles, the cache-busted frontend bootstrap, and `header.jinja` navigation; page templates provide only their content and page-specific scripts. This prevents navigation and layout divergence.
Third-party frontend licences are recorded in `LICENSES.md`. In particular,
Vue is redistributed as a committed browser runtime and Pico CSS is served as
a committed readable stylesheet, so their upstream MIT notices must remain
documented alongside the project licences. Update `LICENSES.md` whenever a
frontend package or bundled static asset is added, removed, or replaced.


### Static demo background video

To optionally upload the generated demo after a build, set `DEMO_UPLOAD_DEST`
to an rsync destination:

```bash
DEMO_UPLOAD_DEST="user@example.com:/var/www/cockpit" \
  ./scripts/build_static_demo.sh
```

The generator asks for confirmation at the end and defaults to skipping the
upload. The upload uses `rsync -avz` without `--delete`; verify the destination
and command in `scripts/build_static_demo.sh` before using it for a live site.

The static demo embeds the YouTube video `4Gz9FJzXeb8` as a muted, autoplaying, looping background using the YouTube iframe player. The video is not downloaded or redistributed; the demo retains the local background image underneath as a fallback. The source is credited in `static-demo/index.template.html` and carried into the generated `static-demo/index.html` as Baited Remote Underwater Video Surveys (BRUVS), with Ocean First Institute and the YouTube video linked. Its licence remains whatever licence the uploader has selected, and must be confirmed before treating the video as reusable media; successful embedding is not proof of a reuse licence.
