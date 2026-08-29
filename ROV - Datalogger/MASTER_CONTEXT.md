# ROV Datalogger Master Context

Interactive command examples assume Zsh. Shell scripts may use the interpreter declared by their shebang; documentation must keep interactive commands Zsh-compatible and identify any script-specific interpreter requirements.

The Datalogger is part of the shared multi-robot framework. Each robot uses a distinct NATS namespace and has one active, Git-versioned JSON robot profile on its Raspberry Pi. The Datalogger records the subjects produced by that robot without changing commands or applying Control-side actuator mappings. Profile and namespace changes require corresponding documentation and test updates.

The Datalogger is co-installed with Cockpit and Control on the robot Raspberry Pi and communicates with both through NATS Core. It observes and records the agreed message subjects; it must not intercept, modify, delay, or become a dependency for control messages.

The canonical Raspberry Pi installer is Cockpit's
`scripts/0_provision_raspberry_pi.sh`. It creates the Datalogger virtual
environment, creates the SQLite and shared Cockpit-media directories, and
renders `configs/datalogger.service` with the actual checkout path and runtime
account. The service receives the authenticated local NATS URL through the
root-readable `/etc/robot/nats.env` systemd environment file. No deployed unit
may assume `/home/pi/ROV---Datalogger`. This provisioning path is implemented
but remains unbench-tested on Raspberry Pi hardware.

The intended deployment loads and validates the shared profile during boot. The current Datalogger implementation does not yet load the profile or publish profile identity in runtime status; those remain planned work.

Robot profiles currently originate in the Cockpit repository under `configs/profiles/`. Datalogger consumes the deployed active profile for namespace and recording metadata and must not maintain an independently edited copy.

The shared runtime profile is initially `/etc/robot/profile.json` on the robot Raspberry Pi and is loaded during boot.

On Linux, the documented clone location is `~/robots/ROV---Datalogger`, beside the other ROV repositories. On macOS, use a user-selected workspace beneath the home directory, for example `~/Projects/ROV/ROV---Datalogger`. This is a default convention, not a hard-coded path; scripts must derive paths from their own location.

The enforceable documentation policy is `docs/documentation-policy.md`, with contributor guidance in `CONTRIBUTING.md`, current status in `docs/status.md`, and checks in `tests/test_documentation.py` and `tests/documentation_change_policy.py` using `tests/documentation_change_policy.json`.

The Datalogger repository subscribes to NATS Core and records a message to SQLite only when its payload differs from the last recorded value for that subject. Changes include their UTC timestamp, subject, raw payload, text representation, and normalised JSON where valid. Repeated identical values are ignored, including after restart. It provides a foundation for CSV export and later reporting. It does not control the ROV or provide a web UI.

Windows support is provided through `scripts/1_install_dependencies.bat` and `scripts/2_start_app.bat`. These follow the TiaB workflow: they detect UNC paths, install portable WinPython locally without administrator rights, use `requirements.txt` when present, and do not use `uv` on Windows.

The service is started with `PYTHONPATH=src python -m rov_datalogger.main`. Configuration is supplied through `NATS_URL`, `NATS_SUBJECT`, `DATALOGGER_DATABASE`, `DATALOGGER_RETENTION_DAYS`, and `DATALOGGER_EXPORT_DIR`. On an installed robot, the provisioned unit sets the last four values and imports the authenticated `NATS_URL` from `/etc/robot/nats.env`; local development may set them directly. Retention defaults to 30 days. Only changed payloads are stored; raw payload bytes are retained and valid JSON is stored in a normalised companion column for analysis. Expired rows are removed at startup and periodically during operation. SQLite is disposable: if the database is missing or lost, startup creates a new one; no restore workflow is required. The current `telemetry.csv` export is written to `DATALOGGER_EXPORT_DIR`, which should be the shared Cockpit media CSV directory on a robot. The Datalogger uses NATS Core only, not JetStream.

When the schema, NATS subject selection, retention policy, or export behaviour changes, update this file and the relevant documentation in the same change. Every change must include a consistency check of this file; if it is not a true reflection of current behaviour, correct it in the same change. Documentation must remain current, use formal British English, and be written for readers with an engineering degree or equivalent technical experience.

Where SI units are used, place a space between the numerical value and the unit symbol, for example `5 m`, `12 V`, and `20 °C`. Use the degree symbol `°` by preference for angles.

The verbose portable scripting standard applies equally to Windows batch/PowerShell scripts and POSIX shell scripts on macOS, Linux, and Raspberry Pi.
