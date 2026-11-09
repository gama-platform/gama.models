"""Compile every .gaml file of an extracted model with a GAMA headless server running in Docker.

The model directory is mounted read-only in a container attached to an `--internal` Docker network (no internet
access), and only gama-server's `describe` command is used: models are compiled, never executed.
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import subprocess
import time
import uuid
from dataclasses import asdict, dataclass, field
from pathlib import Path

import websockets

from .common import utc_now

PORT = 6868
EXPERIMENT_RE = re.compile(r"^\s*experiment\s+(\"[^\"]+\"|'[^']+'|[A-Za-z_][\w]*)([^{;]*)", re.MULTILINE)
TYPE_RE = re.compile(r"\btype\s*:\s*([A-Za-z_]\w*)")


@dataclass
class FileResult:
    file: str
    ok: bool
    experiments: list[str] = field(default_factory=list)
    errors: list[dict] = field(default_factory=list)  # {"message", "line", "source"}
    warnings: int = 0


@dataclass
class ValidationResult:
    image: str
    date: str
    result: str  # "compiled" | "failed" | "error"
    files: list[FileResult] = field(default_factory=list)
    message: str | None = None
    log_tail: str | None = None

    @property
    def ok(self) -> bool:
        return self.result == "compiled"

    def to_dict(self) -> dict:
        return asdict(self)


def experiment_types(source: str) -> dict[str, str]:
    """Best-effort `{experiment name: type}` from the GAML source (gama-server doesn't report the type)."""
    types = {}
    for m in EXPERIMENT_RE.finditer(re.sub(r"//[^\n]*", "", source)):
        name = m.group(1).strip("\"'")
        t = TYPE_RE.search(m.group(2))
        types[name] = t.group(1) if t else "gui"
    return types


def _docker(*args: str, check: bool = True, timeout: float = 600) -> subprocess.CompletedProcess:
    return subprocess.run(["docker", *args], check=check, capture_output=True, text=True, timeout=timeout)


def _relative(source: str | None, mount: str) -> str | None:
    if not source:
        return None
    source = source.removeprefix("file:")
    return source[len(mount):].lstrip("/") if source.startswith(mount) else source


async def _describe_all(ip: str, files: list[str], mount: str, startup_timeout: float, file_timeout: float,
                        container: str) -> list[FileResult]:
    deadline = time.monotonic() + startup_timeout
    while True:
        try:
            ws = await websockets.connect(f"ws://{ip}:{PORT}", max_size=None, open_timeout=5)
            break
        except (OSError, asyncio.TimeoutError, websockets.exceptions.InvalidHandshake):
            if time.monotonic() > deadline:
                raise TimeoutError("GAMA server did not start in time")
            state = _docker("inspect", "-f", "{{.State.Running}}", container, check=False).stdout.strip()
            if state != "true":
                raise RuntimeError("GAMA server stopped during startup")
            await asyncio.sleep(2)

    results = []
    async with ws:
        while True:  # wait for the connection acknowledgement
            message = json.loads(await asyncio.wait_for(ws.recv(), 30))
            if message.get("type") == "ConnectionSuccessful":
                break
        for file in files:
            command = {"type": "describe", "model": f"{mount}/{file}", "experiments": True,
                       "speciesNames": False, "speciesVariables": False, "speciesActions": False}
            await ws.send(json.dumps(command))
            response = await _response_for(ws, command["model"], file_timeout)
            results.append(_file_result(file, response, mount))
        try:
            await ws.send(json.dumps({"type": "exit"}))
        except websockets.exceptions.ConnectionClosed:
            pass
    return results


async def _response_for(ws, model: str, timeout: float) -> dict:
    deadline = time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return {"type": "Timeout", "content": f"Compilation took more than {timeout:.0f} seconds"}
        message = json.loads(await asyncio.wait_for(ws.recv(), remaining))
        kind = message.get("type")
        if kind == "CommandExecutedSuccessfully":
            content = message.get("content")
            if isinstance(content, dict) and content.get("path") not in (None, model):
                continue
            return message
        if kind in ("UnableToExecuteRequest", "MalformedRequest", "GamaServerError", "RuntimeError"):
            command = message.get("command") or {}
            if command.get("model") not in (None, model):
                continue
            return message


def _file_result(file: str, response: dict, mount: str) -> FileResult:
    content = response.get("content")
    if response.get("type") == "CommandExecutedSuccessfully" and isinstance(content, dict):
        names = [e.get("name") for e in content.get("experiments") or [] if e.get("name")]
        return FileResult(file, True, experiments=names)
    result = FileResult(file, False)
    if isinstance(content, dict) and isinstance(content.get("errors"), list):
        for issue in content["errors"]:
            if issue.get("type") == "Error":
                result.errors.append({"message": issue.get("message", ""), "line": issue.get("starting_at_line"),
                                      "source": _relative(issue.get("source") or issue.get("uri"), mount)})
            elif issue.get("type") == "Warning":
                result.warnings += 1
        if not result.errors:
            result.errors.append({"message": content.get("message") or "Compilation failed", "line": None,
                                  "source": file})
    else:
        message = content.get("message") if isinstance(content, dict) else content
        result.errors.append({"message": str(message or response.get("type")), "line": None, "source": file})
    return result


def validate(model_dir: Path, gaml_files: list[str], image: str, *, startup_timeout: float = 240,
             file_timeout: float = 180, memory: str = "4g", cpus: str = "2", pull: bool = True) -> ValidationResult:
    """Compile `gaml_files` (relative to `model_dir`) with the GAMA docker `image`."""
    mount = "/model"
    tag = uuid.uuid4().hex[:10]
    network, container = f"gama-sandbox-{tag}", f"gama-validate-{tag}"
    result = ValidationResult(image=image, date=utc_now(), result="error")
    try:
        if pull:
            _docker("pull", "-q", image, timeout=1800)
        _docker("network", "create", "--internal", network)
        _docker("run", "-d", "--name", container, "--network", network,
                "--memory", memory, "--cpus", cpus, "--pids-limit", "1024",
                "--cap-drop", "ALL", "--security-opt", "no-new-privileges",
                "-v", f"{model_dir.resolve()}:{mount}:ro", image, "-socket", str(PORT))
        ip = _docker("inspect", "-f", "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}",
                     container).stdout.strip()
        files = asyncio.run(_describe_all(ip, gaml_files, mount, startup_timeout, file_timeout, container))
        result.files = files
        result.result = "compiled" if all(f.ok for f in files) else "failed"
    except subprocess.CalledProcessError as error:
        result.message = f"Docker command failed: {' '.join(error.cmd[:3])}… ({(error.stderr or '').strip()[-500:]})"
    except Exception as error:  # noqa: BLE001 - reported to the contributor, details in the logs
        result.message = f"{type(error).__name__}: {error}"
    finally:
        if result.result == "error":
            logs = _docker("logs", "--tail", "40", container, check=False)
            result.log_tail = ((logs.stdout or "") + (logs.stderr or "")).strip()[-4000:] or None
        _docker("rm", "-f", container, check=False)
        _docker("network", "rm", network, check=False)
    return result


def experiments_for(model_dir: Path, validation: ValidationResult) -> list[dict]:
    experiments = []
    for f in validation.files:
        try:
            types = experiment_types((model_dir / f.file).read_text(encoding="utf-8", errors="replace"))
        except OSError:
            types = {}
        experiments += [{"file": f.file, "name": name, "type": types.get(name)} for name in f.experiments]
    return experiments


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Compile the .gaml files of a directory with GAMA in Docker.")
    parser.add_argument("model_dir", type=Path)
    parser.add_argument("--image", default=os.environ.get("GAMA_IMAGE", "gamaplatform/gama:2025.06.4"))
    parser.add_argument("--no-pull", action="store_true")
    args = parser.parse_args(argv)
    files = sorted(p.relative_to(args.model_dir).as_posix() for p in args.model_dir.rglob("*.gaml"))
    result = validate(args.model_dir, files, args.image, pull=not args.no_pull)
    print(json.dumps(result.to_dict(), indent=2))
    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
