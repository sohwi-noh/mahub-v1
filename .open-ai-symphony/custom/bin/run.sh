#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODE="${1:-local}"
ENV_FILE="${2:-}"
SYMPHONY_DIR="$ROOT_DIR/.open-ai-symphony/elixir"
WORKFLOW_TEMPLATE="$ROOT_DIR/.open-ai-symphony/custom/WORKFLOW.md"
RUNTIME_DIR="$ROOT_DIR/.symphony-logs"
WORKFLOW_FILE="$RUNTIME_DIR/WORKFLOW.$MODE.generated.md"
GUARDRAIL_FLAG="--i-understand-that-this-will-be-running-without-the-usual-guardrails"

load_env_file() {
  local file="$1"

  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&|\\]/\\&/g'
}

render_workflow_file() {
  local project_root workspace_root target_repo_dir

  mkdir -p "$RUNTIME_DIR"
  project_root="$(escape_sed_replacement "$ROOT_DIR")"
  workspace_root="$(escape_sed_replacement "$SYMPHONY_WORKSPACE_ROOT")"
  target_repo_dir="$(escape_sed_replacement "$SYMPHONY_TARGET_REPO_DIR")"

  sed \
    -e "s|__SYMPHONY_PROJECT_ROOT__|$project_root|g" \
    -e "s|__SYMPHONY_WORKSPACE_ROOT__|$workspace_root|g" \
    -e "s|__SYMPHONY_TARGET_REPO_DIR__|$target_repo_dir|g" \
    "$WORKFLOW_TEMPLATE" > "$WORKFLOW_FILE"
}

case "$MODE" in
  local|shared)
    ;;
  *)
    echo "사용법: .open-ai-symphony/custom/bin/run.sh [local|shared] [env-file]" >&2
    exit 64
    ;;
esac

load_env_file "$ROOT_DIR/.env"
load_env_file "$ROOT_DIR/.env.local"

if [[ -n "$ENV_FILE" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "env 파일을 찾을 수 없습니다: $ENV_FILE" >&2
    exit 66
  fi
  load_env_file "$ENV_FILE"
fi

if [[ ! -x "$SYMPHONY_DIR/bin/symphony" ]]; then
  echo "Symphony 런타임을 찾을 수 없습니다: $SYMPHONY_DIR/bin/symphony" >&2
  echo "먼저 openai/symphony를 $ROOT_DIR/.open-ai-symphony 아래에 복사하거나 clone하세요." >&2
  exit 66
fi

if [[ -z "${LINEAR_API_KEY:-}" ]]; then
  echo "LINEAR_API_KEY가 필요합니다. .env.local에 넣거나 env 파일을 전달하세요." >&2
  exit 78
fi

if [[ "$MODE" == "local" ]]; then
  export LINEAR_ASSIGNEE="${LINEAR_ASSIGNEE:-me}"
else
  unset LINEAR_ASSIGNEE
fi

export SYMPHONY_WORKSPACE_ROOT="${SYMPHONY_WORKSPACE_ROOT:-$ROOT_DIR/.symphony-workspaces}"
export SYMPHONY_PROJECT_ROOT="$ROOT_DIR"
export SYMPHONY_TARGET_REPO_DIR="${SYMPHONY_TARGET_REPO_DIR:-target-repo}"
export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"
if [[ -z "${GH_TOKEN:-}" && -n "${GITHUB_TOKEN:-}" ]]; then
  export GH_TOKEN="$GITHUB_TOKEN"
fi
if [[ -z "${GITHUB_TOKEN:-}" && -n "${GH_TOKEN:-}" ]]; then
  export GITHUB_TOKEN="$GH_TOKEN"
fi
if [[ -n "${GH_TOKEN:-}" ]]; then
  export GIT_ASKPASS="$ROOT_DIR/.open-ai-symphony/custom/lib/git-askpass-github-token.sh"
else
  export GIT_ASKPASS="${GIT_ASKPASS:-/usr/bin/false}"
fi
if [[ -n "${SYMPHONY_GITHUB_SSH_KEY:-}" ]]; then
  export GIT_SSH_COMMAND="ssh -i $SYMPHONY_GITHUB_SSH_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
fi
export SSH_ASKPASS="${SSH_ASKPASS:-/usr/bin/false}"
export GCM_INTERACTIVE="${GCM_INTERACTIVE:-never}"
if [[ -z "${GIT_CONFIG_COUNT:-}" ]]; then
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=credential.helper
  export GIT_CONFIG_VALUE_0=
fi
SYMPHONY_PORT="${SYMPHONY_PORT:-4101}"
render_workflow_file

cd "$SYMPHONY_DIR"
exec mise exec -- ./bin/symphony "$WORKFLOW_FILE" --port "$SYMPHONY_PORT" "$GUARDRAIL_FLAG"
