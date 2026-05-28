# ECC 운영 안내

ECC는 이 하네스에서 규칙과 스킬 레이어를 담당합니다.

이 문서는 위치 인덱스입니다. Java, TypeScript, Web 세부 기준은 README에 복사하지 않고 `.ecc/rules/**` 아래의 실제 rule 파일을 기준으로 봅니다.

## 스킬 사용 기준

- `.codex/skills/`: 이 프로젝트 Codex 세션에서 실제로 자동 로드되는 project-local skill surface입니다.
- `.codex/.agents/skills/`: ECC가 들고 온 원본 skill/reference surface입니다. 자동 로드 대상으로 보지 않습니다.
- 특정 스킬이 필요하면 먼저 `.codex/skills/<skill-name>/SKILL.md`를 확인합니다.
- `.codex/skills/`에 없는 스킬을 참고해야 할 때만 `.codex/.agents/skills/<skill-name>/SKILL.md`를 봅니다.
- Codex 자동 로드가 필요하면 선택한 스킬만 `.codex/skills/`에 추가합니다.
- 개인 PC 기준 경로인 `~/.codex/skills/`는 개발망 배포 기준 문서에서 사용하지 않습니다.
- `.codex/.agents/skills/` 전체를 `.codex/skills/`로 대량 이동/복사하지 않습니다.

## Rules 인덱스

### 공통

- `.ecc/rules/common/agents.md`
- `.ecc/rules/common/development-workflow.md`: Mahub 기본 작업 범위와 공통 개발 흐름.
- `.ecc/rules/common/coding-style.md`
- `.ecc/rules/common/testing.md`
- `.ecc/rules/common/code-review.md`
- `.ecc/rules/common/security.md`
- `.ecc/rules/common/git-workflow.md`
- `.ecc/rules/common/linear-workflow.md`
- `.ecc/rules/common/hooks.md`
- `.ecc/rules/common/patterns.md`
- `.ecc/rules/common/performance.md`

### Java

Java, Maven, Gradle, Spring 계열 작업은 아래 규칙을 봅니다.

- `.ecc/rules/java/coding-style.md`
- `.ecc/rules/java/patterns.md`
- `.ecc/rules/java/testing.md`
- `.ecc/rules/java/security.md`
- `.ecc/rules/java/hooks.md`

### TypeScript / JavaScript

TypeScript, JavaScript, React, Next.js 작업은 아래 규칙을 봅니다.

- `.ecc/rules/typescript/coding-style.md`
- `.ecc/rules/typescript/patterns.md`
- `.ecc/rules/typescript/testing.md`
- `.ecc/rules/typescript/security.md`
- `.ecc/rules/typescript/hooks.md`

### Web / Frontend

HTML, CSS, UI, 접근성, 성능, E2E가 걸린 프론트엔드 작업은 TypeScript 규칙과 함께 아래 규칙을 봅니다.

- `.ecc/rules/web/coding-style.md`
- `.ecc/rules/web/design-quality.md`
- `.ecc/rules/web/patterns.md`
- `.ecc/rules/web/testing.md`
- `.ecc/rules/web/security.md`
- `.ecc/rules/web/performance.md`
- `.ecc/rules/web/hooks.md`

## Command shim

현재 로컬에서 확인되는 Claude 호환 slash command shim은 `.claude/commands/ecc.md`입니다.

ECC 문서나 스킬에 적힌 slash command가 현재 세션에서 직접 동작하지 않으면, 같은 의도를 자연어로 요청합니다.
