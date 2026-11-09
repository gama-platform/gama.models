"""Weekly check: every published file must still be downloadable and have the SHA-256 recorded at submission."""

from __future__ import annotations

import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass
from pathlib import Path

from . import entry as entries
from . import fetch
from .common import MODELS_DIR, dump_json, load_config, load_json, utc_now

TRACKING_TITLE = "Registry link check: some model files are unavailable"
LINK_CHECK_LABEL = "registry-link-check"


@dataclass
class Check:
    id: str
    name: str
    version: str
    url: str
    ok: bool
    reason: str | None
    previous_status: str
    owners: list[str]


def check_version(entry: dict, version: dict, *, config: dict, workdir: Path) -> Check:
    dl = config["download"]
    target = workdir / f"{entry['id']}-{version['version']}.bin"
    try:
        result = fetch.download(version["url"], target, max_bytes=max(config["limits"]["download_bytes"],
                                                                       version["size"]),
                                timeout=dl["timeout_seconds"], attempts=dl["attempts"], user_agent=dl["user_agent"])
        ok = result.sha256 == version["sha256"]
        reason = None if ok else "hash-mismatch"
    except fetch.DownloadError as error:
        ok, reason = False, f"unreachable:{error.reason}"
    finally:
        target.unlink(missing_ok=True)
    return Check(entry["id"], entry["name"], version["version"], version["url"], ok, reason, version["status"],
                 entries.owners(entry))


def run(models_dir: Path = MODELS_DIR, *, apply: bool = False, config: dict | None = None, workers: int = 4,
        checker=check_version) -> dict:
    config = config or load_config()
    files = {p: load_json(p) for p in sorted(models_dir.glob("*.json"))}
    jobs = [(path, e, v) for path, e in files.items() for v in e["versions"]]
    with tempfile.TemporaryDirectory(prefix="registry-link-check-") as tmp, ThreadPoolExecutor(workers) as pool:
        checks = list(pool.map(lambda job: checker(job[1], job[2], config=config, workdir=Path(tmp)), jobs))

    now = utc_now()
    flagged, recovered, still_broken = [], [], []
    changed_files = set()
    for (path, entry, version), check in zip(jobs, checks):
        if not check.ok and version["status"] == "available":
            flagged.append(check)
        elif not check.ok:
            still_broken.append(check)
        elif version["status"] == "unavailable":
            recovered.append(check)
        new_status = "available" if check.ok else "unavailable"
        if version["status"] != new_status or version.get("status_reason") != check.reason:
            if version["status"] != new_status:
                version["status_changed_at"] = now
            version["status"], version["status_reason"] = new_status, check.reason
            entry["updated_at"] = now
            changed_files.add(path)
    if apply:
        for path in changed_files:
            entries.check_schema(files[path])
            dump_json(files[path], path)
    return {
        "checked": len(checks),
        "date": now,
        "flagged": [asdict(c) for c in flagged],
        "still_broken": [asdict(c) for c in still_broken],
        "recovered": [asdict(c) for c in recovered],
        "changed_files": sorted(str(p) for p in changed_files),
    }


def _reason_text(reason: str | None) -> str:
    if reason == "hash-mismatch":
        return "file was modified (SHA-256 differs)"
    if reason and reason.startswith("unreachable:"):
        return "unreachable (" + reason.split(":", 1)[1] + ")"
    return reason or ""


def render_issue(report: dict) -> str:
    broken = report["flagged"] + report["still_broken"]
    lines = [
        f"The weekly check of {report['checked']} published file(s) on {report['date']} found "
        f"**{len(broken)} unavailable file(s)**.",
        "",
        "A pull request marks them as `unavailable` in the registry so GAMA stops offering them. To fix an entry, "
        "its owners can restore the original file at the same link, or publish a new version with the "
        "**Update a GAMA model** form.",
        "",
        "| Model | Version | Problem | Owners |",
        "|---|---|---|---|",
    ]
    for c in broken:
        owners = " ".join(f"@{o}" for o in c["owners"])
        lines.append(f"| `{c['id']}` | `{c['version']}` | {_reason_text(c['reason'])} | {owners} |")
    if report["recovered"]:
        lines += ["", "Available again: " + ", ".join(f"`{c['id']}` {c['version']}" for c in report["recovered"])]
    lines += ["", "<sub>Updated automatically every week by the registry link check.</sub>"]
    return "\n".join(lines)


def render_pr(report: dict) -> str:
    lines = ["Automatic update of the availability of registry files, from the weekly link check.", ""]
    if report["flagged"]:
        lines += ["Marked **unavailable**:", ""]
        lines += [f"- `{c['id']}` {c['version']}: {_reason_text(c['reason'])}" for c in report["flagged"]] + [""]
    if report["recovered"]:
        lines += ["Marked **available** again:", ""]
        lines += [f"- `{c['id']}` {c['version']}" for c in report["recovered"]] + [""]
    if report["still_broken"]:
        lines += ["Still unavailable (reason refreshed if it changed):", ""]
        lines += [f"- `{c['id']}` {c['version']}: {_reason_text(c['reason'])}" for c in report["still_broken"]]
    return "\n".join(lines)


def notify(report: dict, github) -> None:
    """Open, update or close the tracking issue."""
    broken = report["flagged"] + report["still_broken"]
    open_issues = github.open_issues_with_label(LINK_CHECK_LABEL)
    tracking = open_issues[0] if open_issues else None
    if broken:
        body = render_issue(report)
        if tracking:
            github.update_issue(tracking["number"], body=body)
            number = tracking["number"]
        else:
            number = github.create_issue(TRACKING_TITLE, body, [LINK_CHECK_LABEL])["number"]
        if report["flagged"] and tracking:
            mentions = sorted({o for c in report["flagged"] for o in c["owners"]})
            github.comment(number, "New unavailable file(s) this week: "
                           + ", ".join(f"`{c['id']}` {c['version']}" for c in report["flagged"])
                           + ". " + " ".join(f"@{m}" for m in mentions))
    elif tracking:
        github.comment(tracking["number"], f"All {report['checked']} published file(s) are available again. 🎉")
        github.update_issue(tracking["number"], state="closed", state_reason="completed")
