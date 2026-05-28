# ktds AX Eng. 하네스 에이전트 지침

이 파일은 저장소 전체에서 에이전트가 먼저 읽는 최상위 안내문입니다.
세부 기준의 원천은 `.ecc/rules/**`에 두고, 이 파일은 어떤 기준을 어디에 적용할지만 짧게 안내합니다.

## 운영 표면

- `.ecc/rules/**`: 팀 규칙의 원천입니다. Linear worklog, git/PR, 보안, 테스트 기준은 여기에 둡니다.
- `AGENTS.md`: 에이전트가 읽는 작업 안내입니다. 규칙의 위치와 우선순위를 설명합니다.
- `.codex/hooks/**`와 `.codex/hooks.json`: rules를 실제로 검사, 차단, 기록하는 실행 장치입니다. hook 안에 새 정책을 만들지 않습니다.
- `.open-ai-symphony/custom/**`: 팀 공유 Symphony 실행 진입점과 workspace hook입니다.

## 적용할 Rules

- 항상 `.ecc/rules/common/`을 적용합니다.
- Java, Maven, Gradle, Spring 계열 백엔드 작업에는 `.ecc/rules/java/`를 적용합니다.
- Next.js, React, TypeScript, JavaScript, HTML, CSS, 프론트엔드 작업에는 `.ecc/rules/typescript/`와 `.ecc/rules/web/`를 적용합니다.
- 언어/도메인 규칙이 공통 규칙과 충돌하면 더 구체적인 규칙을 우선합니다.

## 작업 방식

- 작업 전 범위, 영향, 검증 방법을 간단히 확인합니다.
- 시크릿은 `.env.local` 또는 외부 secret store에만 두고 코드나 문서에 하드코딩하지 않습니다.
- 새 정책이 필요하면 먼저 `.ecc/rules/**`에 기준을 두고, 필요한 경우 hook이 그 기준을 집행하게 합니다.
- 변경 후에는 작업 크기에 맞는 가장 가벼운 검증을 실행합니다.
- 새 최상위 문서를 만들기 전에는 기존 `README.md`, `README-ECC.md`, `README-SYMPHONY.md`, `.open-ai-symphony/custom/README.md` 중 들어갈 곳이 있는지 먼저 확인합니다.
