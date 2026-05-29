#!/usr/bin/env bash
set -eu

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TARGET_REPO_DIR="${SYMPHONY_TARGET_REPO_DIR:-target-repo}"
BRANCH_PREFIX="${SYMPHONY_BRANCH_PREFIX:-codex/}"

fail() {
  echo "오류: $*" >&2
  exit 1
}

export GIT_TERMINAL_PROMPT="${GIT_TERMINAL_PROMPT:-0}"

issue_identifier() {
  basename "$(pwd -P)"
}

issue_slug() {
  issue_identifier | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

issue_branch() {
  printf '%s%s\n' "$BRANCH_PREFIX" "$(issue_slug)"
}

target_remote_url() {
  remote=""
  if [ -n "${SYMPHONY_TARGET_REPO_URL:-}" ]; then
    remote="$SYMPHONY_TARGET_REPO_URL"
  else
    remote="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  fi

  if [ -z "$remote" ]; then
    fail ".env.local에 SYMPHONY_TARGET_REPO_URL을 설정하거나 프로젝트 루트에 git origin을 설정하세요."
  fi

  printf '%s\n' "$remote"
}

link_if_missing() {
  source="$1"
  target="$2"

  if [ -L "$target" ] || [ -e "$target" ]; then
    return 0
  fi

  if [ -e "$source" ]; then
    ln -s "$source" "$target"
  fi
}

ensure_codex_surface() {
  link_if_missing "$ROOT/.open-ai-symphony/custom/AGENTS.md" "AGENTS.md"
  link_if_missing "$ROOT/.open-ai-symphony/custom/WORKFLOW.md" "WORKFLOW.md"

  for name in README.md docs; do
    link_if_missing "$ROOT/$name" "$name"
  done
}

repo_default_branch() {
  default_ref="$(git -C "$TARGET_REPO_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  default_branch="${default_ref#origin/}"

  if [ -n "$default_branch" ] && [ "$default_branch" != "$default_ref" ]; then
    printf '%s\n' "$default_branch"
  else
    printf '%s\n' main
  fi
}

ensure_target_repo_remote_matches() {
  actual_remote="$(git -C "$TARGET_REPO_DIR" remote get-url origin 2>/dev/null || true)"
  desired_remote="$(target_remote_url)"
  if [ "$actual_remote" != "$desired_remote" ]; then
    fail "$TARGET_REPO_DIR origin이 기대값과 다릅니다. actual=$actual_remote expected=$desired_remote. 새 workspace에서 다시 실행하세요."
  fi
}

ensure_issue_branch() {
  desired_branch="$(issue_branch)"
  current_branch="$(git -C "$TARGET_REPO_DIR" branch --show-current 2>/dev/null || true)"

  case "$current_branch" in
    "$desired_branch"|"$desired_branch"-*)
      return 0
      ;;
  esac

  if [ -n "$(git -C "$TARGET_REPO_DIR" status --porcelain)" ]; then
    fail "$TARGET_REPO_DIR 저장소의 ${current_branch:-<detached>} branch에 미커밋 변경이 있어 $desired_branch branch로 전환하지 않습니다."
  fi

  if git -C "$TARGET_REPO_DIR" show-ref --verify --quiet "refs/heads/$desired_branch"; then
    git -C "$TARGET_REPO_DIR" switch "$desired_branch"
  else
    default_branch="$(repo_default_branch)"
    git -C "$TARGET_REPO_DIR" switch -c "$desired_branch" "$default_branch" 2>/dev/null || \
      git -C "$TARGET_REPO_DIR" switch -c "$desired_branch"
  fi
}

ensure_target_repo() {
  if [ -d "$TARGET_REPO_DIR/.git" ]; then
    ensure_target_repo_remote_matches
  elif [ -e "$TARGET_REPO_DIR" ]; then
    fail "$TARGET_REPO_DIR 경로가 있지만 git 저장소가 아닙니다."
  else
    git clone "$(target_remote_url)" "$TARGET_REPO_DIR"
  fi

  ensure_issue_branch
}

write_workspace_contract() {
  cat > SYMPHONY_WORKSPACE.md <<EOF
# Symphony Workspace

- Issue: $(issue_identifier)
- Root project: $ROOT
- Target repo dir: $TARGET_REPO_DIR
- Required origin: $(target_remote_url)
- Required branch prefix: $(issue_branch)

product 또는 workflow 변경은 ./$TARGET_REPO_DIR 안에서만 수행합니다.
이 Symphony workspace에서는 Root project 밖을 읽거나 쓰지 않습니다.
EOF
}

setup_workspace() {
  ensure_codex_surface
  ensure_target_repo
  write_workspace_contract
}

after_create() {
  setup_workspace
}

before_run() {
  setup_workspace
}

case "${1:-}" in
  after-create) after_create ;;
  before-run) before_run ;;
  *)
    echo "사용법: $0 after-create|before-run" >&2
    exit 2
    ;;
esac
