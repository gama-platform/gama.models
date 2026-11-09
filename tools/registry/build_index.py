"""Validate every registry entry and generate the published site: index.json + models/*.json + schema/."""

from __future__ import annotations

import shutil
from pathlib import Path

import jsonschema

from . import entry as entries
from .common import MODELS_DIR, SCHEMA_DIR, RegistryError, dump_json, load_json, utc_now


def load_entries(models_dir: Path = MODELS_DIR) -> tuple[list[dict], list[str]]:
    """Return (entries, problems). Problems make the CI fail."""
    loaded, problems, urls = [], [], {}
    for path in sorted(models_dir.glob("*.json")):
        try:
            data = load_json(path)
        except ValueError as error:
            problems.append(f"{path.name}: invalid JSON ({error})")
            continue
        errors = entries.schema_errors(data)
        problems += [f"{path.name}: {e}" for e in errors]
        if errors:
            continue
        if data["id"] != path.stem:
            problems.append(f"{path.name}: id `{data['id']}` does not match the file name")
        seen_versions = set()
        for version in data["versions"]:
            if version["version"] in seen_versions:
                problems.append(f"{path.name}: version {version['version']} appears twice")
            seen_versions.add(version["version"])
            if version["url"] in urls and urls[version["url"]] != data["id"]:
                problems.append(f"{path.name}: {version['url']} is also used by {urls[version['url']]}")
            urls[version["url"]] = data["id"]
        loaded.append(data)
    if models_dir.exists():
        for stray in sorted(models_dir.iterdir()):
            if stray.suffix != ".json" and stray.name != ".gitkeep":
                problems.append(f"unexpected file in {models_dir.name}/: {stray.name}")
    return loaded, problems


def summary(entry: dict) -> dict:
    latest = entry["versions"][-1]
    return {
        "id": entry["id"],
        "name": entry["name"],
        "path": f"models/{entry['id']}.json",
        "latest_version": latest["version"],
        "gama_version": latest["gama_version"],
        "format": latest["format"],
        "thematics": entry.get("thematics") or [],
        "available": any(v["status"] == "available" for v in entry["versions"]),
        "updated_at": entry["updated_at"],
    }


def build_index(all_entries: list[dict], generated_at: str | None = None) -> dict:
    models = sorted((summary(e) for e in all_entries), key=lambda m: (m["name"].casefold(), m["id"]))
    index = {"schema_version": 1, "generated_at": generated_at or utc_now(), "count": len(models), "models": models}
    jsonschema.validate(index, load_json(SCHEMA_DIR / "index.schema.json"))
    return index


def build_site(out: Path, models_dir: Path = MODELS_DIR) -> dict:
    all_entries, problems = load_entries(models_dir)
    if problems:
        raise RegistryError("Invalid registry:\n" + "\n".join(f"- {p}" for p in problems))
    index = build_index(all_entries)
    if out.exists():
        shutil.rmtree(out)
    (out / "models").mkdir(parents=True)
    for e in all_entries:
        dump_json(e, out / "models" / f"{e['id']}.json")
    shutil.copytree(SCHEMA_DIR, out / "schema")
    dump_json(index, out / "index.json")
    return index


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Validate the registry and build the published files.")
    parser.add_argument("--out", type=Path, help="Output directory (e.g. _site/registry)")
    parser.add_argument("--check", action="store_true", help="Only validate, don't write anything")
    parser.add_argument("--models-dir", type=Path, default=MODELS_DIR)
    args = parser.parse_args(argv)
    if args.check or not args.out:
        all_entries, problems = load_entries(args.models_dir)
        for p in problems:
            print(f"::error::{p}")
        if problems:
            return 1
        build_index(all_entries)
        print(f"Registry OK: {len(all_entries)} model(s).")
        return 0
    try:
        index = build_site(args.out, args.models_dir)
    except RegistryError as error:
        print(f"::error::{error}")
        return 1
    print(f"Wrote {args.out}/index.json with {index['count']} model(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
