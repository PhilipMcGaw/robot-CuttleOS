# Introducing CuttleOS: the operating system behind my ROV cockpit

I have been building an underwater robot for a while now, and one of the
things that has become increasingly clear is that the robot itself is only
part of the problem.

There is the camera, the lights, the motors and the sensors. Then there is the
less visible work of connecting those things together, moving telemetry across
the network, recording useful data, presenting a live view to the operator and
making sure the whole system can be installed again when the inevitable
experiment goes wrong.

That software layer is becoming CuttleOS.

You can see the current cockpit demo here:

[Open the CuttleOS ROV cockpit demo](https://cuttleos.philipmcgaw.com/)

## What is CuttleOS?

CuttleOS is a small, profile-driven robot control system for Raspberry Pi-based
robots. It is part of the wider SquidLink, CuttleOS and NautiPi set of projects,
but CuttleOS is the part that lives on the robot and ties the hardware-facing
services together.

The first target is my ROV: a remotely operated underwater vehicle with a
camera, lights, sensors and a surface control station. The architecture is
being designed so that the same foundations can also support K9 and other
robots in the future.

The name comes from “cuttlefish” and “OS”. It seemed a suitable combination of
something clever, adaptable and slightly alien with the very practical job of
running a small robot.

## The cockpit

The most visible part of CuttleOS is the browser-based Robot Cockpit. It is the
interface I use to bring together the things I need while operating the ROV:

- a live camera view;
- telemetry from the robot;
- depth, heading, pitch and roll instruments;
- water temperature and battery information;
- camera and light status;
- a map and supporting data views; and
- recorded stills, video and sensor data.

The cockpit is intended to feel more like an instrument panel than a generic
dashboard. The live video should remain the most important thing on the
screen, with the instruments providing context without hiding the view.

The current interface uses a transparent HUD over the video. It includes an
attitude display, pitch ladders, a depth scale and a graduated heading tape.
The design is still evolving, but the general direction is now clear: compact,
readable and useful when there is a lot happening underwater.

## A few separate services, one robot

CuttleOS is organised as a monorepo because the parts need to change together.
The Cockpit provides the browser interface and API. Control deals with the
hardware-facing behaviour. Datalogger records telemetry to CSV for later
analysis.

NATS provides the messaging layer between those services. This keeps the
browser away from the hardware and means that a camera page, a telemetry
display and a logger do not each need to know how the physical devices work.

That separation is useful while developing the ROV. I can work on the cockpit
without changing motor-control code, test the telemetry display with simulated
values, and record the same style of data that the real robot will eventually
produce.

It also leaves room for the system to grow. A robot profile describes the
capabilities and identity of the target robot, rather than forcing every robot
to pretend to have the same collection of sensors and controls.

## The Raspberry Pi matters

The ROV is intended to run on a Raspberry Pi, which makes deployment part of
the project rather than an afterthought. CuttleOS has a Raspberry Pi
provisioning path that installs the services, creates the Python environments,
configures Nginx, Motion, NATS and the network, and renders the configuration
for the selected robot profile.

I am also working towards a first-boot installation. The idea is to write a
fresh Raspberry Pi OS Lite card with Raspberry Pi Imager, configure the basic
network and SSH details, and then let the Pi complete the CuttleOS setup by
itself when it first powers on.

That is particularly useful for a robot, where connecting a monitor and
keyboard is not always convenient. It should also make it easier to prepare a
replacement computer without relying on a long list of commands remembered
from the previous installation.

## This is still a working project

The demo is not a claim that the ROV is finished. Some pieces are real, some
are simulated, and some are deliberately still placeholders. The application
can present telemetry and video, but physical hardware validation, reliable
underwater networking and complete control-path testing are separate problems
that need to be solved carefully.

That distinction is important with robots. A control button appearing in a
browser is not the same thing as having a safe, tested control system behind
it. CuttleOS keeps that boundary explicit while the rest of the system is
being developed.

The roadmap includes better hardware validation, profile-driven deployment,
audio support, USB microphone capture and eventually live audio streaming.
There is plenty left to do, but having the cockpit, services and deployment
process in one place makes the next steps much easier to see.

For now, the best way to see where it has got to is the live static demo:

[cuttleos.philipmcgaw.com](https://cuttleos.philipmcgaw.com/)

It is a small window into the software that I hope will eventually make the
underwater hardware easier to operate, test and understand.
