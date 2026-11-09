import re
import pytest

from tools.registry import issue_form
from tools.registry.common import REPO_ROOT
from tools.registry.issue_form import KIND_METADATA, KIND_NEW_VERSION

from .conftest import SUBMISSION_BODY, UPDATE_BODY

TEMPLATES = REPO_ROOT / ".github" / "ISSUE_TEMPLATE"


@pytest.mark.parametrize("template", ["submit-model.yml", "update-model.yml"])
def test_template_labels_are_known(template):
    # field labels are those directly under `attributes:`; checkbox options are indented deeper ("- label:")
    field_labels = re.findall(r"^      label:\s*(.+?)\s*$", (TEMPLATES / template).read_text(), re.MULTILINE)
    assert field_labels
    unknown = [label for label in field_labels if label.strip("\"'") not in issue_form.LABELS]
    assert not unknown


def test_template_dropdowns_match_parser():
    text = (TEMPLATES / "update-model.yml").read_text()
    assert KIND_NEW_VERSION in text and KIND_METADATA in text


def test_parse_submission():
    form = issue_form.parse(SUBMISSION_BODY.format(url="https://example.org/m.zip"), "submission")
    assert form.errors == []
    assert form.name == "Schelling segregation"
    assert form.description == "A classic segregation model.\n\n### Usage\n\nPress play."
    assert form.authors == [
        {"name": "Jane Doe", "orcid": "0000-0002-1825-0097", "affiliation": "IRD"},
        {"name": "John Smith", "affiliation": "University of Somewhere, Lab X"},
        {"name": "Alex Martin"},
    ]
    assert form.thematics == ["Social dynamics", "Spatial / GIS", "Segregation"]
    assert form.keywords == ["segregation", "cellular automata"]
    assert form.version == "1.0.0"
    assert form.gama_version == "2025.06"
    assert form.main_model is None and form.citation is None
    assert form.maintainers == ["colleague1", "colleague2"]
    assert form.new_file


def test_submission_missing_fields_and_consent():
    body = SUBMISSION_BODY.format(url="_No response_").replace("- [X] I have", "- [ ] I have")
    form = issue_form.parse(body, "submission")
    assert any("Download link" in e for e in form.errors)
    assert any("Confirmation" in e for e in form.errors)


def test_invalid_values():
    body = (SUBMISSION_BODY.format(url="ftp://nope")
            .replace("https://github.com/jane/schelling", "not a url")
            .replace("@colleague1, colleague2", "bad login!")
            .replace("### Model version\n\n_No response_", "### Model version\n\nv 1"))
    form = issue_form.parse(body, "submission")
    joined = "\n".join(form.errors)
    for word in ("Download link", "Homepage", "maintainers", "Model version"):
        assert word in joined


def test_parse_update_new_version():
    body = UPDATE_BODY.format(kind=KIND_NEW_VERSION, url="https://example.org/v2.zip", version="2.0",
                              keywords="_No response_")
    form = issue_form.parse(body, "update")
    assert form.errors == []
    assert form.model_id == "schelling-segregation"
    assert form.new_file and form.version == "2.0" and form.changelog == "Faster."
    assert form.thematics is None and form.authors is None and form.gama_version is None


def test_parse_update_metadata_only_rejects_link():
    body = UPDATE_BODY.format(kind=KIND_METADATA, url="https://example.org/v2.zip", version="_No response_",
                              keywords="abm")
    form = issue_form.parse(body, "update")
    assert not form.new_file
    assert any("information only" in e for e in form.errors)


def test_parse_update_new_version_requires_link_and_version():
    body = UPDATE_BODY.format(kind=KIND_NEW_VERSION, url="_No response_", version="_No response_",
                              keywords="_No response_")
    errors = "\n".join(issue_form.parse(body, "update").errors)
    assert "Download link" in errors and "Model version" in errors


def test_orcid_url_form():
    authors = issue_form.parse_authors("- Jane (https://orcid.org/0000-0002-1825-009x)")
    assert authors == [{"name": "Jane", "orcid": "0000-0002-1825-009X"}]
