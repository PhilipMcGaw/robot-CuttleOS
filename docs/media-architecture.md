# CuttleOS Media Architecture

## Purpose

This document defines the intended architecture for camera, video, audio, recording, and media presentation across CuttleOS robots.

The design applies to K9 and ROV where the required hardware is available. Media capability is profile-driven; Cockpit must not assume that every robot has the same cameras, microphones, speakers, network capacity, or storage.

## Architectural separation

Media is divided into four concerns:

1. **Acquisition** — camera and microphone capture, including synchronised stereo cameras.
2. **Distribution and recording** — encoding, local recording, live transport, and storage.
3. **Presentation** — mono, side-by-side stereo, stereoscopic/VR, telemetry overlays, and operator controls.
4. **Authoritative data** — raw media, NATS telemetry, and control/event logs.

```text
Camera / microphone
        │
        ├──► Acquisition
        │       │
        │       ├──► Local recorder ──► Vehicle storage
        │       │
        │       └──► Live media ──► WebRTC ──► Operator / Quest
        │
        └──► Processing as required

NATS telemetry + control events
        │
        └──► Datalogger ──► authoritative log
                         │
                         └──► derived subtitles / overlays
```

Cockpit presents media and controls media sessions; it does not own physical camera, microphone, speaker, or storage drivers.

## Live video

WebRTC is the preferred live transport where low latency matters. This is particularly important for K9, which is expected to use a mobile-network connection rather than relying on a local Wi-Fi network.

Live streaming shall be on demand. Local recording may continue with zero viewers, but the live encoder/transport should not consume network bandwidth when nobody is viewing the stream.

The live path shall support adaptive quality. A constrained connection should be able to fall back to lower resolution, lower frame rate, or mono presentation without affecting the authoritative local recording.

Video traffic must not starve safety-critical control or telemetry traffic. Control and telemetry therefore remain logically and operationally separate from the media transport.

## Stereo video

Stereo video is a common CuttleOS capability, not a K9-only feature.

The preferred capture characteristics for remote driving are:

- synchronised left/right frames;
- global shutter where practical;
- approximately 75–80 mm baseline where the physical installation permits it;
- sufficient per-eye resolution for the intended presentation;
- stable frame timing;
- a calibration record associated with the camera pair.

The master recording should preserve native stereo. Anaglyph is a presentation/export option, not the primary storage format.

A single stereo source should be capable of supporting multiple presentation modes without recapturing or altering the master:

- mono left/right selection;
- side-by-side stereo;
- stereoscopic browser presentation;
- Meta Quest/WebXR presentation;
- future computer-vision processing.

## Audio

For K9, the microphone is an operational sensor as well as a recording source. The operator should be able to hear the environment around the robot with sufficiently low latency to support situational awareness.

The K9 microphone should also be included as an audio track in applicable saved video recordings.

K9 should provide an operator-to-robot audio path to the speaker/soundboard for interactive responses. This return path must remain separate from the hardware-control safety path.

The media architecture should permit multiple audio sources in future without making a particular ALSA device name part of the Cockpit interface contract.

## Recording

Recording is a vehicle-side function and must continue independently of the operator's browser connection.

The authoritative recording set should contain:

- native video, including both stereo views where available;
- captured audio where applicable;
- raw NATS telemetry;
- control/event logs;
- recording metadata and configuration references.

Telemetry subtitles, rendered overlays, compressed exports, and other presentation formats are derived products.

For K9, the planned dedicated 1 TB SSD is the preferred destination for video, audio, telemetry, command/control logs, stills, and diagnostics. The SD card should remain primarily responsible for the operating system and application environment.

ROV must support reduced-capability operation where dedicated high-capacity storage is unavailable.

## Time synchronisation and provenance

Video, audio, telemetry, and control events should use a common time reference. This allows an operator or developer to answer what the robot saw, heard, measured, and did at a particular instant.

Recordings should be traceable to:

- robot identity;
- active profile;
- CuttleOS/framework revision;
- profile/configuration hash;
- camera configuration;
- stereo calibration identifier;
- baseline and source identities;
- video/audio configuration;
- recording start time and timebase;
- associated telemetry/control recording identifiers.

## Telemetry presentation

Raw telemetry remains authoritative. Derived presentation may include WebVTT subtitles or a rendered telemetry overlay for an exported video.

Telemetry should not be permanently burned into the master recording merely because the Cockpit currently displays it that way. This preserves the ability to change the presentation later.

## Failure behaviour

Media failures must degrade independently of control:

- camera failure must not stop Control;
- microphone failure must not stop Control;
- storage failure must not stop Control;
- network loss must not stop local recording where possible;
- Cockpit/browser loss must not stop vehicle-side recording;
- live-stream failure must not affect the authoritative telemetry/control path.

The media service should expose health and failure state to Cockpit for operator awareness and to diagnostics for engineering investigation.

## Validation

Before a media capability is described as production-ready, validate it on the target hardware and network. In particular, measure:

- left/right frame synchronisation;
- end-to-end live-video latency;
- audio latency;
- sustained recording throughput;
- storage endurance and free-space behaviour;
- adaptive bitrate/resolution behaviour;
- recovery after camera, network, service, and storage failures;
- synchronisation between media and NATS/control logs.

Software simulation or browser demonstration is not sufficient evidence of physical or production validation.
