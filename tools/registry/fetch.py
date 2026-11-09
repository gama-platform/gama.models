"""Download a submitted model archive, fingerprint it and extract it safely.

Everything downloaded is untrusted: archives are inspected before extraction (no absolute paths, no `..`, no
symlinks, bounded size and file count) and nothing in them is ever executed by this module.
"""

from __future__ import annotations

import hashlib
import http.client
import re
import shutil
import stat
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath

from .common import RegistryError

FORMATS = ("zip", "gamp", "gamx")
GAMP_MANIFEST = "gama-project.properties"
GAMX_MANIFEST = "manifest.properties"
IGNORED_PARTS = {"__MACOSX", ".DS_Store", ".metadata"}
CHUNK = 1024 * 1024


class DownloadError(RegistryError):
    def __init__(self, message: str, reason: str):
        super().__init__(message)
        self.reason = reason  # short machine-readable reason, e.g. "http-404", "too-large", "timeout"


@dataclass
class Download:
    path: Path
    sha256: str
    size: int
    final_url: str


@dataclass
class ArchiveInfo:
    format: str
    gaml_files: list[str]
    manifest: dict[str, str] = field(default_factory=dict)
    manifest_experiments: list[dict] = field(default_factory=list)
    file_count: int = 0
    uncompressed_size: int = 0


# --------------------------------------------------------------------------------------------------- URL checks


def check_url(url: str) -> None:
    """Reject links that are known not to be permanent or not to point to the file itself."""
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc:
        raise RegistryError("The download link must start with `https://`.")
    host = parsed.netloc.lower().split(":")[0]
    path = parsed.path
    if host in ("github.com", "www.github.com") and re.search(r"/archive/(refs/heads/|(main|master|develop)\.zip$)", path):
        raise RegistryError(
            "This link is an archive of a **branch**, which changes with every commit, so its fingerprint "
            "would not stay valid. Please create a [release](https://docs.github.com/en/repositories/"
            "releasing-projects-on-github/managing-releases-in-a-repository) and link one of its assets.")
    if host in ("github.com", "www.github.com") and "/blob/" in path:
        raise RegistryError("This link points to the GitHub page of the file, not to the file itself. "
                            "Use the *Download raw file* link or a release asset instead.")
    if host == "drive.google.com" or host == "docs.google.com":
        raise RegistryError("Google Drive links open a preview page instead of the file. Please host the file "
                            "elsewhere (GitHub release, Zenodo, OSF…).")
    if host.endswith("dropbox.com") and "dl=0" in parsed.query:
        raise RegistryError("This Dropbox link opens a preview page: replace `dl=0` by `dl=1` at the end of it.")


# ---------------------------------------------------------------------------------------------------- download


def download(url: str, destination: Path, *, max_bytes: int, timeout: float = 60, attempts: int = 3,
             user_agent: str = "gama-model-registry") -> Download:
    """Stream `url` into `destination`, computing its SHA-256. Retries transient failures."""
    last: DownloadError | None = None
    for attempt in range(1, attempts + 1):
        try:
            return _download_once(url, destination, max_bytes=max_bytes, timeout=timeout, user_agent=user_agent)
        except DownloadError as error:
            last = error
            transient = error.reason in ("timeout", "network") or re.fullmatch(r"http-(5\d\d|429|408)", error.reason)
            if not transient or attempt == attempts:
                break
            time.sleep(min(30, 5 * 2 ** (attempt - 1)))
    assert last is not None
    raise last


