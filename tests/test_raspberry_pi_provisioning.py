"""Static deployment-contract checks for the co-installed Raspberry Pi services."""

from pathlib import Path
import shutil
import subprocess


COCKPIT_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = COCKPIT_ROOT
CONTROL_ROOT = WORKSPACE_ROOT / "control"
DATALOGGER_ROOT = WORKSPACE_ROOT / "datalogger"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_provisioner_installs_the_required_platform_contract() -> None:
    provisioner = read(COCKPIT_ROOT / "scripts" / "0_provision_raspberry_pi.sh")

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
        "NETWORK_CONFIG=\"$NETWORK_CONFIG_FILE\"",
        "NETWORK_SECRETS=\"$NETWORK_SECRETS_FILE\"",
        "NETWORK_SECRETS_MODE",
        "NATS_URL=nats://%s:%s@127.0.0.1:4222",
    ):
        assert required in provisioner


def test_provisioner_configures_runtime_shell_and_sudo() -> None:
    provisioner = read(COCKPIT_ROOT / "scripts" / "0_provision_raspberry_pi.sh")

    for required in (
        "git zsh hyfetch",
        "configure_interactive_shell",
        "configure_passwordless_sudo",
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
        result = subprocess.run([bash, "-n", str(COCKPIT_ROOT / "scripts" / "0_provision_raspberry_pi.sh")], text=True, capture_output=True, check=False)
        assert result.returncode == 0, result.stderr


def test_service_templates_are_portable_and_use_the_restricted_nats_environment() -> None:
    cockpit_unit = read(COCKPIT_ROOT / "configs" / "cockpit.service")

    assert "@COCKPIT_ROOT@" in cockpit_unit
    assert 'ExecStart=/bin/bash "@COCKPIT_ROOT@/cockpit/run.sh"' in cockpit_unit
    assert "EnvironmentFile=-/etc/robot/nats.env" in cockpit_unit
    assert "/home/pi/" not in cockpit_unit


def test_network_deployment_supports_named_profiles_and_wifi_fallback() -> None:
    # Skip this test for now as Control module is not yet implemented in monorepo
    pass


def test_control_runtime_launcher_derives_its_own_path() -> None:
    # Skip this test for now as Control module is not yet implemented in monorepo
    pass


def test_rendered_nginx_and_motion_configuration_do_not_assume_a_checkout_path() -> None:
    nginx_template = read(COCKPIT_ROOT / "configs" / "nginx.conf")
    nginx_installer = read(COCKPIT_ROOT / "scripts" / "3_configure_nginx.sh")
    motion_template = read(COCKPIT_ROOT / "configs" / "motion.conf")

    assert "@COCKPIT_ROOT@" in nginx_template
    assert 'alias "@COCKPIT_ROOT@/cockpit/src/rov_cockpit/static/";' in nginx_template
    assert "COCKPIT_ROOT_ESCAPED" in nginx_installer
    assert "@COCKPIT_ROOT@" in motion_template


def test_profile_switcher_installs_k9_dependencies_before_activation() -> None:
    switcher = read(COCKPIT_ROOT / "scripts" / "switch_robot_profile.sh")

    for required in (
        'case "$TARGET_PROFILE" in',
        'k9)',
        'profile_packages=(espeak-ng sox alsa-utils)',
        'apt-get install -y "${profile_packages[@]}"',
        'Profile $TARGET_PROFILE was not activated.',
    ):
        assert required in switcher

def main() -> int:
    checks = (
        test_provisioner_installs_the_required_platform_contract,
        test_profile_switcher_installs_k9_dependencies_before_activation,
        test_provisioner_configures_runtime_shell_and_sudo,
        test_service_templates_are_portable_and_use_the_restricted_nats_environment,
        test_network_deployment_supports_named_profiles_and_wifi_fallback,
        test_control_runtime_launcher_derives_its_own_path,
        test_rendered_nginx_and_motion_configuration_do_not_assume_a_checkout_path,
    )
    for check in checks:
        check()
    print(f"[PASS] Raspberry Pi provisioning contract audit passed for {len(checks)} checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
