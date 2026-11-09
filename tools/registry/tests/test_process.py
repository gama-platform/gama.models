import hashlib
import shutil

import pytest

from tools.registry import build_index, check_links, entry, fetch, gama_validate, process
from tools.registry.common import load_json
from tools.registry.issue_form import KIND_METADATA, KIND_NEW_VERSION

from .conftest import GOOD_GAML, SUBMISSION_BODY, UPDATE_BODY, fake_validator, make_zip

URL = "https://github.com/jane/schelling/releases/download/v1/schelling.zip"
URL2 = "https://github.com/jane/schelling/releases/download/v2/schelling.zip"


@pytest.fixture
def served(monkeypatch, tmp_path):
    """Fake `fetch.download`: URL -> local file."""
    files = {}

    def fake_download(url, destination, **kwargs):
        if url not in files:
            raise fetch.DownloadError("The server answered HTTP 404 (Not Found).", "http-404")
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(files[url], destination)
        data = destination.read_bytes()
        return fetch.Download(destination, hashlib.sha256(data).hexdigest(), len(data), url)

    monkeypatch.setattr(fetch, "download", fake_download)
    return files


def issue(body, number=12, login="jane", labels=("model-submission",), association="NONE"):
    return {"number": number, "title": "[Model submission] x", "body": body, "user": {"login": login},
            "labels": [{"name": n} for n in labels], "author_association": association}


def submit(tmp_path, served, models_dir, config, validator=None, files=None, url=URL, **kw):
    served[url] = make_zip(tmp_path / f"src-{len(served)}.zip", files or {
        "Schelling/models/main.gaml": GOOD_GAML, "Schelling/models/lib.gaml": "model lib\n"})
    out = tmp_path / f"out-{len(served)}"
    result = process.process_issue(issue(SUBMISSION_BODY.format(url=url), **kw), tmp_path / "work", out,
                                   config=config, models_dir=models_dir, validate=validator or fake_validator())
    return result, out


def test_submission_success(tmp_path, served, models_dir, config):
    validator = fake_validator()
    result, out = submit(tmp_path, served, models_dir, config, validator)
    assert result["ok"], result.get("problem")
    e = load_json(out / "entry.json")
    assert e["id"] == "schelling-segregation" and e["submitted_by"] == "jane"
    assert e["maintainers"] == ["colleague1", "colleague2"]
    v = e["versions"][0]
    assert v["sha256"] == hashlib.sha256(served[URL].read_bytes()).hexdigest()
    assert v["format"] == "zip" and v["gama_version"] == "2025.06" and v["status"] == "available"
    assert v["main_model"] == "Schelling/models/main.gaml"
    assert v["experiments"] == [{"file": "Schelling/models/main.gaml", "name": "main", "type": "gui"},
                                {"file": "Schelling/models/main.gaml", "name": "explore", "type": "batch"}]
    assert validator.calls[0][2] == "gamaplatform/gama:2025.06.4"
    comment = (out / "comment.md").read_text()
    assert comment.startswith("<!-- gama-registry-bot -->") and "✅" in comment and v["sha256"] in comment

    outputs = process.publish(out, models_dir)
    assert outputs["ok"] == "true" and outputs["branch"] == "registry/issue-12"
    assert (models_dir / "schelling-segregation.json").exists()
    assert "Closes #12" in (out / "pr.md").read_text()
    with pytest.raises(ValueError):  # never overwrite an existing entry with a "submission"
        process.publish(out, models_dir)


def test_submission_compile_failure(tmp_path, served, models_dir, config):
    result, out = submit(tmp_path, served, models_dir, config, fake_validator(ok=False))
    assert not result["ok"] and "do not compile" in result["problem"]
    assert not (out / "entry.json").exists()
    comment = (out / "comment.md").read_text()
    assert "❌" in comment and "Unknown facet lines" in comment and "main.gaml:3" in comment
    assert process.publish(out, models_dir) == {"ok": "false", "issue": "12"}


