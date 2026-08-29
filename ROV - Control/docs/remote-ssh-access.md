# Remote SSH access for robot verification

This guide defines a repeatable, least-privilege way to give an active Codex
task remote shell access to a robot Raspberry Pi. It supports diagnosis and
evidence gathering; it does not authorise unattended access, service changes,
or hardware actuation.

## Status and scope

The procedure is documented and has not yet been applied or bench-tested on a
robot. Each robot MUST use its own hostname and SSH key. The preferred local
names are `rov.local`, `k9.local`, and `piwars.local`, as advertised by Avahi.
Do not depend on a static IP address when a hostname is available.

Use this access only from a trusted operator computer running Codex. An active
task may run read-only checks when requested. Restarting a service, changing
network configuration, changing a profile, writing to hardware, or making any
other state-changing action still requires explicit operator authorisation.

## Security model

- Create a dedicated `codex` account on each robot. Do not share the regular
  operator account or its SSH key.
- Use a separate Ed25519 key pair for every robot. The private key MUST remain
  on the trusted operator computer, MUST have restrictive permissions, and
  MUST NOT be committed to Git, copied to SMB, or pasted into chat.
- Disable password and keyboard-interactive login for the `codex` account.
  Do not disable password login globally unless that is an intentional
  separately reviewed robot policy.
- Verify the robot's SSH host-key fingerprint by an independent local-console
  or trusted-session check before accepting it on the operator computer.
- Do not expose SSH directly to the public Internet. For off-site access, use
  a separately configured private network such as WireGuard or Tailscale; do
  not create a router port-forward for TCP port `22`.
- Begin with no `sudo` authority. If a later diagnostic needs elevation, add a
  narrowly scoped, reviewed command wrapper rather than granting unrestricted
  passwordless `sudo`.

## One-time setup

### 1. Enable SSH on the robot

On the Raspberry Pi, using a directly attached console or a separately trusted
administrator session, install and enable the OpenSSH server if it is not
already available:

```zsh
sudo apt update
sudo apt install openssh-server
sudo systemctl enable --now ssh
sudo systemctl status ssh --no-pager
```

Record the host-key fingerprint from the Pi and compare it with the first
connection prompt on the operator computer:

```zsh
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

### 2. Create a key on the Codex operator computer

Create a unique key for each robot. The following example is for K9:

```zsh
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/codex_robot_k9 -C "codex@k9"
```

Keep `~/.ssh/codex_robot_k9` private. The public file ending in `.pub` is the
only part that is installed on the robot.

### 3. Create and configure the robot account

On the Pi, create an account without a usable password and install the public
key from the preceding step. Paste the *contents* of
`~/.ssh/codex_robot_k9.pub` into the `authorized_keys` file; do not paste the
private key.

```zsh
sudo adduser --disabled-password --gecos '' codex
sudo install -d -m 700 -o codex -g codex /home/codex/.ssh
sudoedit /home/codex/.ssh/authorized_keys
sudo chown codex:codex /home/codex/.ssh/authorized_keys
sudo chmod 600 /home/codex/.ssh/authorized_keys
```

Create a user-specific SSH policy in
`/etc/ssh/sshd_config.d/60-codex-robot.conf`:

```text
Match User codex
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AuthenticationMethods publickey
    AllowTcpForwarding no
    PermitTunnel no
    X11Forwarding no
```

Validate before reload so a configuration error cannot silently break remote
access:

```zsh
sudo sshd -t
sudo systemctl reload ssh
```

### 4. Add an operator-computer SSH alias

On the computer running Codex, add the following to `~/.ssh/config`:

```text
Host k9
    HostName k9.local
    User codex
    IdentityFile ~/.ssh/codex_robot_k9
    IdentitiesOnly yes
```

Use a parallel entry and unique key for each other robot, such as `rov` and
`piwars`. The alias avoids confusing one robot with another and makes all
automated commands explicit about their target.

## Acceptance checks

From the operator computer, after checking the host-key fingerprint, connect
and run only read-only checks:

```zsh
ssh k9 'hostnamectl --static; uptime; systemctl is-active nats-server python cockpit datalogger nginx; nmcli device status'
```

The output MUST identify the expected hostname. A non-`active` service result,
an unexpected hostname, or a changed host-key fingerprint is a diagnostic
finding, not a reason to restart or reconfigure the robot automatically.

For a profile and broker check on the Pi, use the installed paths and avoid
printing NATS credentials:

```zsh
ssh k9 'test -r /etc/robot/profile.json && python3 -m json.tool /etc/robot/profile.json >/dev/null && echo profile-valid; ss -ltn | grep -F "127.0.0.1:4222"'
```

These checks do not prove physical hardware operation. I2C scanning, GPIO
access, servo tests, motor tests, camera configuration, and service restarts
are separate, reviewed actions and MUST follow the relevant safety procedure.

## Optional future elevation

If routine diagnostics later require privileged data, add a root-owned,
fixed-purpose wrapper under `/usr/local/sbin/` and grant `codex` permission to
run only that wrapper using a file in `/etc/sudoers.d/`. Validate every sudoers
change with `visudo -cf`. Do not use a broad rule such as
`codex ALL=(ALL) NOPASSWD: ALL`.

Any such wrapper, its permitted output, and its safety impact MUST be reviewed,
documented, and tested before it is enabled on a robot.
