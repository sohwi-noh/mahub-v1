# Linear 워크플로우

## 이슈 발행 게이트

새 Linear 이슈는 agent worklog 계약 대상인지 반드시 본문에 명시합니다.

이슈 본문에는 아래 섹션을 넣습니다.

```md
## 이슈 발행 게이트

- Agent worklog 계약 대상: true|false
- 사유: <이 이슈가 agent worklog 훅 강제 대상인지 아닌지에 대한 이유>
```

`Agent worklog 계약 대상`이 `true`이면 아래 기준을 따릅니다.

- Linear 이슈에 `agent-worklog` 라벨을 붙입니다.
- 프로젝트 로컬 Linear worklog 훅 적용 대상으로 봅니다.
- 파일 편집 전에 한국어 `작업 계획:` 댓글을 남깁니다.
- 파일 변경 후 종료하기 전에 한국어 `작업 결과:` 댓글을 남깁니다.

`Agent worklog 계약 대상`이 `false`이면 아래 기준을 따릅니다.

- `agent-worklog` 라벨을 붙이지 않습니다.
- 이슈 본문에 false 사유를 남깁니다.
- `codex`처럼 범위가 넓은 라벨로 훅 강제 적용을 암시하지 않습니다.

## 라벨 의미

- `agent-worklog`: 이 이슈는 에이전트 작업 이력을 Linear에 남겨야 하며, 프로젝트 로컬 훅 강제 대상입니다.
- `codex`: 도구나 논의 범위를 표시하는 넓은 라벨입니다. 이 라벨만으로 worklog 훅을 켜지 않습니다.

## 훅 책임 경계

Linear 작업 로그 훅은 실행 경로에 따라 책임을 나눕니다.

`.codex/hooks/**`는 실행 엔트리로 들어온 대화형 작업에 적용합니다.

- 대화형 작업의 선택적 누락 방지 장치입니다.
- Linear 이슈에 `agent-worklog` 라벨이 있을 때만 작업 계획, 작업 결과, PR 미진행 사유 누락을 점검합니다.
- `agent-worklog` 라벨이 없거나 Linear 이슈 맥락이 없으면 기본적으로 동작하지 않습니다.
- 사용자의 모든 프롬프트나 수동 판단을 자동으로 Linear에 기록하지 않습니다.
- 훅은 가볍게 유지하고, 판단 기준의 원천은 이 문서에 둡니다.

Symphony 작업공간 훅은 `.open-ai-symphony/custom/hooks/**`에 둡니다.

- Symphony가 `Symphony Ready` 상태 이슈를 잡아 `.symphony-workspaces/<이슈키>/` 작업공간에서 실행할 때의 필수 감사 로그 장치입니다.
- `agent-worklog` 계약 대상 이슈는 작업 시작 댓글, 작업 결과 댓글, PR 생성 여부, 상태 전환을 강하게 점검합니다.
- 작업 결과가 있는데 PR을 만들지 못하면 실패 사유를 댓글로 남기고 `확인 필요` 상태로 넘기는 것을 강제합니다.
- PR 요청 상태로 넘어간 이슈에는 후속 수정을 직접 추가하지 않고 연계 이슈로 이어갑니다.

공통 원칙은 `.ecc/rules/common/linear-workflow.md`에 두고, 각 훅 구현에는 해당 실행 컨텍스트에서 강제 가능한 최소 동작만 둡니다.

## 상태와 PR 인계

- `Symphony Ready`는 Symphony queue 상태이며, worklog 훅 marker가 아닙니다.
- `In Review`는 PR 요청 상태로 사용합니다.
- 작업 결과는 완료됐지만 PR을 만들지 못했다면 `확인 필요 사유:` 또는 `PR 미진행 사유:`가 들어간 한국어 댓글을 남기고 이슈를 `확인 필요`로 옮깁니다.
- 한 번 PR review로 넘어갔거나 PR이 merge된 이슈에는 후속 변경을 추가하지 않습니다. 연계 이슈, 새 branch, 새 PR로 이어갑니다.
