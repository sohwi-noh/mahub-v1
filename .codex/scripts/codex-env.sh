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

mkdir -p "$CODEX_HOME/state"

cd "$repo_root"
exec codex --cd "$repo_root" "$@"
