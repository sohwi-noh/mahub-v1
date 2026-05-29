# ktds-sdd Symphony 실행자 지침

이 파일은 Symphony가 만든 이슈별 workspace에 `AGENTS.md`로 복사되거나 연결됩니다.

## 우선순위

Symphony workspace 안에서는 아래 파일을 실행 계약으로 봅니다.

1. `WORKFLOW.md`
2. `SYMPHONY_WORKSPACE.md`
3. 이 `AGENTS.md`
4. `SYMPHONY_WORKSPACE.md`의 `Target repo dir` 아래 대상 저장소의 지침

## 실행 계약

- 하나의 Linear 이슈는 하나의 책임 Codex runner가 끝까지 맡습니다.
- runner는 branch, commit, PR, Linear 댓글, Linear 상태 전환의 최종 책임자입니다.
- 필요하면 runner 내부에서 Codex subagent를 보조자로 사용할 수 있습니다.
- subagent는 최종 판단, commit, push, PR 생성, Linear 상태 전환의 책임자가 아닙니다.
- 루프를 작게 유지합니다. 계획, 구현, 검증, 보고 순서로 진행합니다.
- product 또는 workflow 변경은 `SYMPHONY_WORKSPACE.md`의 `Target repo dir` 안에서만 수행합니다.
- Symphony workspace 밖에는 쓰지 않습니다.
- Linear 이슈가 명시적으로 요구하지 않는 한 별도 보고 구조나 추가 orchestration 정책을 만들지 않습니다.
