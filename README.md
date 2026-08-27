# robot-CuttleOS

Part of the SquidLink, CuttleOS, and NautiPi set

2. CuttleOS

    The operating system, this name combines “Cuttlefish” (a clever cephalopod) with “OS” (operating system), giving it a futuristic yet natural feel.


1. SquidLink

(For your main control software or Raspberry Pi)

    A sleek, tech-sounding-name that implies connectivity and agility—perfect for a robotics control system.


3. NautiPi

(For your secondary device or backup system)

    A nod to the “Nautilus” (the shell of a nautilus, another cephalopod relative) and “Raspberry Pi,” making it a fun and functional name.

Why These Work Together:

    Thematic Unity: All three names tie into cephalopods and technology.
    Clear Roles: Each name suggests a different component (software, PCB/OS, and device).
    Memorable: They’re short, catchy, and easy to remember.







# How to put the codebase back together

https://chatgpt.com/share/6a8d481a-08bc-83eb-b14a-adfcd44393be?ogimg=plain

> For simplicity sake after trying the multiple parts of the ROV script in different repos. I think changing the got seperaratio. To just be everything on a pi in one repo. And the HIL has its own?

Yes. I think that is a better architecture for your project at this stage, particularly after the friction you've encountered with multiple repositories.

I'd simplify it to two repositories:

```
                    ROV PROJECT
                         │
             ┌───────────┴───────────┐
             │                       │
       ROV / Pi repo              HIL / SiL repo
       "the real thing"           "the simulator"
             │                       │
             │                       │
        ┌────┴────┐             ┌────┴────┐
        │         │             │         │
     Cockpit   Control       ROS 2     Gazebo
        │         │             │         │
     Cameras    NATS          Simulated robot
        │         │
     Web UI    RS-485
        │         │
        └────┬────┘
             │
          Raspberry Pi
```


1. The Pi repository

This becomes the complete deployable ROV system.

I'd put everything required to operate the actual ROV here:

```
rov/
├── cockpit/
├── control/
├── video/
├── telemetry/
├── datalogger/
├── hardware/
├── configs/
├── scripts/
├── tests/
└── docs/
```

You don't necessarily need those exact directories — I'm illustrating the ownership boundary, rather than prescribing the implementation.

The important principle is:

    If it needs to run on the ROV, it belongs in the ROV repository.

That includes your FastAPI/Vue cockpit, NATS, camera handling, dewarping, RS-485 control, telemetry, logging, etc.

The Pi then becomes a self-contained appliance:

```                    Raspberry Pi
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
    Cockpit            NATS            Control
       │                                   │
     WebRTC                              RS-485
       │                                   │
    Cameras                             Nodes```

That's considerably easier to deploy and maintain.

----

2. The HIL/SiL repository

This is a development and simulation environment, not another implementation of the ROV.

```rov-hil/
├── ros2_ws/
├── gazebo/
├── models/
├── worlds/
├── bridges/
├── test_scenarios/
├── configs/
└── docs/```

Its job is essentially:

    Pretend to be the physical ROV and its environment.

So the HIL system can communicate with the same interfaces that the real Pi system expects.

For example:

````
                 ROV HIL / SiL
                       │
                 ROS 2 / Gazebo
                       │
                simulated hardware
                       │
                     NATS
                       │
                       ▼
                 ROV Cockpit
````

That is where your virtual motors, IMU, depth sensor, camera, etc. live.

The really important bit

I'd stop thinking of the HIL repository as a second version of the ROV software.

Instead:

ROV repo

> "This is the software that actually runs the vehicle."

HIL repo

> "This provides simulated hardware so I can test the ROV software."

That gives you a very useful boundary.

For example, your control software might receive:

```
/rov/sensors/imu
/rov/sensors/depth
/rov/sensors/battery
```

It shouldn't care whether those messages came from:

```
Physical IMU
     ↓
RS-485 node
     ↓
NATS
```
or:
```
Gazebo IMU
     ↓
ROS 2
     ↓
NATS
```
That's exactly what makes the HIL useful.

----

And this makes the K9 idea easier too

This architecture doesn't prevent you eventually making the cockpit generic.

You could eventually have:

```
robot-control/
    rov/
    k9/
```

But don't build that abstraction prematurely.

I'd get:
````
ROV Pi repo
        ↓
physical ROV

ROV HIL repo
        ↓
simulated ROV
````

working cleanly first.

Then, if you decide the cockpit should operate K9:

                    Generic Cockpit
                           │
                         NATS
                           │
                 ┌─────────┴─────────┐
                 │                   │
             ROV Control          K9 Control
                 │                   │
              ROV HW               K9 HW

You can introduce that abstraction where it actually becomes useful, rather than creating a complicated multi-repository architecture now.

So yes — I'd change the plan.

