"""Build or update a registry entry (registry/models/<id>.json) from a parsed issue form."""

from __future__ import annotations

import copy
from pathlib import Path

import jsonschema

from .common import MODELS_DIR, SCHEMA_DIR, RegistryError, entry_path, load_json, slugify

TRUSTED_ASSOCIATIONS = {"OWNER", "MEMBER", "COLLABORATOR"}
METADATA_FIELDS = ("name", "description", "authors", "thematics", "keywords", "license", "homepage", "citation",
                   "maintainers")

_validator: jsonschema.protocols.Validator | None = None


def schema_validator() -> jsonschema.protocols.Validator:
    global _validator
    if _validator is None:
        schema = load_json(SCHEMA_DIR / "model.schema.json")
        cls = jsonschema.validators.validator_for(schema)
        _validator = cls(schema, format_checker=cls.FORMAT_CHECKER)
    return _validator


def schema_errors(entry: dict) -> list[str]:
    errors = sorted(schema_validator().iter_errors(entry), key=lambda e: list(e.absolute_path))
    return [f"{'/'.join(map(str, e.absolute_path)) or '(root)'}: {e.message}" for e in errors]


def check_schema(entry: dict) -> None:
    errors = schema_errors(entry)
    if errors:
        raise RegistryError("The generated entry is invalid:\n" + "\n".join(f"- `{e}`" for e in errors))


def is_owner(entry: dict, login: str, association: str | None) -> bool:
    """Original submitter, listed maintainer, or someone with rights on the repository."""
    if (association or "").upper() in TRUSTED_ASSOCIATIONS:
        return True
    owners = [entry.get("submitted_by", "")] + list(entry.get("maintainers") or [])
    return login.lower() in (o.lower() for o in owners)


def owners(entry: dict) -> list[str]:
    result = []
    for login in [entry.get("submitted_by")] + list(entry.get("maintainers") or []):
        if login and login.lower() not in (r.lower() for r in result):
            result.append(login)
    return result


def pick_main_model(requested: str | None, gaml_files: list[str], experiments: list[dict]) -> str | None:
    if requested:
        if requested not in gaml_files:
            matches = [f for f in gaml_files if f.endswith("/" + requested) or f == requested]
            if len(matches) != 1:
                raise RegistryError(f"The main model file `{requested}` was not found in the archive. "
                                    "Files found:\n" + "\n".join(f"- `{f}`" for f in gaml_files[:50]))
            return matches[0]
        return requested
    with_experiments = sorted({e["file"] for e in experiments})
    return with_experiments[0] if len(with_experiments) == 1 else None


def make_version(*, form, gama_version: str, fmt: str, url: str, sha256: str, size: int, gaml_files: list[str],
                 experiments: list[dict], image: str, validated_at: str, issue: int | None, now: str,
                 main_model: str | None) -> dict:
    return {
        "version": form.version,
        "gama_version": gama_version,
        "format": fmt,
        "url": url,
        "sha256": sha256,
        "size": size,
        "added_at": now,
        "issue": issue,
        "changelog": form.changelog,
        "main_model": main_model,
        "gaml_files": gaml_files,
        "experiments": experiments,
        "validation": {"image": image, "date": validated_at, "result": "compiled"},
        "status": "available",
        "status_reason": None,
        "status_changed_at": None,
    }


def new_model_id(name: str, models_dir: Path = MODELS_DIR) -> str:
    model_id = slugify(name)
    if not model_id:
        raise RegistryError("The project name must contain at least one letter or digit.")
    if entry_path(model_id, models_dir).exists():
        raise RegistryError(
            f"A model with the identifier `{model_id}` already exists in the registry. If it is yours, use the "
            "**Update a GAMA model** form; otherwise choose a different project name.")
    return model_id


def build_new(form, *, model_id: str, version: dict, author: str, issue: int | None, now: str) -> dict:
    maintainers = [m for m in (form.maintainers or []) if m.lower() != author.lower()]
    entry = {
        "schema_version": 1,
        "id": model_id,
        "name": form.name,
        "description": form.description,
        "authors": form.authors,
        "thematics": form.thematics or [],
        "keywords": form.keywords or [],
        "license": form.license,
        "homepage": form.homepage,
        "citation": form.citation,
        "submitted_by": author,
        "maintainers": maintainers,
        "issue": issue,
        "created_at": now,
        "updated_at": now,
        "versions": [version],
    }
    check_schema(entry)
    return entry


def load_existing(model_id: str, models_dir: Path = MODELS_DIR) -> dict:
    path = entry_path(model_id, models_dir)
    if not path.exists():
        raise RegistryError(f"No model with the identifier `{model_id}` exists in the registry. Check the "
                            "[index](https://gama-platform.org/gama.models/registry/index.json), or use the "
                            "**Share a GAMA model** form for a new model.")
    return load_json(path)


def apply_update(existing: dict, form, *, version: dict | None, now: str) -> tuple[dict, list[str]]:
    """Return (updated entry, list of human-readable changes)."""
    entry = copy.deepcopy(existing)
    changes = []
    for key in METADATA_FIELDS:
        value = getattr(form, key)
        if value is None:
            continue
        if key == "maintainers":
            value = [m for m in value if m.lower() != entry["submitted_by"].lower()]
        if entry.get(key) != value:
            entry[key] = value
            changes.append(key)
    if version is not None:
        for previous in entry["versions"]:
            if previous["version"] == version["version"]:
                raise RegistryError(f"Version `{version['version']}` is already published. Choose a new version "
                                    "number.")
            if previous["url"] == version["url"] or previous["sha256"] == version["sha256"]:
                raise RegistryError(f"This file is already published as version `{previous['version']}`.")
        entry["versions"].append(version)
        changes.append(f"new version {version['version']}")
    if not changes:
        raise RegistryError("Nothing to update: all the fields are empty or identical to the current values.")
    entry["updated_at"] = now
    check_schema(entry)
    return entry, changes