def _download_once(url: str, destination: Path, *, max_bytes: int, timeout: float, user_agent: str) -> Download:
    request = urllib.request.Request(url, headers={"User-Agent": user_agent, "Accept": "*/*"})
    digest = hashlib.sha256()
    size = 0
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            final_url = response.geturl()
            if url.startswith("https://") and not final_url.startswith("https://"):
                raise DownloadError("The download was redirected to a non-HTTPS address.", "insecure-redirect")
            declared = response.headers.get("Content-Length")
            if declared and declared.isdigit() and int(declared) > max_bytes:
                raise DownloadError(f"The file is too large ({int(declared)} bytes, the limit is {max_bytes}).",
                                    "too-large")
            content_type = (response.headers.get("Content-Type") or "").lower()
            with open(destination, "wb") as out:
                while chunk := response.read(CHUNK):
                    size += len(chunk)
                    if size > max_bytes:
                        raise DownloadError(f"The file is larger than the limit of {max_bytes} bytes.", "too-large")
                    digest.update(chunk)
                    out.write(chunk)
    except urllib.error.HTTPError as error:
        raise DownloadError(f"The server answered HTTP {error.code} ({error.reason}).", f"http-{error.code}") from None
    except TimeoutError:
        raise DownloadError("The download timed out.", "timeout") from None
    except urllib.error.URLError as error:
        reason = "timeout" if isinstance(error.reason, TimeoutError) else "network"
        raise DownloadError(f"The file could not be downloaded: {error.reason}.", reason) from None
    except (OSError, http.client.HTTPException) as error:
        raise DownloadError(f"The file could not be downloaded: {error}.", "network") from None
    if size == 0:
        raise DownloadError("The downloaded file is empty.", "empty")
    if "text/html" in content_type and not zipfile.is_zipfile(destination):
        raise DownloadError("The link returned a web page instead of a file. Make sure it points directly to the "
                            "`.zip`, `.gamp` or `.gamx` file.", "html")
    return Download(destination, digest.hexdigest(), size, final_url)


# ----------------------------------------------------------------------------------------------------- archives


def _member_path(name: str) -> PurePosixPath:
    if "\\" in name or name.startswith("/") or re.match(r"^[A-Za-z]:", name):
        raise RegistryError(f"The archive contains an unsafe path: `{name}`.")
    path = PurePosixPath(name)
    if any(part == ".." for part in path.parts):
        raise RegistryError(f"The archive contains an unsafe path: `{name}`.")
    return path


def _ignored(path: PurePosixPath) -> bool:
    return any(part in IGNORED_PARTS or part.startswith("._") for part in path.parts)


def _is_symlink(info: zipfile.ZipInfo) -> bool:
    return info.create_system == 3 and stat.S_ISLNK(info.external_attr >> 16)


def parse_properties(text: str) -> dict[str, str]:
    """Minimal Java .properties reader (enough for GAMA manifests)."""
    result: dict[str, str] = {}
    logical: list[str] = []
    buffer = ""
    for raw in text.splitlines():
        line = raw.lstrip()
        if not buffer and (not line or line[0] in "#!"):
            continue
        backslashes = len(line) - len(line.rstrip("\\"))
        if backslashes % 2 == 1:
            buffer += line[:-1]
            continue
        logical.append(buffer + line)
        buffer = ""
    if buffer:
        logical.append(buffer)
    for line in logical:
        m = re.match(r"^((?:\\.|[^=:\s\\])*)\s*[=:\s]\s*(.*)$", line)
        key, value = (m.group(1), m.group(2)) if m else (line, "")
        result[_unescape(key)] = _unescape(value)
    return result


def _unescape(value: str) -> str:
    def repl(m: re.Match) -> str:
        c = m.group(1)
        if c.startswith("u"):
            return chr(int(c[1:], 16))
        return {"t": "\t", "n": "\n", "r": "\r", "f": "\f"}.get(c, c)

    return re.sub(r"\\(u[0-9a-fA-F]{4}|.)", repl, value)


