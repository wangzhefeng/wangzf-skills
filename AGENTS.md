# AGENTS.md

## Strict Trigger Rule: uv_pyenv-3.xx.xx

When a user message contains a token like `uv_pyenv-3.<minor>.<patch>` (example: `uv_pyenv-3.11.11`), treat it as an immediate command to run `uv_pyenv` init with that Python version.

## Required behavior

1. Parse version exactly
- Pattern: `uv_pyenv-(3\.\d+\.\d+)`
- Use the last matched token in the message as `PY_VERSION`.

2. Execute immediately
- Do not ask for confirmation unless blocked by sandbox/permissions.

3. Choose script by platform
- Windows PowerShell:
  - `powershell -ExecutionPolicy Bypass -File "<PROJECT_ROOT>/skills/uv_pyenv/scripts/uv_venv_manager.ps1" init -ProjectPath "<PROJECT_ROOT>" -PythonVersion <PY_VERSION>`
- Linux/macOS:
  - `bash "<PROJECT_ROOT>/skills/uv_pyenv/scripts/uv_venv_manager.sh" init "<PROJECT_ROOT>" "" "<PY_VERSION>"`
- Fallback once (if shell path fails):
  - `python "<PROJECT_ROOT>/skills/uv_pyenv/scripts/uv_venv_manager.py" init --project-path "<PROJECT_ROOT>" --python-version "<PY_VERSION>"`

4. Version-switch semantics (must enforce)
- Ensure `pyproject.toml` exists.
- Auto-adjust `pyproject.toml` `requires-python` to be compatible with target version major/minor (for example `3.11.11` => `>=3.11`).
- Pin requested version to `.python-version`.
- Recreate `.venv` (remove old `.venv` first).
- Reinstall dependencies via `uv sync`.
- If sync fails due lock mismatch, run `uv lock` then `uv sync`.
- Never switch to non-uv tooling.

5. Strict validation after execution
- `.python-version` exists and equals `<PY_VERSION>`.
- `.venv` exists.
- `pyproject.toml` exists and `requires-python` is compatible with `<PY_VERSION>` major/minor.
- `uv.lock` exists in project directory OR any ancestor workspace directory.
- Dependency continuity check:
  - If project had dependencies before switch, ensure they still resolve after switch (e.g., `uv tree` still contains previously added packages).

6. Failure handling
- Retry once with Python fallback script.
- If still failing, report exact failed checks and root cause.

7. Continue build mode in same turn
- If same prompt includes dependency actions (`add/remove/sync/lock/list`), execute them in order after successful init.

8. Safety constraints
- Never run `python -m venv`, `pip`, `poetry`, `pipenv`, or `conda` in this flow.
- Never delete unrelated files/directories.

## Notes

- `<PROJECT_ROOT>` means current repository root.
- If no trigger token is present, do not apply this rule.
