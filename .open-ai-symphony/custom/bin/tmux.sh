#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SESSION_NAME="${SYMPHONY_TMUX_SESSION:-symphony-local}"

case "${1:-status}" in
  start)
    tmux new-session -d -s "$SESSION_NAME" "$ROOT_DIR/.open-ai-symphony/custom/bin/run.sh serve"
    echo "Symphony를 tmux session에서 시작했습니다: $SESSION_NAME"
    ;;
  stop)
    tmux kill-session -t "$SESSION_NAME"
    echo "Symphony를 중지했습니다: $SESSION_NAME"
    ;;
  attach)
    exec tmux attach -t "$SESSION_NAME"
    ;;
  status)
    tmux has-session -t "$SESSION_NAME" 2>/dev/null && echo "running: $SESSION_NAME" || echo "stopped: $SESSION_NAME"
    ;;
  *)
    echo "사용법: $0 start|stop|attach|status" >&2
    exit 64
    ;;
esac
