---
tracker:
  kind: $SYMPHONY_TRACKER_KIND
  active_states:
    - Symphony Ready
  terminal_states:
    - Done
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
  linear:
    endpoint: $LINEAR_API_ENDPOINT
    api_key: $LINEAR_API_KEY
    assignee: $LINEAR_ASSIGNEE
  github:
    token: $SYMPHONY_GITHUB_TOKEN
    owner: $SYMPHONY_GITHUB_OWNER
    repo: $SYMPHONY_GITHUB_REPO
    assignee: $SYMPHONY_GITHUB_ASSIGNEE
    ready_label: $SYMPHONY_GITHUB_READY_LABEL
    running_label: $SYMPHONY_GITHUB_RUNNING_LABEL
    review_label: $SYMPHONY_GITHUB_REVIEW_LABEL
    done_label: $SYMPHONY_GITHUB_DONE_LABEL
polling:
  interval_ms: 15000
workspace:
  root: $SYMPHONY_WORKSPACE_ROOT
agent:
  max_concurrent_agents: 3
  max_turns: 3
codex:
  command: CODEX_WORKDIR="$PWD" ../../entrypoint.sh app-server
---

당신은 Symphony가 배정한 issue `{{ issue.identifier }}`를 처리하는 책임 runner입니다.

Title: `{{ issue.title }}`
Tracker: `{{ issue.tracker }}`
URL: `{{ issue.url }}`

작업 전 계획을 남기고, 작업 후 변경 요약과 검증 결과를 issue에 댓글로 기록합니다.
