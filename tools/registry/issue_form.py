"""Parse the body of the 'Share a GAMA model' and 'Update a GAMA model' issue forms.

GitHub renders an issue form as markdown: every field becomes a `### <label>` heading followed by its value.
Unanswered fields contain `_No response_`, and checkboxes are rendered as `- [X] option` / `- [ ] option`.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

from .common import LOGIN_PATTERN, RegistryError

NO_RESPONSE = "_No response_"

# Issue form label -> internal key. Must stay in sync with .github/ISSUE_TEMPLATE/*.yml (checked by the tests).
LABELS = {
    "Project name": "name",
    "Short description": "description",
    "Authors": "authors",
    "Thematics": "thematics",
    "Other thematics": "other_thematics",
    "Keywords": "keywords",
    "Model version": "version",
    "GAMA version": "gama_version",
    "Download link": "url",
    "Main model file": "main_model",
    "License": "license",
    "Homepage or source repository": "homepage",
    "Citation or DOI": "citation",
    "Other GitHub maintainers": "maintainers",
    "Confirmation": "consent",
    "Model ID": "model_id",
    "What do you want to update?": "kind",
    "What changed in this version?": "changelog",
}

KIND_NEW_VERSION = "Publish a new version of the model file"
KIND_METADATA = "Update the information only"

ORCID_RE = re.compile(r"^(?:https?://orcid\.org/)?(\d{4}-\d{4}-\d{4}-\d{3}[\dX])$", re.IGNORECASE)
CHECKBOX_RE = re.compile(r"^\s*-\s*\[([ xX])\]\s*(.+?)\s*$")


@dataclass
class FormData:
    """Normalised content of an issue form. `None` / empty means 'not provided'."""

    kind: str  # "submission" | "update"
    name: str | None = None
    description: str | None = None
    authors: list[dict] | None = None
    thematics: list[str] | None = None
    keywords: list[str] | None = None
    version: str | None = None
    gama_version: str | None = None
    url: str | None = None
    main_model: str | None = None
    license: str | None = None
    homepage: str | None = None
    citation: str | None = None
    maintainers: list[str] | None = None
    model_id: str | None = None
    new_file: bool = True
    changelog: str | None = None
    errors: list[str] = field(default_factory=list)


def split_sections(body: str) -> dict[str, str]:
    """Return {label: raw value} for every `### <known label>` heading of the body.

    Headings that aren't form labels (e.g. a `### Usage` written inside the description) stay part of the value.
    """
    sections: dict[str, list[str]] = {}
    current: str | None = None
    for line in (body or "").replace("\r\n", "\n").split("\n"):
        heading = re.match(r"^###\s+(.+?)\s*$", line)
        if heading and heading.group(1) in LABELS and heading.group(1) not in sections:
            current = heading.group(1)
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    return {k: "\n".join(v).strip() for k, v in sections.items()}


def _text(raw: str | None) -> str | None:
    if raw is None:
        return None
    value = raw.strip()
    if not value or value == NO_RESPONSE:
        return None
    return value


def _comma_list(raw: str | None) -> list[str] | None:
    value = _text(raw)
    if value is None:
        return None
    items = [item.strip() for item in re.split(r"[,;\n]", value)]
    seen: list[str] = []
    for item in items:
        if item and item not in seen:
            seen.append(item)
    return seen or None


def _checked(raw: str | None) -> tuple[list[str], list[str]]:
    """Return (checked, unchecked) option labels of a checkboxes field."""
    checked, unchecked = [], []
    for line in (raw or "").split("\n"):
        m = CHECKBOX_RE.match(line)
        if m:
            (checked if m.group(1) in "xX" else unchecked).append(m.group(2))
    return checked, unchecked


def parse_authors(raw: str | None) -> list[dict] | None:
    value = _text(raw)
    if value is None:
        return None
    authors = []
    for line in value.split("\n"):
        line = line.strip().lstrip("-*").strip()
        if not line:
            continue
        m = re.match(r"^(.*?)\s*\((.*)\)\s*$", line)
        name, details = (m.group(1), m.group(2)) if m else (line, "")
        author: dict = {"name": name.strip()}
        affiliation = []
        for part in [p.strip() for p in details.split(",") if p.strip()]:
            orcid = ORCID_RE.match(part)
            if orcid and "orcid" not in author:
                author["orcid"] = orcid.group(1).upper()
            else:
                affiliation.append(part)
        if affiliation:
            author["affiliation"] = ", ".join(affiliation)
        if author["name"]:
            authors.append(author)
    return authors or None


def parse_logins(raw: str | None) -> tuple[list[str] | None, list[str]]:
    items = _comma_list(raw)
    if items is None:
        return None, []
    logins, invalid = [], []
    for item in items:
        login = item.lstrip("@").strip()
        if LOGIN_PATTERN.match(login):
            if login.lower() not in [x.lower() for x in logins]:
                logins.append(login)
        else:
            invalid.append(item)
    return logins, invalid


def parse(body: str, kind: str) -> FormData:
    """Parse an issue body. `kind` is "submission" or "update"."""
    if kind not in ("submission", "update"):
        raise ValueError(kind)
    sections = {LABELS[k]: v for k, v in split_sections(body).items() if k in LABELS}
    form = FormData(kind=kind)
    form.name = _text(sections.get("name"))
    form.description = _text(sections.get("description"))
    form.authors = parse_authors(sections.get("authors"))
    form.keywords = _comma_list(sections.get("keywords"))
    form.version = _text(sections.get("version"))
    form.gama_version = _text(sections.get("gama_version"))
    form.url = _text(sections.get("url"))
    form.main_model = _text(sections.get("main_model"))
    if form.main_model:
        form.main_model = form.main_model.strip("`").lstrip("/")
    form.license = _text(sections.get("license"))
    form.homepage = _text(sections.get("homepage"))
    form.citation = _text(sections.get("citation"))
    form.changelog = _text(sections.get("changelog"))
    form.model_id = _text(sections.get("model_id"))
    if form.model_id:
        form.model_id = form.model_id.strip("`").strip().lower()

    checked, _ = _checked(sections.get("thematics"))
    other = _comma_list(sections.get("other_thematics")) or []
    thematics = checked + [t for t in other if t not in checked]
    form.thematics = thematics or None

    form.maintainers, invalid = parse_logins(sections.get("maintainers"))
    if invalid:
        form.errors.append("These maintainers are not valid GitHub usernames: " + ", ".join(f"`{i}`" for i in invalid))

    if form.homepage and not re.match(r"^https?://\S+$", form.homepage):
        form.errors.append("**Homepage or source repository** must be a web address starting with `https://`.")
    if form.url and not re.match(r"^https?://\S+$", form.url):
        form.errors.append("**Download link** must be a web address starting with `https://`.")
    if form.version and not re.match(r"^[0-9A-Za-z][0-9A-Za-z.+_-]{0,31}$", form.version):
        form.errors.append("**Model version** may only contain letters, digits and `. + _ -` (for example `1.2.0`).")

    _, unchecked_consent = _checked(sections.get("consent"))
    if unchecked_consent or "consent" not in sections:
        form.errors.append("Please tick the boxes of the **Confirmation** section.")

    if kind == "submission":
        for key, label in (("name", "Project name"), ("description", "Short description"),
                           ("authors", "Authors"), ("gama_version", "GAMA version"),
                           ("url", "Download link"), ("license", "License")):
            if not getattr(form, key):
                form.errors.append(f"**{label}** is required.")
        form.new_file = True
        form.version = form.version or "1.0.0"
    else:
        kind_value = _text(sections.get("kind"))
        if not form.model_id:
            form.errors.append("**Model ID** is required.")
        if kind_value == KIND_METADATA:
            form.new_file = False
            if form.url:
                form.errors.append("You chose *Update the information only* but gave a **Download link**. "
                                   "Choose *Publish a new version of the model file* to publish a new file.")
        elif kind_value == KIND_NEW_VERSION:
            form.new_file = True
            if not form.url:
                form.errors.append("**Download link** is required to publish a new version.")
            if not form.version:
                form.errors.append("**Model version** is required to publish a new version.")
        else:
            form.errors.append("Please choose what you want to update.")
    return form


def check_no_errors(form: FormData) -> None:
    if form.errors:
        raise RegistryError("\n".join(f"- {e}" for e in form.errors))