Two repositories:

rov — everything required to operate and develop the real ROV, ultimately deployed to the Pi.
rov-hil — ROS 2/Gazebo/HIL/SiL environment used to simulate the ROV and test the rov software.

And I'd keep NATS as the interface between them.

That is a much cleaner boundary than the several-repository arrangement we were experimenting with.










> What is the best way to recombine the software that runs on the pi?

Yes. I would recombine it as one application repository, but not as one giant application.

The distinction is important:

One repository ≠ one process.

For your Pi, I'd use a monorepo containing several small services, with NATS remaining the internal message bus.

Recommended structure
rov/
├── apps/
│   ├── cockpit/
│   ├── control/
│   ├── telemetry/
│   ├── video/
│   └── datalogger/
│
├── packages/
│   ├── messages/
│   ├── robot/
│   ├── hardware/
│   └── common/
│
├── frontend/
│   └── cockpit/
│
├── configs/
│   ├── robot.json
│   └── ...
│
├── tests/
│   ├── integration/
│   └── system/
│
├── scripts/
│
├── docs/
│
├── pyproject.toml
├── package.json
└── README.md

The exact names can change, but this is the architectural shape I'd recommend.

What goes where
apps/cockpit

Your existing FastAPI + Vue application.

It owns:

browser UI
authentication
WebSocket telemetry
instrument rendering
camera selection
operator controls
configuration UI

It doesn't directly control RS-485 hardware.

apps/control

This is the actual vehicle-control layer.

For example:

Joystick
   ↓
Cockpit
   ↓
NATS
   ↓
Control
   ↓
RS-485
   ↓
Thruster nodes

It handles things such as:

command processing
control loops
thruster allocation
limits
failsafes
RS-485 communications
node discovery
watchdogs

This is probably the most important separation in the whole system.

apps/telemetry

Responsible for collecting and publishing the vehicle's state.

For example:

RS-485
   ↓
Telemetry
   ↓
NATS
   ├── Cockpit
   ├── DataLogger
   └── Diagnostics

This keeps the cockpit from becoming responsible for knowing how sensors physically work.

apps/video

This is where I'd put the camera pipeline we were just discussing.

For example:

Camera
  ↓
Capture
  ↓
Dewarp
  ↓
Encode
  ↓
WebRTC
  ↓
Cockpit

The Kogeto Dot could therefore become just another supported camera source.

apps/datalogger

The Pi-side logger you previously described belongs here.

It subscribes to NATS and records things such as:

telemetry
commands
system state
faults
timestamps
potentially video metadata

Crucially, it doesn't need to be involved in the control path.

Then packages/

This is where I'd put the things that are genuinely shared.

For example:

packages/messages/

contains the definitions of messages exchanged through NATS.

Something conceptually like:

Command
Telemetry
BatteryStatus
Depth
Attitude
ThrusterCommand
Fault
CameraStatus

Then:

cockpit
control
telemetry
datalogger

can all use the same definitions.

This avoids the horrible situation where the cockpit thinks a message looks like:

{
    "depth": 12.4
}

while another application thinks it is:

{
    "depth_m": 12.4
}

You establish the interface once.

I would also keep NATS inside the Pi deployment

So operationally you end up with something like:

                    Raspberry Pi
┌──────────────────────────────────────────────┐
│                                              │
│                    NATS                      │
│                     │                        │
│       ┌─────────────┼─────────────┐          │
│       │             │             │          │
│   Cockpit       Control       Telemetry      │
│       │             │             │          │
│       │          RS-485           │          │
│       │             │             │          │
│       │          Nodes            │          │
│       │                           │          │
│     Video                     Datalogger     │
│       │                           │          │
└───────┼───────────────────────────┼──────────┘
        │                           │
     Browser                     Storage

Each process can be started/stopped independently.

The HIL repository then becomes much cleaner

Your HIL repo doesn't need copies of all of this.

Instead:

rov-hil/
└── ros2_ws/
    ├── src/
    │   ├── rov_gazebo/
    │   ├── rov_simulation/
    │   ├── rov_nats_bridge/
    │   └── ...
    │
    ├── worlds/
    ├── models/
    └── configs/

The HIL system essentially substitutes for the hardware.

                  REAL
                   │
             ┌─────▼─────┐
             │ ROV Pi    │
             │           │
             │ Control   │
             │ Telemetry │
             └─────┬─────┘
                   │
                 NATS
                   │
                Hardware


                  HIL
                   │
             ┌─────▼─────┐
             │ ROS 2     │
             │ Gazebo    │
             └─────┬─────┘
                   │
              NATS bridge
                   │
                 NATS
                   │
             ROV software

And that is the really valuable part:

The HIL system can exercise the actual ROV software, rather than a special HIL version of it.