def test_submission_dead_link(tmp_path, served, models_dir, config):
    out = tmp_path / "out"
    result = process.process_issue(issue(SUBMISSION_BODY.format(url=URL)), tmp_path / "w", out, config=config,
                                   models_dir=models_dir, validate=fake_validator())
    assert not result["ok"] and "404" in result["problem"]


def test_submission_format_not_supported(tmp_path, served, models_dir, config):
    url = "https://example.org/m.gamx"
    served[url] = make_zip(tmp_path / "m.gamx", {"manifest.properties": "format.version=1\n",
                                                 "workspace/P/models/main.gaml": GOOD_GAML})
    result = process.process_issue(issue(SUBMISSION_BODY.format(url=url)), tmp_path / "w", tmp_path / "o",
                                   config=config, models_dir=models_dir, validate=fake_validator())
    assert not result["ok"] and "not supported by GAMA 2025.06" in result["problem"]


def test_submission_gamx_on_alpha(tmp_path, served, models_dir, config):
    url = "https://example.org/m.gamx"
    served[url] = make_zip(tmp_path / "m.gamx", {
        "manifest.properties": "format.version=1\nexperiments.count=1\nexperiment.0.model=P/models/b.gaml\n"
                               "experiment.0.name=main\n",
        "workspace/P/models/a.gaml": GOOD_GAML, "workspace/P/models/b.gaml": GOOD_GAML})
    body = SUBMISSION_BODY.format(url=url).replace("### GAMA version\n\n2025.06",
                                                   "### GAMA version\n\nalpha (development build)")
    validator = fake_validator()
    result = process.process_issue(issue(body), tmp_path / "w", tmp_path / "o", config=config,
                                   models_dir=models_dir, validate=validator)
    assert result["ok"], result.get("problem")
    version = result["entry"]["versions"][0]
    assert version["format"] == "gamx" and version["gama_version"] == "alpha"
    assert version["main_model"] == "workspace/P/models/b.gaml"
    assert validator.calls[0][2] == "gamaplatform/gama:alpha"


def test_submission_id_collision(tmp_path, served, models_dir, config):
    result, out = submit(tmp_path, served, models_dir, config)
    process.publish(out, models_dir)
    again, _ = submit(tmp_path, served, models_dir, config, number=13, url=URL2)
    assert not again["ok"] and "already exists" in again["problem"]
    same_issue, _ = submit(tmp_path, served, models_dir, config, url=URL2)
    assert not same_issue["ok"] and "already been published from this issue" in same_issue["problem"]


def test_unexpected_error_is_reported(tmp_path, served, models_dir, config):
    def broken(*a, **kw):
        raise ZeroDivisionError

    result, out = submit(tmp_path, served, models_dir, config, broken)
    assert not result["ok"] and result["internal_error"]
    assert "not your fault" in (out / "comment.md").read_text()


def _published(tmp_path, served, models_dir, config):
    _, out = submit(tmp_path, served, models_dir, config)
    process.publish(out, models_dir)


def update_issue(kind, url="_No response_", version="_No response_", keywords="_No response_", **kw):
    kw.setdefault("labels", ("model-update",))
    return issue(UPDATE_BODY.format(kind=kind, url=url, version=version, keywords=keywords), number=20, **kw)


def test_update_new_version_by_owner(tmp_path, served, models_dir, config):
    _published(tmp_path, served, models_dir, config)
    served[URL2] = make_zip(tmp_path / "v2.zip", {"S/models/main.gaml": GOOD_GAML + "// v2\n"})
    out = tmp_path / "upd"
    result = process.process_issue(update_issue(KIND_NEW_VERSION, URL2, "2.0", login="colleague1"),
                                   tmp_path / "w2", out, config=config, models_dir=models_dir,
                                   validate=fake_validator())
    assert result["ok"], result.get("problem")
    assert not result["needs_owner_approval"]
    e = load_json(out / "entry.json")
    assert [v["version"] for v in e["versions"]] == ["1.0.0", "2.0"]
    assert e["versions"][1]["gama_version"] == "2025.06"  # inherited
    assert e["versions"][1]["changelog"] == "Faster."
    outputs = process.publish(out, models_dir)
    assert outputs["labels"] == "model-update"


