"""Profile and command-contract checks for the K9 Cockpit soundboard drawer."""

import asyncio
import json
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT / "src"))

from rov_cockpit.app import (
    ActiveRobotProfile,
    SoundboardPlaybackRequest,
    home,
    relay_soundboard_playback,
    render_template,
)


def load_profile(name: str) -> ActiveRobotProfile:
    return ActiveRobotProfile.model_validate_json(
        (ROOT / "configs" / "profiles" / f"{name}.json").read_text(encoding="utf-8")
    )


def test_only_k9_enables_the_profile_soundboard_drawer() -> None:
    k9 = load_profile("k9")
    rov = load_profile("rov")
    piwars = load_profile("piwars")

    assert rov.identity_icon == "fa-otter"
    assert k9.identity_icon == "fa-bone"
    assert piwars.identity_icon == "fa-robot"
    assert k9.capabilities["soundboard"] is True
    assert k9.soundboard is not None
    assert [sound.id for sound in k9.soundboard.sounds] == ["affirmative", "negative", "alert"]
    assert k9.commands["sound.play"].subject == "k9.command.sound.play"
    assert any(item["id"] == "soundboard" and item["position"] == "right-drawer" for item in json.loads((ROOT / "configs" / "profiles" / "k9.json").read_text(encoding="utf-8"))["instruments"])
    assert rov.capabilities["soundboard"] is False
    assert piwars.capabilities["soundboard"] is False


def test_authorised_k9_soundboard_request_publishes_the_profile_command() -> None:
    class FakeNatsClient:
        def __init__(self) -> None:
            self.published: list[tuple[str, bytes]] = []
            self.flushed = False

        async def publish(self, subject: str, payload: bytes) -> None:
            self.published.append((subject, payload))

        async def flush(self, *, timeout: int) -> None:
            self.flushed = timeout == 1

    client = FakeNatsClient()
    request = SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(nats_client=client)))
    k9 = load_profile("k9")

    async def relay() -> dict[str, object]:
        with patch("rov_cockpit.app.authenticated_user", return_value={"role": "driver"}), patch(
            "rov_cockpit.app.ACTIVE_ROBOT_PROFILE", k9
        ):
            return await relay_soundboard_playback(
                SoundboardPlaybackRequest(sound_id="affirmative"), request
            )

    result = asyncio.run(relay())

    assert result == {"accepted": True, "sound_id": "affirmative", "label": "Affirmative"}
    assert client.flushed is True
    assert client.published[0][0] == "k9.command.sound.play"
    assert json.loads(client.published[0][1]) == {
        "value": "affirmative",
        "units": "",
        "profile": "k9",
        "source": "cockpit-sound-drawer",
    }


def test_soundboard_drawer_and_endpoint_are_profile_gated() -> None:
    page = (ROOT / "src" / "rov_cockpit" / "templates" / "home.jinja").read_text(encoding="utf-8")
    app = (ROOT / "src" / "rov_cockpit" / "app.py").read_text(encoding="utf-8")

    assert "{% if soundboard %}" in page
    assert 'id="soundboard-drawer" hidden' in page
    assert 'data-sound-id="{{ sound.id }}"' in page
    assert '@app.post("/api/soundboard/play")' in app
    assert 'user["role"] not in {"driver", "admin"}' in app
    assert 'await client.publish(sound_command.subject' in app
    header = (ROOT / "src" / "rov_cockpit" / "templates" / "header.jinja").read_text(encoding="utf-8")
    assert 'fa-solid {{ active_robot_profile.identity_icon }}' in header


def test_every_page_renderer_supplies_the_active_profile() -> None:
    request = SimpleNamespace(
        scope={"type": "http", "method": "GET", "path": "/", "headers": []}
    )
    context = render_template(request, "login.jinja", {"error": None}).context
    assert context["active_robot_profile"].profile_id == "rov"

    response = asyncio.run(home(request))
    body = response.body.decode("utf-8")
    assert "home — ROV" in body
    assert 'fa-solid fa-otter' in body


def main() -> int:
    checks = (
        test_only_k9_enables_the_profile_soundboard_drawer,
        test_authorised_k9_soundboard_request_publishes_the_profile_command,
        test_soundboard_drawer_and_endpoint_are_profile_gated,
        test_every_page_renderer_supplies_the_active_profile,
    )
    for check in checks:
        check()
    print(f"[PASS] K9 soundboard contract audit passed for {len(checks)} checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
