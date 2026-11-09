"""Minimal GitHub REST client (stdlib only) used by the workflows. Needs GITHUB_TOKEN and GITHUB_REPOSITORY."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request

API = os.environ.get("GITHUB_API_URL", "https://api.github.com")

LABELS = {
    "model-submission": ("0e8a16", "New model submitted to the registry"),
    "model-update": ("1d76db", "Update of a model of the registry"),
    "validated": ("2ea44f", "The registry bot validated this model"),
    "validation-failed": ("d93f0b", "The registry bot could not validate this model"),
    "needs-owner-approval": ("fbca04", "Update requested by someone who isn't an owner of the entry"),
    "registry-link-check": ("b60205", "Weekly check of the registry download links"),
}


class GitHub:
    def __init__(self, token: str | None = None, repository: str | None = None):
        self.token = token or os.environ["GITHUB_TOKEN"]
        self.repository = repository or os.environ["GITHUB_REPOSITORY"]

    def request(self, method: str, path: str, data: dict | None = None, ok_missing: bool = False):
        url = path if path.startswith("http") else f"{API}/repos/{self.repository}{path}"
        body = json.dumps(data).encode() if data is not None else None
        request = urllib.request.Request(url, data=body, method=method, headers={
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
        })
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            if ok_missing and error.code in (404, 422):
                return None
            detail = error.read().decode(errors="replace")[:500]
            raise RuntimeError(f"GitHub API {method} {path} failed: HTTP {error.code} {detail}") from None

    def paginate(self, path: str):
        page = 1
        while True:
            sep = "&" if "?" in path else "?"
            items = self.request("GET", f"{path}{sep}per_page=100&page={page}") or []
            yield from items
            if len(items) < 100:
                return
            page += 1

    # ---------------------------------------------------------------------------------------------- labels

    def ensure_labels(self, names=None) -> None:
        existing = {label["name"] for label in self.paginate("/labels")}
        for name in names or LABELS:
            if name not in existing and name in LABELS:
                color, description = LABELS[name]
                self.request("POST", "/labels", {"name": name, "color": color, "description": description},
                             ok_missing=True)

    def add_labels(self, issue: int, labels: list[str]) -> None:
        if labels:
            self.ensure_labels(labels)
            self.request("POST", f"/issues/{issue}/labels", {"labels": labels})

    def remove_label(self, issue: int, label: str) -> None:
        self.request("DELETE", f"/issues/{issue}/labels/{urllib.parse.quote(label)}", ok_missing=True)

    # -------------------------------------------------------------------------------------------- comments

    def upsert_comment(self, issue: int, body: str, marker: str) -> None:
        """Edit the bot's previous comment carrying `marker`, or create one."""
        for comment in self.paginate(f"/issues/{issue}/comments"):
            if marker in (comment.get("body") or "") and comment.get("user", {}).get("type") == "Bot":
                self.request("PATCH", f"/issues/comments/{comment['id']}", {"body": body})
                return
        self.request("POST", f"/issues/{issue}/comments", {"body": body})

    def comment(self, issue: int, body: str) -> None:
        self.request("POST", f"/issues/{issue}/comments", {"body": body})

    # ---------------------------------------------------------------------------------------------- issues

    def open_issues_with_label(self, label: str) -> list[dict]:
        query = urllib.parse.urlencode({"labels": label, "state": "open"})
        return [i for i in self.paginate(f"/issues?{query}") if "pull_request" not in i]

    def create_issue(self, title: str, body: str, labels: list[str]) -> dict:
        self.ensure_labels(labels)
        return self.request("POST", "/issues", {"title": title, "body": body, "labels": labels})

    def update_issue(self, issue: int, **fields) -> dict:
        return self.request("PATCH", f"/issues/{issue}", fields)
