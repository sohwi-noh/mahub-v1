# Symphony 운영 안내

Symphony는 이 하네스에서 Linear 이슈를 workspace 단위로 실행하는 런타임입니다. 팀에서 공유해야 하는 실행 계약과 hook은 `.open-ai-symphony/custom/` 아래에 둡니다.

## 문서 위치

- `.open-ai-symphony/custom/README.md`: custom entrypoint, hook, GitHub auth helper의 파일 단위 설명.
- `.open-ai-symphony/custom/WORKFLOW.md`: Linear tracker, active/terminal state, Codex runner prompt, 완료 기준.
- `.open-ai-symphony/custom/AGENTS.md`: Symphony가 만든 workspace에 연결되는 최소 runner 계약.

최상위에 별도 `SYMPHONY_AGENTS.md`나 `WORKFLOW.md`를 두지 않습니다. workspace에는 custom hook이 위 파일들을 `AGENTS.md`, `WORKFLOW.md`로 연결합니다.

## 실행 흐름

```text
.open-ai-symphony/custom/bin/tmux.sh start
  -> .open-ai-symphony/custom/bin/run.sh
    -> .open-ai-symphony/elixir/bin/symphony .open-ai-symphony/custom/WORKFLOW.md
      -> .open-ai-symphony/custom/hooks/workspace-setup.sh after-create|before-run
        -> issue workspace 안의 ./mahub-goal repo 준비
```

## Linear 상태 기준

- 실행 대상 상태: `Symphony Ready`
- 완료 상태: `Done`
- PR 요청 상태: `In Review`
- PR 실패 또는 확인 필요 상태: `확인 필요`

PR URL이 생기기 전까지는 `In Review`로 옮기지 않습니다. 작업 결과는 맞지만 PR 생성에 실패하면 실패 사유를 Linear 댓글에 남기고 `확인 필요`로 넘깁니다.

## 환경변수

공유 스키마는 `.env.example`에 둡니다. 실제 값은 `.env.local`에만 둡니다.

- `LINEAR_API_KEY`: Linear API 토큰.
- `LINEAR_ASSIGNEE`: local 모드에서 가져올 Linear 담당자. 기본값은 `me`.
- `SYMPHONY_PORT`: 로컬 Symphony 포트.
- `SYMPHONY_WORKSPACE_ROOT`: 이슈별 workspace 루트.
- `SYMPHONY_TARGET_REPO_DIR`: workspace 안의 실제 작업 repo 디렉터리.
- `SYMPHONY_TARGET_REPO_URL`: workspace origin URL. 비우면 root git origin을 사용합니다.
- `GH_TOKEN` 또는 `GITHUB_TOKEN`: HTTPS Git 작업용 GitHub 토큰.
- `SYMPHONY_GITHUB_SSH_KEY`: SSH remote 사용 시 private key 경로.
- `CODEX_LINEAR_LABELS`: Codex worklog hook을 켤 Linear 라벨. 기본값은 `agent-worklog`.

## Codex Worklog Hook

Codex 로컬 훅은 `.codex/hooks.json`과 `.codex/hooks/`에 둡니다. Linear 이슈에 `agent-worklog` 라벨이 있을 때만 작업 계획/결과 누락 방지 훅을 탑니다.

`codex` 같은 넓은 라벨이나 `Symphony Ready` 상태만으로는 worklog hook 대상이 아닙니다.
