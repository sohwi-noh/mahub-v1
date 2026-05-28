#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ACTION="${1:-status}"
MODE="${2:-local}"
ENV_FILE="${3:-}"
SESSION="${SYMPHONY_TMUX_SESSION:-ktds-sdd-symphony-$MODE}"
LOG_DIR="$ROOT_DIR/.symphony-logs"
LOG_FILE="$LOG_DIR/symphony-$MODE.log"

case "$MODE" in
  local|shared)
    ;;
  *)
    echo "사용법: .open-ai-symphony/custom/bin/tmux.sh [start|status|stop|attach|logs] [local|shared] [env-file]" >&2
    exit 64
    ;;
esac

require_tmux() {
  if ! command -v tmux >/dev/null 2>&1; then
    echo "Symphony를 지속 실행하려면 tmux가 필요합니다." >&2
    exit 69
  fi
}

is_running() {
  tmux has-session -t "$SESSION" 2>/dev/null
}

case "$ACTION" in
  start)
    require_tmux
    if is_running; then
      echo "Symphony가 이미 tmux session에서 실행 중입니다: $SESSION"
      exit 0
    fi

    mkdir -p "$LOG_DIR"
    if [[ -n "$ENV_FILE" ]]; then
      printf -v run_cmd './.open-ai-symphony/custom/bin/run.sh %q %q >> %q 2>&1' "$MODE" "$ENV_FILE" "$LOG_FILE"
    else
      printf -v run_cmd './.open-ai-symphony/custom/bin/run.sh %q >> %q 2>&1' "$MODE" "$LOG_FILE"
    fi
    tmux new-session -d -s "$SESSION" -c "$ROOT_DIR" "$run_cmd"
    sleep 1

    if is_running; then
      echo "Symphony를 tmux session에서 시작했습니다: $SESSION"
      echo "대시보드: http://127.0.0.1:${SYMPHONY_PORT:-4101}/"
      echo "로그: $LOG_FILE"
    else
      echo "Symphony가 시작 중 종료됐습니다. 로그를 확인하세요: $LOG_FILE" >&2
      exit 1
    fi
    ;;
  status)
    require_tmux
    if is_running; then
      echo "Symphony가 tmux session에서 실행 중입니다: $SESSION"
    else
      echo "Symphony가 tmux session에서 실행 중이 아닙니다: $SESSION"
      exit 1
    fi
    ;;
  stop)
    require_tmux
    if is_running; then
      tmux send-keys -t "$SESSION" C-c
      sleep 1
      if is_running; then
        tmux kill-session -t "$SESSION"
      fi
      echo "Symphony를 중지했습니다: $SESSION"
    else
      echo "Symphony가 tmux session에서 실행 중이 아닙니다: $SESSION"
    fi
    ;;
  attach)
    require_tmux
    exec tmux attach-session -t "$SESSION"
    ;;
  logs)
    if [[ -f "$LOG_FILE" ]]; then
      tail -n 80 "$LOG_FILE"
    else
      echo "아직 로그 파일이 없습니다: $LOG_FILE"
      exit 1
    fi
    ;;
  *)
    echo "사용법: .open-ai-symphony/custom/bin/tmux.sh [start|status|stop|attach|logs] [local|shared] [env-file]" >&2
    exit 64
    ;;
esac
