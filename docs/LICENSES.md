# Licensing map

This repository contains project-authored software, configuration, documentation, and UI/media assets. The licences below do not replace third-party licences.

| Project material | Licence | Licence text |
|---|---|---|
| `src/rov_cockpit/`, `configs/`, `scripts/`, and project-authored code | PolyForm Noncommercial 1.0.0 | [`LICENSE-POLYFORM-NonCommercial-1.0.0.txt`](LICENSE-POLYFORM-NonCommercial-1.0.0.txt) |
| Project-authored documentation, operating instructions, diagrams, and other copyrightable written or visual material | CC BY-NC-SA 4.0 | [`LICENSE-CC-BY-NC-SA-4.0.txt`](LICENSE-CC-BY-NC-SA-4.0.txt) |

## Attribution and third-party material

Retain copyright and licence notices for third-party material. In particular, `src/rov_cockpit/static/` contains bundled libraries and assets with their own licences. Those notices remain applicable and are not relicensed by this project.

Where a directory contains imported or historical material, inspect its README, source headers, or licence notice before modifying or redistributing it. If project material and third-party material are combined, keep the applicable notices together and do not imply that the third-party material is covered by the project licence.

This file is a project-maintenance guide, not legal advice. When distributing a combined product, review the complete licence obligations for every included component.

## Currently bundled third-party components

The following third-party components are currently shipped by the Cockpit or
included in its frontend build. Their copyright and licence notices must be
retained when the Cockpit is copied or distributed.

| Component | Location/use | Licence / notice |
|---|---|---|
| Vue 3 | `package.json`; committed browser runtime at `src/rov_cockpit/static/dist/vendor/vue.runtime.esm-browser.prod.js` | MIT; [Vue licence](https://github.com/vuejs/core/blob/main/LICENSE) |
| Pico CSS 2.1.1 | `src/rov_cockpit/static/css/pico.css`; npm dependency `@picocss/pico` | MIT; the bundled file retains its upstream notice |
| Font Awesome Free 7 | `src/rov_cockpit/static/css/all.css` and `webfonts/` | Icons: CC BY 4.0; fonts: SIL OFL 1.1; code: MIT. See the notice at the top of `all.css` and [Font Awesome licensing](https://fontawesome.com/license/free) |
| Leaflet | `src/rov_cockpit/static/js/leaflet.js` and `css/leaflet.css` | BSD-2-Clause; retain the upstream notice |
| jQuery | `src/rov_cockpit/static/js/jquery.js` | MIT |
| jQuery Flight Indicators | `src/rov_cockpit/static/js/jquery.flightindicators.js` and `css/flightindicators.css` | GPL-3.0; the upstream notice is retained in `flightindicators.css` |
| Weather Icons | `src/rov_cockpit/static/css/weather-icons*.css` and `font/` | SIL OFL 1.1; retain the upstream font and CSS notices |

The npm lockfile records licences for the complete dependency tree, including
transitive Vue and TypeScript build dependencies. It is not a substitute for
this human-readable register.

## Deployment-installed third-party components

The canonical Raspberry Pi provisioner installs the following tools for the
normal robot runtime user's interactive environment. They are not bundled in
this repository; the target operating system's package manager or Git clone
retains their applicable notices.

| Component | Deployment use | Licence / notice |
|---|---|---|
| Oh My Zsh | Installed from its upstream Git repository to provide the `clean` Zsh theme | MIT; [Oh My Zsh licence](https://github.com/ohmyzsh/ohmyzsh/blob/master/LICENSE) |
| HyFetch | Installed from the Debian package repository and run only for interactive Zsh logins | MIT; [HyFetch licence](https://github.com/hykilpikonna/hyfetch/blob/master/LICENSE.md) |
