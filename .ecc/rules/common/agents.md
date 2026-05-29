# Agent Orchestration

## 기본 구조

- 한 Linear 이슈는 한 Symphony/Codex runner가 끝까지 책임집니다.
- runner는 branch, commit, PR, Linear 댓글, Linear 상태 전환의 단일 책임자입니다.
- Symphony의 단일 runner 구조는 subagent 사용 금지가 아닙니다. 책임자를 하나로 고정한다는 뜻입니다.
- Symphony의 `agent.max_concurrent_agents`는 동시에 처리할 runner 수를 정하는 값으로 봅니다. Codex runner 내부 subagent 호출을 차단하는 정책으로 해석하지 않습니다.

## Subagent 사용 기준

- subagent는 runner 내부의 보조자입니다.
- subagent는 사용자, 이슈, 작업 계획에서 허용된 경우에만 조사, 설계 검토, 코드 리뷰, 테스트 관점 점검처럼 범위가 분리된 일을 도울 수 있습니다.
- subagent는 최종 판단, commit, push, PR 생성, Linear 상태 전환의 책임자가 아닙니다.
- runner는 subagent 결과를 검토한 뒤 자기 판단으로 반영합니다.

## 병렬 실행 기준

- 병렬 subagent는 기본값이 아닙니다.
- 병렬 실행은 사용자, 이슈, 작업 계획에서 명시했고, 서로 독립적인 보조 작업을 분리해도 책임 경계가 흐려지지 않을 때만 사용합니다.
- 병렬 실행을 하더라도 한 이슈의 최종 산출물, PR, Linear 보고는 runner 하나가 정리합니다.
- Symphony 실행 중 내부 subagent 호출 가능 여부에 의존하는 변경은 실제 실행 검증 결과를 Linear 댓글에 남깁니다.

## 금지

- Claude 전용 agent 경로나 전역 agent 목록을 이 프로젝트의 기본 기준으로 쓰지 않습니다.
- 하네스 제어면 변경을 subagent에게 위임하지 않습니다.
- PR/Linear/branch 책임을 여러 agent에게 나누지 않습니다.
