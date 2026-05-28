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

## 상태와 PR 인계

- `Symphony Ready`는 Symphony queue 상태이며, worklog 훅 marker가 아닙니다.
- `In Review`는 PR 요청 상태로 사용합니다.
- 작업 결과는 완료됐지만 PR을 만들지 못했다면 `확인 필요 사유:` 또는 `PR 미진행 사유:`가 들어간 한국어 댓글을 남기고 이슈를 `확인 필요`로 옮깁니다.
- 한 번 PR review로 넘어갔거나 PR이 merge된 이슈에는 후속 변경을 추가하지 않습니다. 연계 이슈, 새 branch, 새 PR로 이어갑니다.
