"""Turn a submission/update issue into a validated registry entry, then publish it.

`process_issue` runs in the unprivileged workflow job: it handles all the untrusted input (issue text, downloaded
archive) and only writes into an output directory. `publish` and `notify` run in the privileged job and treat that
directory as data: they re-validate the entry before writing it to the repository.
"""

from __future__ import annotations

import json
import os
import re
import traceback
from pathlib import Path

from . import entry as entries
from . import fetch, gama_validate, issue_form, report
from .common import COMMENT_MARKER, MODELS_DIR, REPO_ROOT, RegistryError, dump_json, entry_path, load_config, load_json, \
    resolve_gama_version, utc_now

SUBMISSION_LABEL = "model-submission"
UPDATE_LABEL = "model-update"


def issue_kind(issue: dict) -> str | None:
    labels = {label["name"] if isinstance(label, dict) else label for label in issue.get("labels") or []}
    title = (issue.get("title") or "").lower()
    if UPDATE_LABEL in labels or title.startswith("[model update]"):
        return "update"
    if SUBMISSION_LABEL in labels or title.startswith("[model submission]"):
        return "submission"
    return None


def process_issue(issue: dict, work: Path, out: Path, *, config: dict | None = None,
                  models_dir: Path = MODELS_DIR, validate=gama_validate.validate) -> dict:
    """Process one issue and write result.json / comment.md (and entry.json on success) into `out`."""
    config = config or load_config()
    out.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    kind = issue_kind(issue) or "submission"
    author = issue["user"]["login"]
    number = issue["number"]
    result: dict = {"ok": False, "kind": kind, "issue": number, "author": author, "model_id": None,
                    "repo_url": _repo_url()}
    try:
        _process(issue, kind, author, number, work, config, models_dir, validate, result)
        result["ok"] = True
    except RegistryError as error:
        result["problem"] = str(error)
    except Exception:  # noqa: BLE001 - never leave the contributor without an answer
        traceback.print_exc()
        result["problem"] = ("An unexpected error happened in the registry bot. This is not your fault: a maintainer "
                             "has been notified through the failed workflow run.")
        result["internal_error"] = True
    dump_json(result, out / "result.json")
    if result.get("entry"):
        dump_json(result["entry"], out / "entry.json")
    (out / "comment.md").write_text(report.render_comment(result), encoding="utf-8")
    return result


def _repo_url() -> str:
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    return f"{server}/{os.environ.get('GITHUB_REPOSITORY', 'gama-platform/gama.models')}"


def _process(issue, kind, author, number, work, config, models_dir, validate, result) -> None:
    form = issue_form.parse(issue.get("body") or "", kind)
    issue_form.check_no_errors(form)
    now = utc_now()

    existing = None
    if kind == "update":
        existing = entries.load_existing(form.model_id, models_dir)
        result["model_id"] = existing["id"]
        result["owners"] = entries.owners(existing)
        result["needs_owner_approval"] = not entries.is_owner(existing, author, issue.get("author_association"))
    else:
        model_id = entries.slugify(form.name)
        if model_id and entry_path(model_id, models_dir).exists():
            current = load_json(entry_path(model_id, models_dir))
            if current.get("issue") == number:
                raise RegistryError("This model has already been published from this issue. To change it, open "
                                    "a new issue with the **Update a GAMA model** form.")
        result["model_id"] = entries.new_model_id(form.name, models_dir)

    version = None
    if form.new_file:
        previous_gama = existing["versions"][-1]["gama_version"] if existing else None
        gama_key = resolve_gama_version(form.gama_version, config) or previous_gama
        if gama_key not in config["gama_versions"]:
            raise RegistryError("Please choose a **GAMA version**.")
        version = _fetch_and_validate(form, gama_key, number, work, config, validate, result, now)

    if existing is not None:
        entry, changes = entries.apply_update(existing, form, version=version, now=now)
        result["changes"] = changes
    else:
        entry = entries.build_new(form, model_id=result["model_id"], version=version, author=author, issue=number,
                                  now=now)
    result["entry"] = entry


