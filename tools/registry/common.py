"""Shared paths, configuration and small helpers for the model registry tooling."""

from __future__ import annotations

import datetime as _dt
import json
import re
import unicodedata
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_DIR = REPO_ROOT / "registry"
MODELS_DIR = REGISTRY_DIR / "models"
SCHEMA_DIR = REGISTRY_DIR / "schema"
CONFIG_PATH = REGISTRY_DIR / "config.json"

ID_PATTERN = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LOGIN_PATTERN = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$")
COMMENT_MARKER = "<!-- gama-registry-bot -->"


class RegistryError(Exception):
    """An error caused by the contributor's input: reported back to them, never a crash."""


def utc_now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_json(path: Path) -> Any:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dump_json(data: Any, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def load_config(path: Path = CONFIG_PATH) -> dict:
    return load_json(path)


def slugify(text: str, max_length: int = 64) -> str:
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_text.lower()).strip("-")
    slug = slug[:max_length].rstrip("-")
    return slug


def entry_path(model_id: str, models_dir: Path = MODELS_DIR) -> Path:
    if not ID_PATTERN.match(model_id):
        raise RegistryError(f"`{model_id}` is not a valid model ID (lowercase letters, digits and dashes only).")
    return models_dir / f"{model_id}.json"


def resolve_gama_version(value: str | None, config: dict) -> str | None:
    """Map a dropdown value such as 'alpha (development build)' to a config key such as 'alpha'."""
    if not value:
        return None
    key = value.strip().split()[0]
    if key not in config["gama_versions"]:
        known = ", ".join(config["gama_versions"])
        raise RegistryError(f"Unsupported GAMA version `{value}`. Supported versions: {known}.")
    return key


def human_size(n: int) -> str:
    size = float(n)
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{n} B"
