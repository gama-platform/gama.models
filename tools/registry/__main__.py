"""Command line used by the GitHub workflows: `python -m tools.registry <command> …`."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import build_index, check_links, gama_validate, process
from .common import dump_json, load_json


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m tools.registry")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("process-issue", help="Validate a submission/update issue (unprivileged job)")
    p.add_argument("--issue-json", type=Path, required=True, help="Issue object, as returned by the GitHub API")
    p.add_argument("--work", type=Path, required=True, help="Scratch directory for the download")
    p.add_argument("--out", type=Path, required=True, help="Directory receiving result.json, entry.json, comment.md")

    p = sub.add_parser("publish", help="Write the validated entry into registry/models (privileged job)")
    p.add_argument("--result-dir", type=Path, required=True)

    p = sub.add_parser("notify", help="Post the result comment and labels on the issue (privileged job)")
    p.add_argument("--result-dir", type=Path, required=True)
    p.add_argument("--pr-url", default="")

    p = sub.add_parser("build-index", help="Validate the registry and build the site")
    p.add_argument("--out", type=Path)
    p.add_argument("--check", action="store_true")

    p = sub.add_parser("check-links", help="Weekly availability / hash check")
    p.add_argument("--apply", action="store_true", help="Write status changes into registry/models")
    p.add_argument("--out", type=Path, required=True, help="Directory receiving report.json, issue.md, pr.md")

    p = sub.add_parser("check-links-notify", help="Open/update/close the tracking issue")
    p.add_argument("--report", type=Path, required=True)

    sub.add_parser("ensure-labels", help="Create the labels used by the registry workflows")

    p = sub.add_parser("validate", help="Compile a local model directory with GAMA in Docker")
    p.add_argument("model_dir", type=Path)
    p.add_argument("--image", default="gamaplatform/gama:2025.06.4")
    p.add_argument("--no-pull", action="store_true")

    args = parser.parse_args(argv)

    if args.command == "process-issue":
        issue = load_json(args.issue_json)
        if "issue" in issue and "number" not in issue:  # a raw event payload
            issue = issue["issue"]
        result = process.process_issue(issue, args.work, args.out)
        print(json.dumps({k: result.get(k) for k in ("ok", "kind", "model_id", "problem")}, indent=2))
        return 0
    if args.command == "publish":
        process.write_outputs(process.publish(args.result_dir))
        return 0
    if args.command == "notify":
        from .github_api import GitHub
        process.notify(args.result_dir, GitHub(), args.pr_url or None)
        return 0
    if args.command == "build-index":
        return build_index.main((["--out", str(args.out)] if args.out else []) + (["--check"] if args.check else []))
    if args.command == "check-links":
        report = check_links.run(apply=args.apply)
        args.out.mkdir(parents=True, exist_ok=True)
        dump_json(report, args.out / "report.json")
        (args.out / "issue.md").write_text(check_links.render_issue(report), encoding="utf-8")
        (args.out / "pr.md").write_text(check_links.render_pr(report), encoding="utf-8")
        print(f"Checked {report['checked']} file(s): {len(report['flagged'])} newly unavailable, "
              f"{len(report['still_broken'])} still unavailable, {len(report['recovered'])} recovered.")
        process.write_outputs({"changed": "true" if report["changed_files"] else "false"})
        return 0
    if args.command == "check-links-notify":
        from .github_api import GitHub
        check_links.notify(load_json(args.report), GitHub())
        return 0
    if args.command == "ensure-labels":
        from .github_api import GitHub
        GitHub().ensure_labels()
        return 0
    if args.command == "validate":
        return gama_validate.main([str(args.model_dir), "--image", args.image] + (["--no-pull"] if args.no_pull else []))
    return 2


if __name__ == "__main__":
    sys.exit(main())
