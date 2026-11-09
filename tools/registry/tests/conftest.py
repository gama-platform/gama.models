from __future__ import annotations

import http.server
import threading
import zipfile
from pathlib import Path

import pytest

from tools.registry.gama_validate import FileResult, ValidationResult

SUBMISSION_BODY = """### Project name

Schelling segregation

### Short description

A classic segregation model.

### Usage

Press play.

### Authors

Jane Doe (0000-0002-1825-0097, IRD)
John Smith (University of Somewhere, Lab X)
Alex Martin

### Thematics

- [ ] Toy model / teaching
- [ ] Urban & mobility
- [X] Social dynamics
- [x] Spatial / GIS

### Other thematics

Segregation

### Keywords

segregation, cellular automata, segregation

### Model version

_No response_

### GAMA version

2025.06

### Download link

{url}

### Main model file

_No response_

### License

GPL-3.0

### Homepage or source repository

https://github.com/jane/schelling

### Citation or DOI

_No response_

### Other GitHub maintainers

@colleague1, colleague2

### Confirmation

- [X] I have the right to share this model and its data under the license above.
- [X] The link above is permanent and the file will not be modified. I will use the update form to publish a new version.
"""

UPDATE_BODY = """### Model ID

schelling-segregation

### What do you want to update?

{kind}

### Download link

{url}

### Model version

{version}

### GAMA version

_No response_

### Main model file

_No response_

### What changed in this version?

Faster.

### Project name

_No response_

### Short description

_No response_

### Authors

_No response_

### Thematics

- [ ] Toy model / teaching
- [ ] Social dynamics

### Other thematics

_No response_

### Keywords

{keywords}

### License

_No response_

### Homepage or source repository

_No response_

### Citation or DOI

_No response_

### Other GitHub maintainers

_No response_

### Confirmation

- [X] I have the right to share this model and its data, and any new link is permanent.
"""

GOOD_GAML = 'model good\nglobal { int n <- 3; }\nexperiment main type: gui {}\nexperiment explore type: batch {}\n'


def make_zip(path: Path, files: dict[str, str | bytes]) -> Path:
    with zipfile.ZipFile(path, "w") as zf:
        for name, content in files.items():
            zf.writestr(name, content)
    return path


@pytest.fixture
def models_dir(tmp_path) -> Path:
    d = tmp_path / "models"
    d.mkdir()
    return d


@pytest.fixture
def http_server(tmp_path):
    """Serve tmp_path/www over HTTP; yields (base_url, directory)."""
    root = tmp_path / "www"
    root.mkdir()

    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(root), **kw)

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield f"http://127.0.0.1:{server.server_address[1]}", root
    server.shutdown()


def fake_validator(ok: bool = True):
    calls = []

    def validate(model_dir, gaml_files, image, **kwargs):
        calls.append((model_dir, list(gaml_files), image))
        files = [FileResult(f, ok, experiments=["main", "explore"] if ok and f.endswith("main.gaml") else [],
                            errors=[] if ok else [{"message": "Unknown facet lines", "line": 3, "source": f}])
                 for f in gaml_files]
        return ValidationResult(image=image, date="2026-11-09T10:00:00Z", result="compiled" if ok else "failed",
                                files=files)

    validate.calls = calls
    return validate


@pytest.fixture
def config():
    return {
        "gama_versions": {
            "2025.06": {"label": "GAMA 2025.06", "image": "gamaplatform/gama:2025.06.4", "formats": ["zip"]},
            "alpha": {"label": "GAMA alpha", "image": "gamaplatform/gama:alpha", "formats": ["zip", "gamp", "gamx"]},
        },
        "limits": {"download_bytes": 10_000_000, "extracted_bytes": 10_000_000, "extracted_files": 100,
                   "gaml_files": 20},
        "download": {"timeout_seconds": 5, "attempts": 1, "user_agent": "test"},
        "validation": {"startup_timeout_seconds": 5, "per_file_timeout_seconds": 5, "memory": "1g", "cpus": "1"},
    }
