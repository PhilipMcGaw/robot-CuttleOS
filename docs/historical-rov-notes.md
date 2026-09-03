# Historical ROV notes

This document preserves historical ROV research and project notes for reference.
It is not an active hardware, software, NATS or safety contract.

The topic names, serial identifiers, pin assignments, device paths, component
choices and scaling conventions below may be obsolete or unverified. They must
not be copied into Cockpit, Control or robot profiles without review, profile
mapping and physical validation. Current implementation and commissioning
guidance is maintained in the active documentation under `docs/`.

## Historical notes

<https://38-3d.co.uk/blogs/blog/communicating-with-an-arduino-using-a-raspberry-pi>

On a Raspberry Pi, older experiments used the following discovery and serial
commands:

```bash
cd /dev/serial/by-id
lsusb

stty -F /dev/ttyUSB0 115200
cat /dev/ttyUSB0
```

Example devices recorded at the time were:

```text
Bus 001 Device 009: ID 1a86:7523 QinHeng Electronics CH340 serial converter -- ../../ttyUSB0 [115200] -- Light
Bus 001 Device 008: ID 2341:0043 Arduino SA Uno R3 (CDC ACM) -- ../../ttyACM0 [115200] -- AHRS
```

These device names and paths are examples only. A deployed Pi must discover
its actual devices, preferably using stable `/dev/serial/by-id/` names.

### Historical shopping list

- U01 Underwater Thruster with 45A Bi-Directional ESC, 12V–16V, 2 kg thrust, CCW — [Amazon](https://amzn.to/3L75YPU) — approximately £40 each at the time.
- U01 Underwater Thruster with 45A Bi-Directional ESC, 12V–16V, 2 kg thrust, CW — [Amazon](https://amzn.to/4oDKNU7) — approximately £40 each at the time.
- [1.27-pitch headers](https://www.ebay.co.uk/itm/353845928953?var=623218464025&_ul=GB&toolid=10001&customid=eb%3Ag%3Avms%3Aeb%3Ap%3A353845928953-623218464066%3B)

These links are retained as historical research only. Availability, price,
specification and suitability must be checked again before purchasing.

### Historical research links

- Raspberry Pi camera MJPG: <https://github.com/jacksonliam/mjpg-streamer>
- Arribada Initiative — [three years in Antarctica with Penguin Watch](https://blog.voltaicsystems.com/arribada-initiative-three-years-in-antarctica-with-penguin-watch/)
- [Arribada time-lapse monitoring](https://arribada.org/2021/12/16/three-years-in-antarctica-affordable-and-durable-time-lapse-monitoring/)
- [Arribada](https://arribada.org/working-for-arribada/)
- [WildLabs camera-trapping discussion](https://wildlabs.net/en/discussion/camera-trappin-hedgehogs-woodlands)
- [WildLabs habitat-box monitoring discussion](https://wildlabs.net/discussion/habitat-box-monitoring)
- [WildLabs LoRa sensor-network discussion](https://wildlabs.net/discussion/using-lora-sensor-network-recommendations)
- [WildLabs mesh camera-trap discussion](https://wildlabs.net/discussion/mesh-camera-trap-network)
- [Arribada — building a better camera trap](https://arribada.org/2019/03/11/building-a-better-camera-trap/)
- [Jana-Marie Kitspace](https://github.com/Jana-Marie/kitspace)
- [Jana-Marie awesome-electronics](https://github.com/Jana-Marie/awesome-electronics)
- [Southern Fried Science pressure-vessel project](https://www.southernfriedscience.com/i-built-a-diy-hardware-store-pressure-vessel-to-test-ocean-science-hardware-from-the-comfort-of-my-shed/)
- [OpenCTD](https://github.com/OceanographyforEveryone/OpenCTD/tree/main)
- [Oceanography for Everyone](https://oceanographyforeveryone.com/)
- [OpenCTD construction and operation PDF](https://oceanographyforeveryone.com/wp-content/uploads/2025/06/OpenCTD_ConstructionOperation_small.pdf)
- [OpenROV research](https://irvlab.cs.umn.edu/openrov)
- [OpenROV hardware reference](https://www.researchgate.net/figure/OpenROV-28-with-added-sensors-IMU-compass-depth-modules-water-quality-electronics-and_fig1_345358236)
- [OpenROV discussion](https://discuss.bluerobotics.com/t/openrov-v2-7-with-br-compatible-kit/41/9)

