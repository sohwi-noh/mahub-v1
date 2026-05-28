# ktds-sdd

Codex, Symphony, ECC, Linear 작업 로그를 팀 단위로 운영하기 위한 공유 하네스입니다.

## 운영 기준

- 팀 기준은 `.ecc/rules/**`에 둡니다.
- 에이전트 작업 안내는 `AGENTS.md`에 둡니다.
- Codex 실행은 이 README를, ECC와 Symphony 세부 기준은 아래 문서 인덱스를 봅니다.

## 지침 우선순위

AGENTS.md는 적용 경로가 더 구체적일수록 우선합니다.

- 최상단 `AGENTS.md`: 저장소 전체 기본 규칙입니다.
- `.codex/AGENTS.md`: `.codex/` 하위 파일에만 추가로 적용됩니다.
- `.codex/` 안에서 규칙이 충돌하면 `.codex/AGENTS.md`를 우선합니다.
- `.open-ai-symphony/**/AGENTS.md`: `.open-ai-symphony/` 하위의 해당 Symphony 폴더 안 파일에만 추가로 적용됩니다.
- 그 외 저장소 파일에는 최상단 `AGENTS.md`만 적용됩니다.

## 문서 인덱스

- `docs/guide/README.md`: 처음 읽는 순서와 문서 역할 안내.
- `docs/operations/README-ECC.md`: ECC rules, skills, Java/TypeScript/Web 기준.
- `docs/operations/README-SYMPHONY.md`: Symphony 실행, Linear queue, 이슈별 작업공간 운영.
- `docs/operations/README-LINEAR.md`: Linear 작업 로그 hook 경계.

## 현재 구조

```
AGENTS.md                         # 워크스페이스 전체 작업 지침
README.md                         # Codex 시작점과 하네스 문서 인덱스
docs/guide/README.md              # 처음 읽는 문서 가이드
docs/operations/README-ECC.md     # ECC 규칙/스킬 안내
docs/operations/README-SYMPHONY.md # Symphony 운영 안내
docs/operations/README-LINEAR.md  # Linear 작업 로그 훅 안내
.env.example                      # 팀 공유 환경변수 스키마
entrypoint.sh                     # Codex 실행 엔트리포인트
.codex/                           # Codex 설정, hooks, agents, skills
.ecc/rules/                       # ECC 공통/언어별 규칙
.open-ai-symphony/custom/         # 팀 공유 Symphony 실행 구조와 이슈별 작업공간 hook
```

## Codex 시작

최상단 `entrypoint.sh`로 시작합니다.

```bash
./entrypoint.sh
```

이 스크립트는 repo root를 작업 위치로 고정하고, `.env`, `.env.local`을 읽은 뒤, `CODEX_HOME`을 이 저장소의 `.codex/`로 설정합니다.