How I would actually recombine your existing repositories

I would not simply copy all the files into one directory.

I'd do it in this order:

Create the new rov repository.
Move the existing cockpit into apps/cockpit.
Move the control software into apps/control.
Move the datalogger into apps/datalogger.
Add video as apps/video.
Identify duplicated code and move only genuinely shared code into packages/.
Establish the NATS message contracts in packages/messages/.
Make each application independently runnable.
Add one Pi-level deployment configuration that starts all services.
Only then start removing the old repositories.

That last point matters. Don't refactor everything simultaneously.

You want to preserve working functionality while changing the repository boundary.

One further recommendation

I wouldn't call the repository rov-cockpit anymore.

I'd call it something like:

rov

because the cockpit is now only one component of the vehicle software.

That also leaves you with a very natural future:

rov
├── cockpit
├── control
├── telemetry
├── video
└── datalogger

rov-hil
└── simulation

That's probably the architecture I'd settle on for your project now. It is considerably simpler than the multi-repository approach, while retaining the modularity we actually need.











> I was thinking of calling the repo Robots rather than specifically any model


Yes — robots is actually a better name if you already know you want the same software architecture to eventually support K9 as well as the ROV.

I would make that the top-level repository, and treat the individual robots as configurations/implementations within it.

Something like:

robots/
├── apps/
│   ├── cockpit/
│   ├── control/
│   ├── telemetry/
│   ├── video/
│   └── datalogger/
│
├── robots/
│   ├── rov/
│   │   ├── config/
│   │   ├── control/
│   │   └── hardware/
│   │
│   └── k9/
│       ├── config/
│       ├── control/
│       └── hardware/
│
├── packages/
│   ├── messages/
│   ├── nats/
│   ├── hardware/
│   └── common/
│
├── frontend/
├── configs/
├── tests/
├── scripts/
└── docs/

However, I would not necessarily put rov/ and k9/ in there immediately.

There's an important architectural distinction:

Generic software

Things that should work for any robot:

apps/
packages/

For example:

Cockpit
NATS
WebSocket telemetry
video
logging
authentication
configuration
generic telemetry
generic command handling
Robot-specific behaviour

Things that genuinely depend on the vehicle:

robots/
├── rov/
└── k9/

For example, the ROV might have:

depth
heading
thruster allocation
buoyancy
underwater cameras

while K9 might eventually have:

wheel/leg control
head movement
arm control
different camera arrangements
There's an even cleaner possibility

Given what you've already built, I'd consider making the robot definition primarily configuration, rather than separate code.

For example:

configs/
├── robots/
│   ├── rov.yaml
│   └── k9.yaml

Then:

robot:
  id: rov
  name: ROV
  type: underwater

capabilities:
  - drive
  - depth
  - heading
  - camera
  - lights

and:

robot:
  id: k9
  name: K9
  type: ground

capabilities:
  - drive
  - camera
  - head
  - lights

The cockpit can then discover:

"I'm connected to a robot with these capabilities."

and render the appropriate UI.

That's particularly compatible with your existing robot profile concept in the cockpit.

And robots has another advantage

It gives you a very clean relationship between the two repositories:

robots/
    │
    ├── actual robot software
    │
    ├── ROV configuration
    │
    └── K9 configuration


robots-hil/
    │
    ├── ROS 2
    ├── Gazebo
    ├── simulated ROV
    └── simulated K9 (eventually)

Or, if you want the HIL repository name to match:

robots
robots-hil

I quite like that.

It communicates that the first repository is the real robot software, while the second is the environment used to test it.

One thing I would not do

I wouldn't make this:

robots/
├── rov/
│   └── entire application
└── k9/
    └── entire application

because you'd quickly end up duplicating:

cockpit
NATS
video
logging
telemetry
authentication
configuration

and then maintaining two versions.

Instead:

robots/
├── common software
├── robot-specific software
└── robot configurations

That gives you one cockpit, one communications architecture, one video system, etc., while allowing the actual vehicles to differ where they need to.

So, yes: I'd be happy with robots as the repository name, and I think it's a better long-term choice than rov.

Yaml vs json vs something else?

For the robots project, I would choose YAML for human-edited configuration, JSON for machine/API data, and a typed schema for the actual contract.

My recommendation
Use	Format	Why
Robot profiles	YAML	Easy for humans to read/edit
Deployment/configuration	YAML	Good for structured configuration
NATS messages	JSON initially	Easy to inspect/debug
REST/WebSocket data	JSON	Natural fit for web tooling
Persistent telemetry/logs	SQLite	Don't turn configuration files into a database
Configuration validation	JSON Schema / Pydantic	Gives us an actual contract

For example, your robot profile could be:

id: rov
name: ROV
type: underwater

capabilities:
  - drive
  - depth
  - heading
  - attitude
  - camera
  - lights

