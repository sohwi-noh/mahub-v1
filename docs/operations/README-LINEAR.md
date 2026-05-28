# Linear 작업 로그 훅 경계

Linear 작업 로그 계약의 원천 규칙은 `.ecc/rules/common/linear-workflow.md`입니다.

- `agent-worklog` 라벨이 붙은 Linear 이슈만 에이전트 작업 로그 계약 대상입니다.
- `.codex/hooks/**`는 실행 엔트리로 들어온 대화형 작업의 선택적 누락 방지 장치입니다.
- `.codex/hooks/**`는 `agent-worklog` 라벨이 없거나 Linear 이슈 맥락이 없으면 기본적으로 기록하지 않습니다.
- Symphony 작업공간 훅은 `.open-ai-symphony/custom/hooks/**`에서 동작하며, `.symphony-workspaces/<이슈키>/`에서 실행되는 자율 에이전트 작업의 필수 감사 로그 장치입니다.
- Symphony 작업은 작업 시작/결과 댓글, PR 생성 여부, `In Review` 또는 `확인 필요` 상태 전환을 강하게 점검합니다.
- PR 요청 상태로 넘어간 이슈에는 후속 수정을 직접 추가하지 않고 연계 이슈와 새 PR로 이어갑니다.
