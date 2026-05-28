---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  assignee: $LINEAR_ASSIGNEE
  active_states:
    - Symphony Ready
  terminal_states:
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
    - Done
    - In Review
  retry_exhausted_state: 확인 필요
polling:
  interval_ms: 15000
workspace:
  root: /Users/so2/workspace-so2/mahub-goal/.symphony-workspaces
hooks:
  after_create: |
    /Users/so2/workspace-so2/mahub-goal/.open-ai-symphony/custom/hooks/workspace-setup.sh after-create
  before_run: |
    /Users/so2/workspace-so2/mahub-goal/.open-ai-symphony/custom/hooks/workspace-setup.sh before-run
agent:
  max_concurrent_agents: 1
  max_turns: 1
  max_retry_attempts: 1
codex:
  command: codex --config shell_environment_policy.inherit=all --config 'model="gpt-5.5"' --config model_reasoning_effort=medium app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
    networkAccess: true
    writableRoots:
      - /Users/so2/workspace-so2/mahub-goal/.symphony-workspaces
---

당신은 Linear 이슈 `{{ issue.identifier }}`를 처리하는 mahub-goal 전용 단일 Codex 실행자입니다.

Issue: `{{ issue.identifier }}` / `{{ issue.title }}` / `{{ issue.state }}` / `{{ issue.labels }}` / `{{ issue.url }}`

{% if issue.description %}{{ issue.description }}{% else %}본문이 제공되지 않았습니다.{% endif %}

## 운영 계약

- 이 Symphony는 `/Users/so2/workspace-so2/mahub-goal`만 기준으로 동작한다.
- 다른 프로젝트의 Symphony 설정이나 workspace를 참조하지 않는다.
- Symphony 실행 중에는 `WORKFLOW.md`, `SYMPHONY_WORKSPACE.md`, workspace `AGENTS.md`를 실행 계약으로 우선한다.
- 이슈별 작업 대상 repo는 workspace hook이 만든 `SYMPHONY_WORKSPACE.md`의 `Target repo dir`와 `Required origin`을 기준으로 한다.
- 기본 작업 대상은 workspace 안의 `./mahub-goal` repo다.
- 구현/검증/PR 완료를 주장하기 전에 반드시 `git -C <target-repo-dir> remote get-url origin`, `git -C <target-repo-dir> branch --show-current`, `git -C <target-repo-dir> status --short`, `git -C <target-repo-dir> diff --name-only` 또는 commit log로 실제 변경 위치를 확인한다.
- destructive command 금지: `git reset --hard`, `git checkout --`, 원격 branch 삭제, 강제 push.
- Linear 상태 변경은 가능한 경우 수행하고, 실패하면 Linear 댓글에 남긴다.
- PR 대상 이슈는 GitHub PR URL이 생기기 전까지 `In Review`로 옮기지 않는다.
- PR 생성 실패는 `확인 필요`로 보내고 실패 명령과 원인을 Linear 댓글에 남긴다.

## 완료 기준

- 작업 계획과 변경 범위를 먼저 정리한다.
- 실제 변경 위치가 `SYMPHONY_WORKSPACE.md`의 target repo와 일치하는지 확인한다.
- 가장 가벼운 검증 명령을 실행하고 결과를 남긴다.
- 변경이 있으면 commit, push, PR 생성 또는 PR 링크 확보까지 진행한다.
- Linear에 한국어 작업 결과 댓글을 남긴다.
- 이 실행은 단일 Codex 실행이다. 별도의 실행 체계나 보고서 구조를 만들지 않는다.