interfaces:
  control: nats
  hardware: rs485

cameras:
  - id: forward
    type: usb
  - id: panoramic
    type: kogeto
    dewarp: true

That is substantially nicer to maintain than equivalent JSON.

But I would not let YAML define your software interface

This is the important distinction.

I'd have something like:

robot.yaml
     │
     ▼
Pydantic model
     │
     ├── validates configuration
     ├── provides typed objects
     └── exposes configuration to applications

So the application doesn't do this everywhere:

config["capabilities"][3]

It does something more like:

robot.capabilities

That gives you compile-/run-time structure without sacrificing the convenience of YAML.

For NATS

I'd initially use JSON messages:

{
  "robot_id": "rov",
  "timestamp": "2026-08-22T22:00:00Z",
  "depth_m": 12.4,
  "heading_deg": 183.2
}

But there's an important caveat.

Don't make JSON the permanent wire protocol if performance becomes important.

Because you're eventually talking about high-rate telemetry and control, we could move the NATS payloads to something schema-based such as Protocol Buffers later:

Cockpit ─┐
Control ─┼── NATS ── protobuf
Video ───┤
Logger ──┘

That gives you:

explicit types
versioned schemas
smaller messages
faster serialisation
language independence
much less ambiguity about units and field types

For your current stage, however, JSON is much easier to debug. I'd rather get the architecture right first than introduce protobuf prematurely.

So I'd settle on
robots/
│
├── configs/
│   └── robots/
│       ├── rov.yaml
│       └── k9.yaml
│
├── packages/
│   └── messages/
│       └── schemas/
│
├── apps/
│   ├── cockpit/
│   ├── control/
│   ├── telemetry/
│   ├── video/
│   └── datalogger/
│
└── ...

YAML = configuration.

JSON = human-readable data exchange.

Pydantic/schema = the contract.

SQLite = persistent structured data.

Protobuf = a future option for high-rate NATS traffic.

For the robots project, I think that's a very good balance between engineering discipline and not over-engineering the system before we need to.

What about toml?

Yes — TOML is a serious contender, and for your robots repository I would actually use TOML in some places.

The key is that YAML, TOML, and JSON have different strengths.

For your project
Requirement	My choice
Python project metadata	TOML
Application configuration	TOML or YAML
Robot profile	TOML
NATS message payload	JSON initially
API/WebSocket payload	JSON
Persistent data	SQLite
Typed contract	Pydantic/schema

The big advantage of TOML is that it sits nicely between JSON and YAML: human-editable, structured, but considerably less ambiguous than YAML.

For example, your ROV configuration could be:

[robot]
id = "rov"
name = "ROV"
type = "underwater"

[capabilities]
drive = true
depth = true
heading = true
attitude = true
camera = true
lights = true

[interfaces]
control = "nats"
hardware = "rs485"

[[cameras]]
id = "forward"
type = "usb"

[[cameras]]
id = "panoramic"
type = "kogeto"
dewarp = true

I actually prefer that to the YAML equivalent for engineering configuration.

Why I'd favour TOML for robots

You're an engineer, and this project is going to contain a lot of things like:

RS-485 addresses
baud rates
timeouts
control-loop frequencies
limits
camera parameters
NATS subjects
ports
GPIO assignments
units
hardware identifiers

TOML makes those explicit without YAML's more surprising parsing behaviour.

For example:

[rs485]
port = "/dev/ttyUSB0"
baudrate = 115200
timeout_ms = 20

[control]
loop_rate_hz = 100
command_timeout_ms = 250

[limits]
max_depth_m = 100.0
max_horizontal_speed_m_s = 1.5

That's very readable.

TOML also fits Python particularly well

Your Python applications can use Python's built-in tomllib for reading TOML, so you don't need another dependency just to parse the configuration.

And your existing pyproject.toml already puts TOML in the Python ecosystem you're using.

One caveat

TOML isn't particularly good for deeply hierarchical, highly dynamic data.

I wouldn't try to make NATS telemetry look like:

[telemetry]
...

TOML is a configuration format, not a streaming data format.

Likewise, if you eventually have complex robot descriptions with hundreds of nested parameters, YAML may become more convenient.

Therefore I'd revise my previous recommendation slightly

For robots, I'd go with:

TOML
 ├── robot configuration
 ├── hardware configuration
 ├── application configuration
 └── deployment configuration

JSON
 ├── NATS messages initially
 ├── WebSocket messages
 └── REST API

SQLite
 └── persistent telemetry / logs

Pydantic
 └── validates configuration and defines application models

And I'd make TOML the default configuration format unless we encounter a specific configuration that YAML handles substantially better.

In fact, given the direction we're taking with the project, I'd choose TOML over YAML for the robot profiles we were discussing.


