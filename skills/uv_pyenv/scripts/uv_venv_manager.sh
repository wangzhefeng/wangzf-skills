#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
project_path="${2:-$PWD}"
packages="${3:-}"
python_version="${4:-3.12}"

require_uv() { command -v uv >/dev/null 2>&1 || { echo "uv is required but not found in PATH." >&2; exit 1; }; }

normalize_major_minor() {
  local v="$1"
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
    return
  fi
  echo "Invalid Python version: $v" >&2
  exit 1
}

update_requires_python() {
  local file="$1"
  local target="$2"
  local mm
  mm="$(normalize_major_minor "$target")"
  local req=">=$mm"

  if grep -Eq '^requires-python\s*=\s*"[^"]*"\s*$' "$file"; then
    sed -i.bak -E "s|^requires-python\s*=\s*\"[^\"]*\"\s*$|requires-python = \"$req\"|" "$file"
    rm -f "$file.bak"
    return
  fi

  if grep -Eq '^\[project\]\s*$' "$file"; then
    awk -v req="$req" 'BEGIN{done=0} /^\[project\]$/ && done==0 {print; print "requires-python = \"" req "\""; done=1; next} {print}' "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
    return
  fi

  echo "Unable to update requires-python: [project] section not found." >&2
  exit 1
}

uv_project() { uv --project "$project_path" "$@"; }

find_lockfile() {
  local p="$project_path"
  while true; do
    [[ -f "$p/uv.lock" ]] && { echo "$p/uv.lock"; return 0; }
    local parent
    parent="$(dirname "$p")"
    [[ "$parent" == "$p" ]] && break
    p="$parent"
  done
  return 1
}

require_project() { [[ -f "$project_path/pyproject.toml" ]] || { echo "pyproject.toml not found in $project_path. Run init first." >&2; exit 1; }; }

split_csv_to_args() {
  local raw="$1" out=()
  IFS=',' read -r -a parts <<< "$raw"
  for p in "${parts[@]}"; do
    p="$(echo "$p" | xargs)"
    [[ -n "$p" ]] && out+=("$p")
  done
  printf '%s\n' "${out[@]}"
}

[[ -n "$action" ]] || { echo "Usage: uv_venv_manager.sh <action> [project_path] [packages_csv] [python_version]" >&2; exit 1; }
require_uv
project_path="$(cd "$project_path" && pwd)"

case "$action" in
  init)
    if [[ ! -f "$project_path/pyproject.toml" ]]; then
      (cd "$project_path" && uv init --bare --no-workspace --name "$(basename "$project_path")" .)
    fi

    update_requires_python "$project_path/pyproject.toml" "$python_version"
    uv_project python pin "$python_version"

    [[ -d "$project_path/.venv" ]] && rm -rf "$project_path/.venv"

    if ! uv_project sync; then
      uv_project lock
      uv_project sync
    fi

    [[ -f "$project_path/.python-version" ]] || { echo ".python-version was not created." >&2; exit 1; }
    [[ -d "$project_path/.venv" ]] || { echo ".venv was not created." >&2; exit 1; }
    lock_path="$(find_lockfile || true)"
    [[ -n "$lock_path" ]] || { echo "uv.lock was not created in project/workspace hierarchy." >&2; exit 1; }

    echo "Initialized/recreated uv project at: $project_path"
    echo "Lockfile path: $lock_path"
    ;;
  sync)
    require_project
    uv_project sync
    ;;
  add)
    require_project
    mapfile -t pkgs < <(split_csv_to_args "$packages")
    [[ ${#pkgs[@]} -gt 0 ]] || { echo "add requires packages csv" >&2; exit 1; }
    uv_project add "${pkgs[@]}"
    ;;
  remove)
    require_project
    mapfile -t pkgs < <(split_csv_to_args "$packages")
    [[ ${#pkgs[@]} -gt 0 ]] || { echo "remove requires packages csv" >&2; exit 1; }
    uv_project remove "${pkgs[@]}"
    ;;
  lock)
    require_project
    uv_project lock
    ;;
  list)
    require_project
    uv_project tree
    ;;
  *)
    echo "Unknown action: $action" >&2
    exit 1
    ;;
esac
