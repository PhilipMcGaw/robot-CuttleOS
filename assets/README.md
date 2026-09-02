# Robot assets

This directory contains version-controlled assets that belong to the robot
software rather than runtime-generated media.

Shared assets live under `common/`. Robot-specific assets live under
`robots/<profile_id>/`, grouped by type:

```text
assets/
├── common/
│   ├── audio/
│   ├── icons/
│   └── images/
└── robots/
    └── <profile_id>/
        ├── animations/
        ├── audio/
        ├── images/
        ├── models/
        ├── tools/
        └── ui/
```

Keep runtime-generated captures and recordings under `media/`, not here.
Profile configuration should refer to logical asset IDs and paths relative to
the relevant robot asset directory. Robot-specific executable helpers belong under the relevant `tools/` directory.
Control-owned assets must not be served
by Cockpit; Cockpit-owned presentation assets may be copied into its static
bundle during a build.
