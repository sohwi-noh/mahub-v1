# ktds AX Eng. 하네스

`mahub-goal` 워크스페이스에서 Codex, Symphony, ECC, Linear 작업 로그를 팀 단위로 운영하기 위한 로컬/공유 하네스입니다.

## 문서 인덱스

- `README-ECC.md`: ECC 규칙, 스킬 원문, Mahub Java + Next.js 작업 기준.
- `README-SYMPHONY.md`: Symphony 실행 구조, Linear 연동, Codex runner/workspace 계약.
- `.open-ai-symphony/custom/README.md`: 실제 Symphony custom entrypoint와 hook 파일 설명.

## 현재 구조

```text
AGENTS.md                         # 워크스페이스 전체 작업 지침
README.md                         # 하네스 문서 인덱스
README-ECC.md                     # ECC 규칙/스킬 안내
README-SYMPHONY.md                # Symphony 운영 안내
.env.example                      # 팀 공유 환경변수 스키마
.codex/AGENTS.md                  # Codex에서 ECC를 쓰기 위한 보충 지침
.codex/config.toml                # Codex 로컬 설정
.codex/agents/*.toml              # Codex 하위 에이전트 역할 설정
.codex/hooks.json                 # Codex 프로젝트 로컬 훅 연결
.codex/hooks/                     # Linear worklog 등 Codex 훅 스크립트
.codex/.agents/                   # ECC 자동 적용/설치 메타데이터 surface
.ecc/rules/                       # ECC 공통/언어별 규칙
.open-ai-symphony/custom/         # 팀 공유 Symphony 엔트리포인트와 workspace hook
skills/                           # ECC 스킬 원문
.claude/commands/ecc.md           # Claude 호환 slash command 진입점
```

## 운영 표면 역할

- `.ecc/rules/**`: 팀 규칙의 원천입니다. Linear worklog, git/PR, 보안 같은 기준은 여기에 둡니다.
- `AGENTS.md`: Codex, Symphony, agent가 읽는 작업 안내입니다. 어떤 rules를 따를지와 경로별 우선순위를 설명합니다.
- `.codex/hooks/**`와 `.codex/hooks.json`: rules를 실제로 검사, 차단, 기록하는 실행 장치입니다. hook 안에 새 정책을 만들지 않습니다.

최상위에 별도 `SYMPHONY_AGENTS.md`나 `WORKFLOW.md`를 두지 않습니다. Symphony 전용 실행 계약은 `.open-ai-symphony/custom/` 아래에 모읍니다.