def detect_format(urls: str | list[str], archive: Path) -> str:
    """Return 'zip', 'gamp' or 'gamx' from the first link with a known extension, checked against the content."""
    if not zipfile.is_zipfile(archive):
        raise RegistryError("The downloaded file is not a valid `.zip`, `.gamp` or `.gamx` archive.")
    with zipfile.ZipFile(archive) as zf:
        names = set(zf.namelist())
    paths = [urllib.parse.urlparse(u).path.lower() for u in ([urls] if isinstance(urls, str) else urls) if u]
    declared = next((fmt for path in paths for fmt in FORMATS if path.endswith("." + fmt)), None)
    if declared == "gamp" and GAMP_MANIFEST not in names:
        raise RegistryError(f"This `.gamp` file has no `{GAMP_MANIFEST}`: export it again from GAMA.")
    if declared == "gamx" and GAMX_MANIFEST not in names:
        raise RegistryError(f"This `.gamx` file has no `{GAMX_MANIFEST}`: export it again from GAMA.")
    if declared:
        return declared
    if GAMP_MANIFEST in names:
        return "gamp"
    if GAMX_MANIFEST in names and any(n.startswith("workspace/") for n in names):
        return "gamx"
    return "zip"


def inspect_and_extract(archive: Path, fmt: str, destination: Path, *, max_bytes: int, max_files: int,
                        max_gaml: int) -> ArchiveInfo:
    """Validate every member of `archive` and extract the regular files into `destination`."""
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    root = destination.resolve()
    try:
        zf = zipfile.ZipFile(archive)
    except zipfile.BadZipFile:
        raise RegistryError("The downloaded file is not a valid archive.") from None
    with zf:
        members = []
        declared_total = 0
        for info in zf.infolist():
            path = _member_path(info.filename)
            if _ignored(path) or info.is_dir():
                continue
            if _is_symlink(info):
                raise RegistryError(f"The archive contains a symbolic link (`{info.filename}`), which is not allowed.")
            if info.flag_bits & 0x1:
                raise RegistryError("The archive is password-protected.")
            members.append((info, path))
            declared_total += info.file_size
            if len(members) > max_files:
                raise RegistryError(f"The archive contains more than {max_files} files.")
            if declared_total > max_bytes:
                raise RegistryError(f"The archive is larger than {max_bytes} bytes once extracted.")

        written = 0
        for info, path in members:
            target = (root / Path(*path.parts)).resolve()
            if not target.is_relative_to(root):
                raise RegistryError(f"The archive contains an unsafe path: `{info.filename}`.")
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info) as src, open(target, "wb") as out:
                while chunk := src.read(CHUNK):
                    written += len(chunk)
                    if written > max_bytes:  # don't trust the sizes declared in the zip headers
                        raise RegistryError(f"The archive is larger than {max_bytes} bytes once extracted.")
                    out.write(chunk)

    manifest: dict[str, str] = {}
    manifest_name = {"gamp": GAMP_MANIFEST, "gamx": GAMX_MANIFEST}.get(fmt)
    if manifest_name:
        manifest_file = destination / manifest_name
        if not manifest_file.is_file():
            raise RegistryError(f"The `.{fmt}` file has no `{manifest_name}`: export it again from GAMA.")
        manifest = parse_properties(manifest_file.read_text(encoding="utf-8", errors="replace"))
        if fmt == "gamp" and (manifest.get("format.version") != "1" or manifest.get("archive.kind") != "project"):
            raise RegistryError("Unsupported `.gamp` format version: export it again with a recent GAMA.")

    experiments = []
    if fmt == "gamx":
        count = int(manifest.get("experiments.count", "0") or 0)
        for i in range(min(count, 1000)):
            model = manifest.get(f"experiment.{i}.model")
            name = manifest.get(f"experiment.{i}.name")
            if model and name:
                experiments.append({"file": model, "name": name})

    gaml = sorted(p.relative_to(destination).as_posix() for p in destination.rglob("*.gaml") if p.is_file())
    if not gaml:
        raise RegistryError("No `.gaml` model file was found in the archive.")
    if len(gaml) > max_gaml:
        raise RegistryError(f"The archive contains more than {max_gaml} `.gaml` files.")
    return ArchiveInfo(fmt, gaml, manifest, experiments, len(members), written)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(CHUNK):
            digest.update(chunk)
    return digest.hexdigest()
