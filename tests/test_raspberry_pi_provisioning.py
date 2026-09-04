"""Static deployment-contract checks for the co-installed Raspberry Pi services."""

from pathlib import Path
import shutil
import subprocess


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONTROL_ROOT = PROJECT_ROOT / "control"
DATALOGGER_ROOT = PROJECT_ROOT / "datalogger"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_provisioner_installs_the_required_platform_contract() -> None:
    provisioner = read(PROJECT_ROOT / "scripts" / "0_provision_rpi.sh")

    for required in (
        "network-manager",
        "dnsmasq-base",
        "avahi-daemon",
        "samba",
        "espeak-ng",
        "sox",
        "alsa-utils",
        "if [[ \"$ROBOT_PROFILE\" == \"k9\" ]]",
        "install_nats_configuration",
        "render_template \"$PROJECT_ROOT/configs/cockpit.service\"",
        'render_template "$DATALOGGER_ROOT/configs/datalogger.service"',
        'render_template "$CONTROL_ROOT/configs/python.service"',
        "NETWORK_CONFIG=\"$NETWORK_CONFIG_FILE\"",
        "NETWORK_SECRETS=\"$NETWORK_SECRETS_FILE\"",
        "NETWORK_SECRETS_MODE",
        "NATS_URL=nats://%s:%s@127.0.0.1:4222",
    ):
        assert required in provisioner


def test_provisioner_uses_the_cuttleos_monorepo_layout() -> None:
    provisioner = read(PROJECT_ROOT / "scripts" / "0_provision_rpi.sh")

    assert 'CONTROL_ROOT="${CONTROL_ROOT:-$PROJECT_ROOT/control}"' in provisioner
    assert 'DATALOGGER_ROOT="${DATALOGGER_ROOT:-$PROJECT_ROOT/datalogger}"' in provisioner
    assert CONTROL_ROOT.is_dir()
    assert DATALOGGER_ROOT.is_dir()


def test_service_templates_are_portable_and_use_the_restricted_nats_environment() -> None:
    cockpit_unit = read(PROJECT_ROOT / "configs" / "cockpit.service")
    control_unit = read(CONTROL_ROOT / "configs" / "python.service")
    datalogger_unit = read(DATALOGGER_ROOT / "configs" / "datalogger.service")

    assert "@COCKPIT_ROOT@" in cockpit_unit
    assert 'ExecStart=/bin/bash "@COCKPIT_ROOT@/cockpit/run.sh"' in cockpit_unit
    assert "EnvironmentFile=-/etc/robot/nats.env" in cockpit_unit
    assert "EnvironmentFile=-/etc/robot/nats.env" in control_unit
    assert "EnvironmentFile=-/etc/robot/nats.env" in datalogger_unit
    assert "@PROJECT_ROOT@/data/csv" in datalogger_unit
    assert "/home/pi/" not in cockpit_unit
    assert "/home/pi/" not in control_unit
    assert "/home/pi/" not in datalogger_unit


def test_provisioner_configures_runtime_shell_and_records_sudo_policy_as_an_open_security_item() -> None:
    provisioner = read(PROJECT_ROOT / "scripts" / "0_provision_rpi.sh")

    for required in (
        "git zsh hyfetch",
        "configure_interactive_shell",
        'ZSH_THEME=\"clean\"',
        "[[ -o interactive ]]",
        "usermod -s",
        "visudo -cf",
        "NOPASSWD:ALL",
        "/etc/sudoers.d/90-rov-runtime-",
    ):
        assert required in provisioner

    bash = shutil.which("bash")
    if bash:
        result = subprocess.run(
            [bash, "-n", str(PROJECT_ROOT / "scripts" / "0_provision_rpi.sh")],
            text=True,
            capture_output=True,
            check=False,
        )
        assert result.returncode == 0, result.stderr


def test_network_deployment_supports_named_profiles_and_wifi_fallback() -> None:
    network_script = CONTROL_ROOT / "scripts" / "0_deploy_network.sh"
    assert network_script.exists()
    content = read(network_script)
    assert "ROBOT_PROFILE" in content
    assert "NetworkManager" in content


def test_control_runtime_launcher_derives_its_own_path() -> None:
    launcher = CONTROL_ROOT / "scripts" / "2_start_app.sh"
    assert launcher.exists()
    content = read(launcher)
    assert "PROJECT_ROOT=" in content


def test_rendered_nginx_and_motion_configuration_do_not_assume_a_checkout_path() -> None:
    nginx_template = read(PROJECT_ROOT / "configs" / "nginx.conf")
    nginx_installer = read(PROJECT_ROOT / "scripts" / "3_configure_nginx.sh")
    motion_template = read(PROJECT_ROOT / "configs" / "motion.conf")

    assert "@COCKPIT_ROOT@" in nginx_template
    assert 'alias "@COCKPIT_ROOT@/cockpit/src/rov_cockpit/static/";' in nginx_template
    assert "COCKPIT_ROOT_ESCAPED" in nginx_installer
    assert "@COCKPIT_ROOT@" in motion_template


def test_profile_switcher_installs_k9_dependencies_before_activation() -> None:
    switcher = read(PROJECT_ROOT / "scripts" / "switch_robot_profile.sh")

    for required in (
        'case "$TARGET_PROFILE" in',
        'k9)',
        'profile_packages=(espeak-ng sox)',
        'apt-get install -y "${profile_packages[@]}"',
        'Profile $TARGET_PROFILE was not activated.',
    ):
        assert required in switcher


def test_first_boot_files_and_macos_helper_are_noninteractive() -> None:
    helper = read(PROJECT_ROOT / "scripts" / "prepare_first_boot.sh")
    first_boot = read(PROJECT_ROOT / "scripts" / "first_boot_provision.sh")
    service = read(PROJECT_ROOT / "configs" / "cuttleos-first-boot.service")

    for required in (
        "uname -s",
        "Darwin",
        "#cloud-config-archive",
        "--config-dir",
        "network.secrets.env",
        "cuttleos-first-boot.service",
    ):
        assert required in helper
    for required in (
        "apt-get update",
        "git clone",
        "0_provision_rpi.sh",
        "first-boot-complete",
        "ROBOT_PROFILE",
        "robot-CuttleOS.git",
    ):
        assert required in first_boot
    assert "robot-Control.git" not in first_boot
    assert "robot-Datalogger.git" not in first_boot
    assert "network-online.target" in service
    assert "ConditionPathExists=!/var/lib/cuttleos/first-boot-complete" in service


def main() -> int:
    checks = (
        test_provisioner_installs_the_required_platform_contract,
        test_provisioner_uses_the_cuttleos_monorepo_layout,
        test_service_templates_are_portable_and_use_the_restricted_nats_environment,
        test_provisioner_configures_runtime_shell_and_records_sudo_policy_as_an_open_security_item,
        test_network_deployment_supports_named_profiles_and_wifi_fallback,
        test_control_runtime_launcher_derives_its_own_path,
        test_rendered_nginx_and_motion_configuration_do_not_assume_a_checkout_path,
        test_profile_switcher_installs_k9_dependencies_before_activation,
        test_first_boot_files_and_macos_helper_are_noninteractive,
    )
    for check in checks:
        check()
    print(f"[PASS] Raspberry Pi provisioning contract audit passed for {len(checks)} checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