def test_update_by_stranger_is_flagged(tmp_path, served, models_dir, config):
    _published(tmp_path, served, models_dir, config)
    out = tmp_path / "upd"
    result = process.process_issue(update_issue(KIND_METADATA, keywords="abm, schelling", login="mallory"),
                                   tmp_path / "w2", out, config=config, models_dir=models_dir,
                                   validate=fake_validator())
    assert result["ok"] and result["needs_owner_approval"]
    assert result["changes"] == ["keywords"]
    assert result["owners"] == ["jane", "colleague1", "colleague2"]
    assert "needs-owner-approval" in process.publish(out, models_dir)["labels"]
    assert "@jane" in (out / "pr.md").read_text()


def test_update_by_repo_member_not_flagged(tmp_path, served, models_dir, config):
    _published(tmp_path, served, models_dir, config)
    result = process.process_issue(update_issue(KIND_METADATA, keywords="abm", login="admin", association="MEMBER"),
                                   tmp_path / "w2", tmp_path / "o", config=config, models_dir=models_dir)
    assert result["ok"] and not result["needs_owner_approval"]


def test_update_errors(tmp_path, served, models_dir, config):
    _published(tmp_path, served, models_dir, config)
    nothing = process.process_issue(update_issue(KIND_METADATA), tmp_path / "w", tmp_path / "o1", config=config,
                                    models_dir=models_dir)
    assert "Nothing to update" in nothing["problem"]
    served[URL2] = make_zip(tmp_path / "v2.zip", {"S/models/main.gaml": GOOD_GAML + "// v2\n"})
    same_version = process.process_issue(update_issue(KIND_NEW_VERSION, URL2, "1.0.0"), tmp_path / "w",
                                         tmp_path / "o2", config=config, models_dir=models_dir,
                                         validate=fake_validator())
    assert "Version `1.0.0` is already published" in same_version["problem"]
    url3 = URL2.replace("v2", "v3")
    served[url3] = served[URL]
    same_file = process.process_issue(update_issue(KIND_NEW_VERSION, url3, "3.0"), tmp_path / "w",
                                      tmp_path / "o3", config=config, models_dir=models_dir,
                                      validate=fake_validator())
    assert "already published as version `1.0.0`" in same_file["problem"]
    body = UPDATE_BODY.format(kind=KIND_METADATA, url="_No response_", version="_No response_", keywords="x")
    unknown = process.process_issue(issue(body.replace("schelling-segregation", "nope"), labels=("model-update",)),
                                    tmp_path / "w", tmp_path / "o4", config=config, models_dir=models_dir)
    assert "No model with the identifier `nope`" in unknown["problem"]


def test_build_index(tmp_path, served, models_dir, config):
    _published(tmp_path, served, models_dir, config)
    site = tmp_path / "site"
    index = build_index.build_site(site, models_dir)
    assert index["count"] == 1
    model = index["models"][0]
    assert model["path"] == "models/schelling-segregation.json" and model["available"]
    assert (site / model["path"]).exists() and (site / "schema" / "model.schema.json").exists()
    assert load_json(site / "index.json") == index


def test_build_index_detects_problems(tmp_path, served, models_dir, config):
    _published(tmp_path, served, models_dir, config)
    data = load_json(models_dir / "schelling-segregation.json")
    (models_dir / "other.json").write_text('{"id": "other"}')
    data["id"] = "renamed"
    (models_dir / "renamed-wrong.json").write_text(__import__("json").dumps(data))
    (models_dir / "notes.txt").write_text("x")
    _, problems = build_index.load_entries(models_dir)
    text = "\n".join(problems)
    assert "other.json" in text and "does not match the file name" in text and "also used by" in text
    assert "notes.txt" in text


