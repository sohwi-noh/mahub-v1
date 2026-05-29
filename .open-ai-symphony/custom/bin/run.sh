#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SYMPHONY_DIR="$ROOT_DIR/.open-ai-symphony/elixir"
COMMAND="${1:-doctor}"
WORKFLOW_FILE="${2:-$SYMPHONY_DIR/WORKFLOW.md}"

PRESERVE_ENV_KEYS=(
  LINEAR_API_ENDPOINT
  LINEAR_API_KEY
  LINEAR_ASSIGNEE
  SYMPHONY_GITHUB_ASSIGNEE
  SYMPHONY_GITHUB_DONE_LABEL
  SYMPHONY_GITHUB_OWNER
  SYMPHONY_GITHUB_READY_LABEL
  SYMPHONY_GITHUB_REPO
  SYMPHONY_GITHUB_REVIEW_LABEL
  SYMPHONY_GITHUB_RUNNING_LABEL
  SYMPHONY_GITHUB_TOKEN
  SYMPHONY_TRACKER_KIND
  SYMPHONY_WORKSPACE_ROOT
)

PRESET_ENV_RESTORE=()

for key in "${PRESERVE_ENV_KEYS[@]}"; do
  if [[ "${!key+x}" == "x" ]]; then
    PRESET_ENV_RESTORE+=("$(printf 'export %s=%q' "$key" "${!key}")")
  fi
done

load_env_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

restore_preset_env() {
  local assignment

  for assignment in "${PRESET_ENV_RESTORE[@]}"; do
    eval "$assignment"
  done
}

load_env_file "$ROOT_DIR/.env"
load_env_file "$ROOT_DIR/.env.local"
restore_preset_env

cd "$SYMPHONY_DIR"

if [[ ! -x "$SYMPHONY_DIR/bin/symphony" ]]; then
  mise exec -- mix escript.build
fi

exec mise exec -- "$SYMPHONY_DIR/bin/symphony" "$COMMAND" "$WORKFLOW_FILE"