def _fetch_and_validate(form, gama_key, number, work, config, validate, result, now) -> dict:
    gama = config["gama_versions"][gama_key]
    limits, dl = config["limits"], config["download"]
    fetch.check_url(form.url)
    download = fetch.download(form.url, work / "download.bin", max_bytes=limits["download_bytes"],
                              timeout=dl["timeout_seconds"], attempts=dl["attempts"], user_agent=dl["user_agent"])
    result["download"] = {"url": form.url, "final_url": download.final_url, "sha256": download.sha256,
                          "size": download.size}
    fmt = fetch.detect_format([form.url, download.final_url], download.path)
    result["download"]["format"] = fmt
    if fmt not in gama["formats"]:
        raise RegistryError(f"`.{fmt}` files are not supported by {gama['label']}. Supported: "
                            + ", ".join(f"`.{f}`" for f in gama["formats"]) + ".")
    info = fetch.inspect_and_extract(download.path, fmt, work / "model", max_bytes=limits["extracted_bytes"],
                                     max_files=limits["extracted_files"], max_gaml=limits["gaml_files"])
    vcfg = config["validation"]
    validation = validate(work / "model", info.gaml_files, gama["image"],
                          startup_timeout=vcfg["startup_timeout_seconds"],
                          file_timeout=vcfg["per_file_timeout_seconds"], memory=vcfg["memory"], cpus=vcfg["cpus"])
    result["validation"] = validation.to_dict()
    if validation.result == "error":
        result["internal_error"] = True
        raise RegistryError("GAMA could not be started to compile the model (see below).")
    if not validation.ok:
        raise RegistryError("Some `.gaml` files do not compile (see below).")
    experiments = gama_validate.experiments_for(work / "model", validation)
    result["experiments"] = experiments
    requested = form.main_model
    if not requested and info.manifest_experiments:  # .gamx: the experiment chosen when it was exported
        candidate = info.manifest_experiments[0]["file"].lstrip("/")
        requested = next((f for f in info.gaml_files if f == candidate or f.endswith("/" + candidate)), None)
    main_model = entries.pick_main_model(requested, info.gaml_files, experiments)
    return entries.make_version(form=form, gama_version=gama_key, fmt=fmt, url=form.url, sha256=download.sha256,
                                size=download.size, gaml_files=info.gaml_files, experiments=experiments,
                                image=gama["image"], validated_at=validation.date, issue=number, now=now,
                                main_model=main_model)


# ------------------------------------------------------------------------------------------- privileged steps


def _read_result(result_dir: Path) -> dict:
    result = load_json(result_dir / "result.json")
    if not isinstance(result, dict) or not isinstance(result.get("issue"), int):
        raise ValueError("Malformed result.json")
    return result


def publish(result_dir: Path, models_dir: Path = MODELS_DIR) -> dict:
    """Write the validated entry into the repository. Returns values for the workflow outputs."""
    result = _read_result(result_dir)
    outputs = {"ok": "false", "issue": str(result["issue"])}
    if not result.get("ok"):
        return outputs
    entry = load_json(result_dir / "entry.json")
    entries.check_schema(entry)
    if entry["id"] != result.get("model_id"):
        raise ValueError("Entry id does not match the result")
    path = entry_path(entry["id"], models_dir)
    if result["kind"] == "submission" and path.exists():
        raise ValueError(f"{path} already exists")
    if result["kind"] == "update" and not path.exists():
        raise ValueError(f"{path} does not exist")
    dump_json(entry, path)
    result["entry"] = entry
    (result_dir / "pr.md").write_text(report.render_pr_body(result), encoding="utf-8")
    verb = "Update" if result["kind"] == "update" else "Add"
    title = f"[Registry] {verb} model {entry['id']} {entry['versions'][-1]['version']}"
    labels = [UPDATE_LABEL if result["kind"] == "update" else SUBMISSION_LABEL]
    if result.get("needs_owner_approval"):
        labels.append("needs-owner-approval")
    try:
        relative = path.resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        relative = str(path)
    outputs.update(ok="true", model_id=entry["id"], path=relative,
                   title=re.sub(r"[\r\n]", " ", title), labels=",".join(labels),
                   branch=f"registry/issue-{result['issue']}", pr_body=str(result_dir / "pr.md"))
    return outputs


def notify(result_dir: Path, github, pr_url: str | None = None) -> None:
    """Post/refresh the bot comment on the issue and set its labels."""
    result = _read_result(result_dir)
    issue = result["issue"]
    body = (result_dir / "comment.md").read_text(encoding="utf-8")
    if not body.startswith(COMMENT_MARKER):
        raise ValueError("Malformed comment")
    if pr_url and result.get("ok"):
        body = body.replace("A pull request has been opened", f"Pull request {pr_url} has been opened", 1)
    github.upsert_comment(issue, body, COMMENT_MARKER)
    good, bad = ("validated", "validation-failed") if result.get("ok") else ("validation-failed", "validated")
    github.remove_label(issue, bad)
    labels = [good]
    if result.get("needs_owner_approval"):
        labels.append("needs-owner-approval")
    github.add_labels(issue, labels)


def write_outputs(outputs: dict) -> None:
    target = os.environ.get("GITHUB_OUTPUT")
    lines = [f"{k}={v}" for k, v in outputs.items()]
    if target:
        with open(target, "a", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
    print(json.dumps(outputs, indent=2))
