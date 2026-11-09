"""Markdown rendering of the bot's issue comment and pull request body."""

from __future__ import annotations

import json

from .common import COMMENT_MARKER, human_size

MAX_ERRORS = 40


def _code(text: str) -> str:
    """Inline code that survives backticks in `text`."""
    text = str(text).replace("\n", " ")
    fence = "``" if "`" in text else "`"
    return f"{fence}{text}{fence}" if text else ""


def _no_mentions(text: str) -> str:
    """Neutralise @mentions and markdown emphasis in a user-provided one-line value."""
    return str(text).replace("\n", " ").replace("@", "@\u200b").replace("*", "\\*")


def _block(text: str, lang: str = "text") -> str:
    text = str(text).replace("```", "ʼʼʼ")
    return f"```{lang}\n{text}\n```"


def render_comment(result: dict) -> str:
    lines = [COMMENT_MARKER]
    kind = "update" if result.get("kind") == "update" else "submission"
    if result.get("ok"):
        lines.append("## ✅ Model validated")
        lines.append("")
        lines.append("Thanks! Everything looks good. A pull request has been opened to add this "
                     + ("update" if kind == "update" else "model") + " to the registry; a maintainer will review "
                     "and merge it." + (" Editing this issue runs the checks again and updates the pull request."))
    else:
        lines.append("## ❌ The model could not be validated")
        lines.append("")
        lines.append("**Please edit this issue to fix the problem below: the checks run again automatically.**")
    lines.append("")

    if result.get("problem"):
        lines += ["### Problem", "", result["problem"], ""]

    download = result.get("download")
    if download:
        lines += ["### File", "",
                  "| | |", "|---|---|",
                  f"| Link | {_code(download['url'])} |",
                  f"| Format | `{download.get('format', '?')}` |",
                  f"| Size | {human_size(download['size'])} |",
                  f"| SHA-256 | `{download['sha256']}` |", ""]
        if download.get("final_url") and download["final_url"] != download["url"]:
            lines += [f"The link redirects to {_code(download['final_url'])}.", ""]

    validation = result.get("validation")
    if validation:
        files = validation.get("files") or []
        failed = [f for f in files if not f["ok"]]
        lines += [f"### Compilation with `{validation['image']}`", ""]
        if validation["result"] == "error":
            lines += ["The validation could not run. This is probably not your fault: a maintainer will look at it.",
                      "", _block(validation.get("message") or "unknown error")]
            if validation.get("log_tail"):
                lines += ["<details><summary>GAMA log</summary>", "", _block(validation["log_tail"]), "", "</details>"]
            lines.append("")
        else:
            lines.append(f"{len(files) - len(failed)} of {len(files)} `.gaml` file(s) compiled.")
            lines.append("")
            if failed:
                errors = []
                for f in failed:
                    for e in f["errors"]:
                        where = e.get("source") or f["file"]
                        line = f":{e['line']}" if e.get("line") else ""
                        errors.append(f"{where}{line}: {e['message']}")
                errors = list(dict.fromkeys(errors))
                shown = errors[:MAX_ERRORS]
                if len(errors) > MAX_ERRORS:
                    shown.append(f"… and {len(errors) - MAX_ERRORS} more")
                lines += ["Compilation errors:", "", _block("\n".join(shown)), ""]
                lines += ["Every `.gaml` file of the archive must compile with the GAMA version you selected. "
                          "Remove the files that are not part of the model, or fix them.", ""]
            experiments = result.get("experiments") or []
            if experiments and not failed:
                lines += ["<details><summary>Experiments found</summary>", ""]
                lines += [f"- {_code(e['file'])}: {_code(e['name'])}" + (f" ({e['type']})" if e.get("type") else "")
                          for e in experiments[:200]]
                lines += ["", "</details>", ""]

    if result.get("needs_owner_approval"):
        owners = ", ".join(f"@{o}" for o in result.get("owners") or [])
        lines += ["### Ownership", "",
                  f"You are not listed as an owner of this model, so the owners ({owners}) are asked to confirm "
                  "this update on the pull request.", ""]

    if result.get("changes"):
        lines += ["### Changes", ""] + [f"- {c}" for c in result["changes"]] + [""]

    if result.get("entry"):
        lines += ["<details><summary>Registry entry</summary>", "",
                  _block(json.dumps(result["entry"], indent=2, ensure_ascii=False), "json"), "", "</details>", ""]
    repo = result.get("repo_url") or "https://github.com/gama-platform/gama.models"
    lines.append(f"<sub>GAMA model registry bot · [how it works]({repo}/blob/main/CONTRIBUTING.md)</sub>")
    return "\n".join(lines)


def render_pr_body(result: dict) -> str:
    entry = result["entry"]
    issue = result["issue"]
    latest = entry["versions"][-1]
    kind = result.get("kind")
    lines = [
        f"{'Updates' if kind == 'update' else 'Adds'} the model **{_no_mentions(entry['name'])}** (`{entry['id']}`) "
        f"from #{issue}.",
        "",
        "| | |", "|---|---|",
        f"| Submitted by | @{result['author']} |",
        f"| Latest version | `{latest['version']}` ({latest['format']}, GAMA {latest['gama_version']}) |",
        f"| File | {_code(latest['url'])} |",
        f"| SHA-256 | `{latest['sha256']}` |",
        f"| Compiled with | `{latest['validation']['image']}` |",
        "",
    ]
    if result.get("changes"):
        lines += ["Changes:", ""] + [f"- {c}" for c in result["changes"]] + [""]
    if result.get("needs_owner_approval"):
        owners = ", ".join(f"@{o}" for o in result.get("owners") or [])
        lines += [f"> [!WARNING]\n> @{result['author']} is not an owner of this entry. Owners ({owners}): please "
                  "confirm this update in a comment before it is merged.", ""]
    lines += [
        "### Reviewer checklist",
        "",
        "- [ ] The description and metadata are appropriate",
        "- [ ] The license allows redistribution",
        "",
        f"Closes #{issue}",
        "",
        "<sub>Generated by the GAMA model registry bot. Editing the issue updates this pull request.</sub>",
    ]
    return "\n".join(lines)
