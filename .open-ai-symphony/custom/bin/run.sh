#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODE="${1:-local}"
ENV_FILE="${2:-}"
SYMPHONY_DIR="$ROOT_DIR/.open-ai-symphony/elixir"
WORKFLOW_FILE="$ROOT_DIR/.open-ai-symphony/custom/WORKFLOW.md"
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

case "$MODE" in
  local|shared)
    ;;
  *)
    echo "usage: .open-ai-symphony/custom/bin/run.sh [local|shared] [env-file]" >&2
    exit 64
    ;;
esac

load_env_file "$ROOT_DIR/.env"
load_env_file "$ROOT_DIR/.env.local"

if [[ -n "$ENV_FILE" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "missing env file: $ENV_FILE" >&2
    exit 66
  fi
  load_env_file "$ENV_FILE"
fi

if [[ ! -x "$SYMPHONY_DIR/bin/symphony" ]]; then
  echo "missing Symphony runtime: $SYMPHONY_DIR/bin/symphony" >&2
  echo "copy or clone openai/symphony into $ROOT_DIR/.open-ai-symphony first" >&2
  exit 66
fi

if [[ -z "${LINEAR_API_KEY:-}" ]]; then
  echo "LINEAR_API_KEY is required. Put it in .env.local or pass an env file." >&2
  exit 78
fi

if [[ "$MODE" == "local" ]]; then
  export LINEAR_ASSIGNEE="${LINEAR_ASSIGNEE:-me}"
else
  unset LINEAR_ASSIGNEE
fi

export SYMPHONY_WORKSPACE_ROOT="${SYMPHONY_WORKSPACE_ROOT:-$ROOT_DIR/.symphony-workspaces}"
export SYMPHONY_TARGET_REPO_DIR="${SYMPHONY_TARGET_REPO_DIR:-mahub-goal}"
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

cd "$SYMPHONY_DIR"
exec mise exec -- ./bin/symphony "$WORKFLOW_FILE" --port "$SYMPHONY_PORT" "$GUARDRAIL_FLAG"
