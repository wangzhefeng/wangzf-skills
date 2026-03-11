---
name: uv_pyenv
description: Manage Python project environments with uv official workflow using .python-version and uv.lock, including Python-version switching with .venv recreation and dependency reinstallation.
---

# UV PyEnv

Use this skill when the user wants uv-only Python project environment management with pinned Python and lockfile-based dependencies.

## Hard rule

- Use `uv` only.
- Do not use `python -m venv`, `pip`, `poetry`, `pipenv`, or `conda`.

## Managed files

- `.python-version`: pinned Python version (`uv python pin`).
- `uv.lock`: dependency lockfile (`uv lock` / updated by `uv add` and `uv remove`).
- `pyproject.toml`: dependency source of truth; `requires-python` is auto-adjusted during version switch.
- `.venv`: recreated when switching Python versions.

## Version-switch behavior

When `init` is called with a new version (for example `uv_pyenv-3.11.11`):

1. Ensure `pyproject.toml` exists (create if missing).
2. Auto-adjust `requires-python` to be compatible with target major/minor version.
3. Pin Python to `.python-version`.
4. Recreate `.venv`.
5. Reinstall dependencies using `uv sync`.
6. If sync fails due stale lock, run `uv lock` then `uv sync`.

This allows Python version changes while keeping dependencies managed and reinstalled via uv lock state.

## Workflow

1. `init` (pin/switch version, recreate env, reinstall deps)
2. `sync`
3. `add`
4. `remove`
5. `lock`
6. `list`
