# A hands-off first boot for a Raspberry Pi robot

One of the nicest things about a Raspberry Pi is that it is small enough to
put inside a robot, but that also makes the first setup slightly awkward. A
monitor, keyboard and network cable are not always convenient accessories when
the computer is eventually going to live inside a K9 or an ROV.

I wanted a newly written SD card to be as close as possible to this:

```text
Write the card → put it in the robot → apply power → wait
```

The good news is that this does not require building a Raspberry Pi operating
system from scratch. Current Raspberry Pi OS images use `cloud-init` for
first-boot configuration, and Raspberry Pi Imager writes the relevant
configuration files to the card's visible boot partition. That gives us a
convenient place to add the actions we want the Pi to perform on its first
start.

## What Raspberry Pi Imager does already

Raspberry Pi Imager can prepare the ordinary details needed for a headless
installation:

- hostname;
- timezone and keyboard layout;
- username and password;
- Wi-Fi credentials;
- SSH access; and
- Raspberry Pi Connect, where supported.

These settings are useful because they allow the Pi to join the network and
accept a remote connection without showing the first-run configuration wizard.
Raspberry Pi recommends applying these settings before the first boot in its
[installation documentation](https://www.raspberrypi.com/documentation/installation/installation/services/configuration.html).

That customisation screen is not, however, a general-purpose script runner. It
does not mean that any arbitrary `first_boot.sh` file can simply be handed to
Imager and automatically installed as a Linux service.

## The small extra step: edit `user-data`

With a recent Raspberry Pi OS image, Imager creates a few files on the first
FAT32 partition, usually shown in macOS as `bootfs` or `boot`. One of these
files is called `user-data`.

After Imager has finished writing the SD card on a Mac:

1. Eject and reinsert the card so the boot partition appears in Finder.
2. Open the existing `user-data` file.
3. Add the first-boot instructions.
4. Safely eject the card.
5. Insert it into the Pi and apply power.

Raspberry Pi describes this workflow in its article on
[cloud-init on Raspberry Pi OS](https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/),
including the fact that the generated `user-data` and `network-config` files
can be edited after the image has been written.

The top of the file must contain:

```yaml
#cloud-config
```

Without that header, cloud-init will not recognise the file as a cloud-config
file.

## What the first-boot instructions can do

Cloud-init can perform the normal setup work as well as more project-specific
tasks. For example, it can:

- install Debian packages;
- create directories and configuration files;
- install SSH keys;
- enable Raspberry Pi hardware interfaces;
- retrieve a project from GitHub;
- run a provisioning script; and
- create a marker showing that setup completed successfully.

For a CuttleOS robot, the sequence could look like this:

```text
Raspberry Pi Imager
        ↓
Wi-Fi, user and SSH are configured
        ↓
cloud-init starts on first boot
        ↓
the CuttleOS repository is retrieved
        ↓
the robot profile is selected
        ↓
the CuttleOS provisioner runs
        ↓
the Pi installs the correct services and dependencies
```

For example, a K9 deployment would select `ROBOT_PROFILE=k9`. The existing
CuttleOS provisioner then installs the shared ALSA tools and K9's speech
dependencies, including `espeak-ng` and `sox`.

## Why use a one-shot service?

The actual provisioning work is better kept in a small `systemd` service than
left as an untracked command in a cloud-init file. A one-shot service gives us
a clear lifecycle:

1. wait until networking is available;
2. run the provisioning script as `root`;
3. write a completion marker on success;
4. disable or skip itself on later boots; and
5. leave a log behind if something goes wrong.

This makes a failed installation recoverable. If a robot is moved out of Wi-Fi
range during its first boot, for example, the failure can be inspected over
SSH and the service can be run again once the network is available.

The service should be idempotent: running it twice should not duplicate
configuration, overwrite local secrets unexpectedly, or start a second copy of
the robot services.

## The practical CuttleOS arrangement

The clean project layout is likely to be:

```text
scripts/prepare_first_boot.sh
scripts/first_boot_provision.sh
configs/cuttleos-first-boot.service
```

The wrapper performs the first-boot-specific work and then calls the
existing `scripts/0_provision_raspberry_pi.sh`. The existing provisioner remains
remain the single source of truth for packages, Python environments, systemd
units, Nginx, NATS, Motion and robot-profile dependencies.

The wrapper receives or defines only the values that vary for a particular
robot, such as:

```text
ROBOT_PROFILE=k9
ROBOT_REPO_URL=https://github.com/PhilipMcGaw/robot-CuttleOS.git
```

That keeps the deployment logic in the repository instead of creating a second
parallel installation process.

## Do not bake secrets into a general image

There is one important boundary. A reusable SD-card image or a public
`user-data` example should not contain real:

- Wi-Fi passwords;
- NATS credentials;
- private SSH keys; or
- other robot-specific secrets.

Those values can be supplied while creating the card, retrieved from a
protected private location during first boot, or entered through a separate
deployment step. A script that is convenient to share is not a safe place for
credentials that grant access to a real robot.

## Preparing a card from macOS

CuttleOS now includes a macOS helper for the final preparation step. First use
Raspberry Pi Imager to write a current Raspberry Pi OS Lite image and configure
the hostname, user, Wi-Fi and SSH access. Then eject and reinsert the card so
its `bootfs` volume appears in Finder.

From a checkout of CuttleOS on the Mac, run:

```zsh
chmod +x scripts/prepare_first_boot.sh
scripts/prepare_first_boot.sh /Volumes/bootfs \
  --user philip \
  --profile k9 \
  --config-dir ~/robot-deployment/k9
```

The private configuration directory must contain `nats.env`, `network.env` and
`network.secrets.env`. The helper embeds the first-boot script, its systemd
unit, the selected profile and those configuration files into cloud-init's
`user-data`. It preserves the customisation that Imager already wrote by using
a cloud-config archive.

If `--config-dir` is omitted, the card is still prepared, but provisioning stops
safely on first boot until the private deployment configuration is supplied.
That is useful for testing the boot mechanism, but it is not a complete
hands-off deployment.
## Do I need a custom image?

Not for the first version. The recommended approach is:

1. choose Raspberry Pi OS Lite in Imager;
2. use Imager's customisation settings for the basic headless setup;
3. edit the generated `user-data` file on the boot partition;
4. boot the Pi; and
5. let the one-shot CuttleOS service complete the installation.

A custom image becomes worthwhile when the same prepared operating system will
be written to many robots, when the repository should already be present, or
when Imager should offer CuttleOS as a formally integrated custom operating
system. Raspberry Pi documents the requirements for custom images, including
the `systemd` and `cloud-init` integration modes, in
[How to add your own images to Imager](https://www.raspberrypi.com/news/how-to-add-your-own-images-to-imager/).

For a small fleet, `scripts/prepare_first_boot.sh` removes the remaining manual edit. It updates `user-data` after Imager has written the card, asks which robot profile is being installed, and copies in the appropriate first-boot configuration. That gives us repeatability without introducing a full operating-system build pipeline.

The result is not quite magic—the card still has to be written and placed in
the robot—but everything after power-on can be unattended, observable and
repeatable.
