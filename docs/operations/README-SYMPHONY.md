# Symphony 운영 안내

Symphony는 이 하네스에서 Linear 이슈마다 격리된 작업공간을 만들고, 그 안에서 Codex 실행을 오케스트레이션하는 런타임입니다.

여기서 작업공간은 Codex 설정 폴더가 아니라 `.symphony-workspaces/<이슈키>/` 아래에 생기는 이슈별 실행 폴더를 뜻합니다.

이 문서는 Symphony 상위 안내만 다룹니다. 실행 흐름, GitHub 인증, workflow 세부 내용은 `.open-ai-symphony/custom/README.md`를 기준으로 봅니다.

## 기준 위치

- `.open-ai-symphony/custom/README.md`: Symphony custom entrypoint와 이슈별 작업공간 hook의 파일 단위 설명.
- `.open-ai-symphony/custom/WORKFLOW.md`: Linear tracker, Codex runner prompt, 완료 기준.
- `.open-ai-symphony/custom/AGENTS.md`: Symphony가 만든 이슈별 작업공간에 연결되는 최소 runner 계약.

## 위치 원칙

- 최상위에 별도 `SYMPHONY_AGENTS.md`나 `WORKFLOW.md`를 두지 않습니다.
- Symphony 전용 실행 계약과 이슈별 작업공간 hook은 `.open-ai-symphony/custom/` 아래에 둡니다.
- `.codex/hooks.json`과 `.codex/hooks/**`는 실행 엔트리로 들어온 작업의 정책 검사에만 사용합니다.
- Symphony가 실행하는 Codex도 루트 `.codex/` 하네스를 사용하되, `CODEX_WORKDIR`로 이슈별 작업공간만 바꿉니다.
- 환경변수 스키마는 `.env.example`, 실제 값은 `.env.local`에 둡니다.

## Runner 책임 경계

- `agent.max_concurrent_agents`는 동시에 처리할 Linear runner 수입니다.
- 한 Linear 이슈의 branch, commit, PR, Linear 댓글, Linear 상태 전환은 하나의 책임 Codex runner가 끝까지 맡습니다.
- 책임 runner 내부의 Codex subagent 사용은 허용합니다. subagent는 보조자이며 최종 책임자가 아닙니다.

## Hook 구분

- `.codex/hooks/**`: 실행 엔트리로 들어온 작업의 도구 실행 전후에 규칙을 검사하거나 차단합니다.
- Symphony 이슈별 작업공간 hook: Symphony가 이슈별 작업공간을 만들거나 실행하기 전에 repo와 branch를 준비합니다. 위치는 `.open-ai-symphony/custom/hooks/**`입니다.
