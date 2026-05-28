# ktds AX Eng. 하네스 에이전트 지침

이 파일은 저장소 전체에서 에이전트가 먼저 읽는 최상위 안내문입니다.
세부 기준의 원천은 `.ecc/rules/**`에 두고, 이 파일은 어떤 기준을 어디에 적용할지만 짧게 안내합니다.

## 어디에 무엇을 적나

- 팀 기준은 `.ecc/rules/**`에 적습니다. 예: Linear worklog, git/PR, 보안, 테스트 기준.
- 에이전트에게 “작업할 때 이렇게 읽고 움직여라”라고 알려줄 내용은 `AGENTS.md`에 적습니다.
- 실제로 검사하거나 막아야 하는 로직은 `.codex/hooks/**`와 `.codex/hooks.json`에 둡니다.
- hook에는 새 기준을 만들지 않습니다. 먼저 `.ecc/rules/**`에 기준을 적고, hook은 그 기준을 실행만 합니다.
- Symphony 실행 진입점과 Symphony가 호출하는 workspace hook만 `.open-ai-symphony/custom/**`에 둡니다.

## 적용할 Rules

- 항상 `.ecc/rules/common/`을 적용합니다.
- Java, Maven, Gradle, Spring 계열 백엔드 작업에는 `.ecc/rules/java/`를 적용합니다.
- Next.js, React, TypeScript, JavaScript, HTML, CSS, 프론트엔드 작업에는 `.ecc/rules/typescript/`와 `.ecc/rules/web/`를 적용합니다.
- 언어/도메인 규칙이 공통 규칙과 충돌하면 더 구체적인 규칙을 우선합니다.

## 작성 원칙

- 오버엔지니어링하지 않습니다. 지금 필요한 만큼만 작게 바꿉니다.
- 문서와 주석은 사람이 읽기 쉬운 한국어로 간결하게 씁니다.
- 새 구조를 만들기보다 기존 위치와 규칙을 먼저 사용합니다.
- 설명은 길게 늘리지 말고, 판단 기준과 실행 방법이 바로 보이게 씁니다.

## 변경 금지

- 에이전트는 `.ecc/rules/**`를 임의로 바꾸지 않습니다.
- `.ecc/rules/**` 변경은 사용자가 명시적으로 요청했을 때만 합니다.
- hook 정책을 바꿀 때도 먼저 사용자 확인을 받고 `.ecc/rules/**`의 기준부터 맞춥니다.

## 작업 방식

- 작업 전 범위, 영향, 검증 방법을 작업 위험도에 맞는 깊이로 확인합니다.
- 시크릿은 `.env.local` 또는 외부 secret store에만 두고 코드나 문서에 하드코딩하지 않습니다.
- 새 최상위 문서를 만들기 전에는 기존 문서 위치에 넣을 수 있는지 먼저 확인합니다.
