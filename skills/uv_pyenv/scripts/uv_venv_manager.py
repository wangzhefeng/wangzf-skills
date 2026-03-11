#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


def run_uv(args: list[str], cwd: Path, use_project: bool = True) -> str:
    cmd = ["uv"]
    if use_project:
        cmd += ["--project", str(cwd)]
    cmd += args
    proc = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed:\n{proc.stderr.strip()}")
    return proc.stdout.strip()


def require_uv(cwd: Path) -> None:
    run_uv(["--version"], cwd, use_project=False)


def parse_packages(raw: str) -> list[str]:
    return [p.strip() for p in raw.split(",") if p.strip()]


def normalize_major_minor(version: str) -> str:
    m = re.match(r"^(\d+)\.(\d+)", version)
    if not m:
        raise RuntimeError(f"Invalid Python version: {version}")
    return f"{m.group(1)}.{m.group(2)}"


def update_requires_python(pyproject: Path, version: str) -> None:
    target = f">={normalize_major_minor(version)}"
    text = pyproject.read_text(encoding="utf-8")

    if re.search(r'^requires-python\s*=\s*"[^"]*"\s*$', text, flags=re.M):
        text = re.sub(r'^requires-python\s*=\s*"[^"]*"\s*$', f'requires-python = "{target}"', text, flags=re.M)
        pyproject.write_text(text, encoding="utf-8")
        return

    if re.search(r'^\[project\]\s*$', text, flags=re.M):
        text = re.sub(r'^\[project\]\s*$', f'[project]\nrequires-python = "{target}"', text, count=1, flags=re.M)
        pyproject.write_text(text, encoding="utf-8")
        return

    raise RuntimeError("Unable to update requires-python: [project] section not found.")


def require_project(project: Path) -> None:
    if not (project / "pyproject.toml").exists():
        raise RuntimeError(f"pyproject.toml not found in {project}. Run init first.")


def find_lockfile(project: Path) -> Path | None:
    current = project.resolve()
    while True:
        candidate = current / "uv.lock"
        if candidate.exists():
            return candidate
        if current.parent == current:
            return None
        current = current.parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["init", "sync", "add", "remove", "lock", "list"])
    parser.add_argument("--project-path", default=".")
    parser.add_argument("--packages", default="")
    parser.add_argument("--python-version", default="3.12")
    args = parser.parse_args()

    project = Path(args.project_path).resolve()
    require_uv(project)

    if args.action == "init":
        if not (project / "pyproject.toml").exists():
            run_uv(["init", "--bare", "--no-workspace", "--name", project.name, "."], project, use_project=False)

        update_requires_python(project / "pyproject.toml", args.python_version)
        run_uv(["python", "pin", args.python_version], project, use_project=True)

        venv = project / ".venv"
        if venv.exists():
            shutil.rmtree(venv)

        try:
            run_uv(["sync"], project, use_project=True)
        except Exception:
            run_uv(["lock"], project, use_project=True)
            run_uv(["sync"], project, use_project=True)

        if not (project / ".python-version").exists():
            raise RuntimeError(".python-version was not created.")
        if not (project / ".venv").exists():
            raise RuntimeError(".venv was not created.")
        lock_path = find_lockfile(project)
        if lock_path is None:
            raise RuntimeError("uv.lock was not created in project/workspace hierarchy.")

        print(f"Initialized/recreated uv project at: {project}")
        print(f"Lockfile path: {lock_path}")
        print("Updated requires-python for requested version and re-synced dependencies.")
        return 0

    require_project(project)

    if args.action == "sync":
        run_uv(["sync"], project, use_project=True)
        return 0
    if args.action == "add":
        pkgs = parse_packages(args.packages)
        if not pkgs:
            raise RuntimeError("add requires --packages, e.g. requests,pytest")
        run_uv(["add", *pkgs], project, use_project=True)
        return 0
    if args.action == "remove":
        pkgs = parse_packages(args.packages)
        if not pkgs:
            raise RuntimeError("remove requires --packages, e.g. requests")
        run_uv(["remove", *pkgs], project, use_project=True)
        return 0
    if args.action == "lock":
        run_uv(["lock"], project, use_project=True)
        return 0
    if args.action == "list":
        print(run_uv(["tree"], project, use_project=True))
        return 0

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
