import hashlib
import stat
import zipfile

import pytest

from tools.registry import fetch
from tools.registry.common import RegistryError

from .conftest import GOOD_GAML, make_zip

LIMITS = dict(max_bytes=1_000_000, max_files=50, max_gaml=10)


@pytest.mark.parametrize("url", [
    "http://example.org/m.zip",
    "https://github.com/me/repo/archive/refs/heads/main.zip",
    "https://github.com/me/repo/archive/master.zip",
    "https://github.com/me/repo/blob/main/m.zip",
    "https://drive.google.com/file/d/abc/view",
    "https://www.dropbox.com/s/abc/m.zip?dl=0",
])
def test_rejected_urls(url):
    with pytest.raises(RegistryError):
        fetch.check_url(url)


@pytest.mark.parametrize("url", [
    "https://github.com/me/repo/releases/download/v1/m.zip",
    "https://github.com/me/repo/archive/refs/tags/v1.0.zip",
    "https://zenodo.org/records/123/files/m.zip?download=1",
])
def test_accepted_urls(url):
    fetch.check_url(url)


def test_download_hash_and_limits(http_server, tmp_path):
    base, root = http_server
    payload = b"x" * 5000
    (root / "m.zip").write_bytes(payload)
    result = fetch.download(f"{base}/m.zip", tmp_path / "dl" / "f", max_bytes=10_000)
    assert result.sha256 == hashlib.sha256(payload).hexdigest() and result.size == 5000
    with pytest.raises(fetch.DownloadError) as error:
        fetch.download(f"{base}/m.zip", tmp_path / "f2", max_bytes=100)
    assert error.value.reason == "too-large"
    with pytest.raises(fetch.DownloadError) as error:
        fetch.download(f"{base}/missing.zip", tmp_path / "f3", max_bytes=100)
    assert error.value.reason == "http-404"
    (root / "page.html").write_text("<html></html>")
    with pytest.raises(fetch.DownloadError) as error:
        fetch.download(f"{base}/page.html", tmp_path / "f4", max_bytes=10_000)
    assert error.value.reason == "html"


def test_extract_zip(tmp_path):
    archive = make_zip(tmp_path / "m.zip", {
        "Proj/models/main.gaml": GOOD_GAML,
        "Proj/includes/data.csv": "a,b",
        "__MACOSX/Proj/._main.gaml": "junk",
        "Proj/.DS_Store": "junk",
    })
    assert fetch.detect_format("https://x.org/m.zip", archive) == "zip"
    info = fetch.inspect_and_extract(archive, "zip", tmp_path / "out", **LIMITS)
    assert info.gaml_files == ["Proj/models/main.gaml"]
    assert (tmp_path / "out" / "Proj" / "includes" / "data.csv").read_text() == "a,b"
    assert not (tmp_path / "out" / "__MACOSX").exists()


@pytest.mark.parametrize("name", ["../evil.gaml", "/abs/evil.gaml", "a/../../evil.gaml", "C:/evil.gaml",
                                  "a\\..\\evil.gaml"])
def test_zip_slip_rejected(tmp_path, name):
    archive = make_zip(tmp_path / "m.zip", {name: GOOD_GAML, "ok.gaml": GOOD_GAML})
    with pytest.raises(RegistryError, match="unsafe path"):
        fetch.inspect_and_extract(archive, "zip", tmp_path / "out", **LIMITS)
    assert not (tmp_path / "evil.gaml").exists()


def test_symlink_rejected(tmp_path):
    archive = tmp_path / "m.zip"
    with zipfile.ZipFile(archive, "w") as zf:
        zf.writestr("ok.gaml", GOOD_GAML)
        link = zipfile.ZipInfo("link.gaml")
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        zf.writestr(link, "/etc/passwd")
    with pytest.raises(RegistryError, match="symbolic link"):
        fetch.inspect_and_extract(archive, "zip", tmp_path / "out", **LIMITS)


def test_size_and_count_limits(tmp_path):
    big = make_zip(tmp_path / "big.zip", {"a.gaml": "x" * 2_000_000})
    with pytest.raises(RegistryError, match="larger"):
        fetch.inspect_and_extract(big, "zip", tmp_path / "out", **LIMITS)
    many = make_zip(tmp_path / "many.zip", {f"f{i}.txt": "x" for i in range(60)})
    with pytest.raises(RegistryError, match="more than 50 files"):
        fetch.inspect_and_extract(many, "zip", tmp_path / "out", **LIMITS)
    empty = make_zip(tmp_path / "nogaml.zip", {"readme.txt": "x"})
    with pytest.raises(RegistryError, match="No `.gaml`"):
        fetch.inspect_and_extract(empty, "zip", tmp_path / "out", **LIMITS)


def test_not_a_zip(tmp_path):
    f = tmp_path / "m.zip"
    f.write_bytes(b"not a zip")
    with pytest.raises(RegistryError, match="not a valid"):
        fetch.detect_format("https://x.org/m.zip", f)


GAMP_MANIFEST = "#GAMA editable project archive\nformat.version=1\narchive.kind=project\ngama.version=2026.1\n" \
                "projects.count=1\nproject.0.name=Proj\nlink.0=C\\:\\\\data\n"
GAMX_MANIFEST = "format.version=1\npackage.id=x\nruntime.version=2026.1\nexperiments.count=1\n" \
                "experiment.0.model=Proj/models/main.gaml\nexperiment.0.name=main\n"


def test_gamp(tmp_path):
    archive = make_zip(tmp_path / "m.gamp", {"gama-project.properties": GAMP_MANIFEST,
                                             "workspace/Proj/models/main.gaml": GOOD_GAML})
    assert fetch.detect_format("https://x.org/download?id=1", archive) == "gamp"
    assert fetch.detect_format(["https://x.org/m.gamp"], archive) == "gamp"
    info = fetch.inspect_and_extract(archive, "gamp", tmp_path / "out", **LIMITS)
    assert info.manifest["project.0.name"] == "Proj"
    assert info.manifest["link.0"] == "C:\\data"
    assert info.gaml_files == ["workspace/Proj/models/main.gaml"]


def test_gamp_without_manifest(tmp_path):
    archive = make_zip(tmp_path / "m.gamp", {"workspace/Proj/models/main.gaml": GOOD_GAML})
    with pytest.raises(RegistryError, match="gama-project.properties"):
        fetch.detect_format("https://x.org/m.gamp", archive)


def test_gamx(tmp_path):
    archive = make_zip(tmp_path / "m.gamx", {"manifest.properties": GAMX_MANIFEST,
                                             "workspace/Proj/models/main.gaml": GOOD_GAML})
    assert fetch.detect_format("https://x.org/m", archive) == "gamx"
    info = fetch.inspect_and_extract(archive, "gamx", tmp_path / "out", **LIMITS)
    assert info.manifest_experiments == [{"file": "Proj/models/main.gaml", "name": "main"}]


def test_properties_continuation_and_unicode():
    props = fetch.parse_properties("a = one \\\n    two\nb:\\u00e9t\\u00e9\n! comment\nc value with spaces\n")
    assert props == {"a": "one two", "b": "été", "c": "value with spaces"}
