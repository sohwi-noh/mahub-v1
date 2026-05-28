#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export CODEX_HOME="$repo_root/.codex"

load_env_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

load_env_file "$repo_root/.env"
load_env_file "$repo_root/.env.local"

codex_workdir="${CODEX_WORKDIR:-$repo_root}"

if [[ ! -d "$codex_workdir" ]]; then
  echo "CODEX_WORKDIR 디렉터리를 찾을 수 없습니다: $codex_workdir" >&2
  exit 66
fi

mkdir -p "$CODEX_HOME/state"

cd "$codex_workdir"
exec codex --cd "$codex_workdir" "$@"
