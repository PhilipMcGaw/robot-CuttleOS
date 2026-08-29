"""Small file-backed authentication foundation for the single-ROV Cockpit."""

import base64
import hashlib
import hmac
import json
import secrets
import time
from pathlib import Path

SESSION_COOKIE = "rov_cockpit_session"
SESSION_TTL_SECONDS = 8 * 60 * 60
ROLES = {"driver", "admin"}


def hash_password(password: str, salt: bytes | None = None) -> str:
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 260_000)
    return f"pbkdf2_sha256$260000${salt.hex()}${digest.hex()}"


def verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, rounds, salt_hex, digest_hex = encoded.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        candidate = hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt_hex), int(rounds))
        return hmac.compare_digest(candidate.hex(), digest_hex)
    except (ValueError, TypeError):
        return False


def load_users(path: Path) -> dict[str, dict[str, str]]:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {name: user for name, user in data.items() if user.get("role") in ROLES}


def save_users(path: Path, users: dict[str, dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(users, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def create_session(username: str, role: str, secret: str) -> str:
    payload = {"user": username, "role": role, "expires": int(time.time()) + SESSION_TTL_SECONDS}
    encoded = base64.urlsafe_b64encode(json.dumps(payload, separators=(",", ":")).encode()).decode()
    signature = hmac.new(secret.encode(), encoded.encode(), hashlib.sha256).hexdigest()
    return f"{encoded}.{signature}"


def read_session(value: str | None, secret: str) -> dict[str, str] | None:
    if not value or "." not in value:
        return None
    encoded, signature = value.rsplit(".", 1)
    expected = hmac.new(secret.encode(), encoded.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(signature, expected):
        return None
    try:
        payload = json.loads(base64.urlsafe_b64decode(encoded).decode())
        return payload if int(payload["expires"]) > time.time() else None
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        return None