def test_check_links(tmp_path, served, models_dir, config):
    _published(tmp_path, served, models_dir, config)
    path = models_dir / "schelling-segregation.json"

    def checker(ok, reason=None):
        return lambda e, v, **kw: check_links.Check(e["id"], e["name"], v["version"], v["url"], ok, reason,
                                                    v["status"], entry.owners(e))

    report = check_links.run(models_dir, apply=True, config=config, checker=checker(True))
    assert report["checked"] == 1 and not report["changed_files"]

    report = check_links.run(models_dir, apply=True, config=config, checker=checker(False, "hash-mismatch"))
    assert [c["id"] for c in report["flagged"]] == ["schelling-segregation"]
    v = load_json(path)["versions"][0]
    assert v["status"] == "unavailable" and v["status_reason"] == "hash-mismatch" and v["status_changed_at"]
    assert "@jane" in check_links.render_issue(report)
    assert not build_index.build_index(build_index.load_entries(models_dir)[0])["models"][0]["available"]

    report = check_links.run(models_dir, apply=True, config=config, checker=checker(False, "hash-mismatch"))
    assert report["still_broken"] and not report["flagged"] and not report["changed_files"]

    report = check_links.run(models_dir, apply=True, config=config, checker=checker(True))
    assert report["recovered"] and load_json(path)["versions"][0]["status"] == "available"


def test_check_version_real_download(tmp_path, http_server, config):
    base, root = http_server
    (root / "m.zip").write_bytes(b"content")
    e = {"id": "m", "name": "M", "submitted_by": "jane", "maintainers": []}
    v = {"version": "1", "url": f"{base}/m.zip", "sha256": hashlib.sha256(b"content").hexdigest(), "size": 7,
         "status": "available"}
    assert check_links.check_version(e, v, config=config, workdir=tmp_path).ok
    (root / "m.zip").write_bytes(b"changed")
    assert check_links.check_version(e, v, config=config, workdir=tmp_path).reason == "hash-mismatch"
    (root / "m.zip").unlink()
    assert check_links.check_version(e, v, config=config, workdir=tmp_path).reason == "unreachable:http-404"


class FakeGitHub:
    def __init__(self, open_issues=()):
        self.calls, self.open = [], list(open_issues)

    def __getattr__(self, name):
        return lambda *a, **kw: self.calls.append((name, a, kw)) or {"number": 99}

    def open_issues_with_label(self, label):
        return self.open


def test_notify_issue(tmp_path, served, models_dir, config):
    _, out = submit(tmp_path, served, models_dir, config)
    gh = FakeGitHub()
    process.notify(out, gh, "https://github.com/o/r/pull/5")
    names = [c[0] for c in gh.calls]
    assert names == ["upsert_comment", "remove_label", "add_labels"]
    assert "Pull request https://github.com/o/r/pull/5" in gh.calls[0][1][1]
    assert gh.calls[1][1] == (12, "validation-failed") and gh.calls[2][1] == (12, ["validated"])


def test_notify_tracking_issue():
    broken = {"checked": 2, "date": "d", "recovered": [], "still_broken": [],
              "flagged": [{"id": "m", "version": "1", "reason": "hash-mismatch", "owners": ["jane"]}]}
    gh = FakeGitHub()
    check_links.notify(broken, gh)
    assert gh.calls[0][0] == "create_issue"
    gh = FakeGitHub(open_issues=[{"number": 7}])
    check_links.notify(broken, gh)
    assert [c[0] for c in gh.calls] == ["update_issue", "comment"]
    gh = FakeGitHub(open_issues=[{"number": 7}])
    check_links.notify({**broken, "flagged": []}, gh)
    assert [c[0] for c in gh.calls] == ["comment", "update_issue"] and gh.calls[1][2]["state"] == "closed"


def test_experiment_types():
    src = 'experiment "My exp" type: gui {}\n// experiment hidden type: batch {}\nexperiment b type:batch until: x {\n'
    assert gama_validate.experiment_types(src) == {"My exp": "gui", "b": "batch"}
