# ECC 로컬 설정

이 저장소는 `mahub-goal` 워크스페이스에서 Everything Claude Code(ECC)를 Codex와 함께 쓰기 위한 로컬 설정/규칙 보관소입니다.

## 현재 구조

```text
AGENTS.md                 # 워크스페이스 전체 작업 지침
.codex/AGENTS.md          # Codex에서 ECC를 쓰기 위한 보충 지침
.codex/agents/*.toml      # Codex 하위 에이전트 역할 설정
.ecc/rules/common/        # 언어 공통 ECC 규칙
.ecc/rules/java/          # Java 전용 ECC 규칙
.ecc/rules/typescript/    # TypeScript/JavaScript 전용 ECC 규칙
.ecc/rules/web/           # Web/Frontend/Next.js 계열 ECC 규칙
skills/                   # ECC 스킬 원문
.claude/commands/ecc.md   # Claude 호환 slash command 진입점
```

## 스킬 사용 기준

- `skills/`에는 ECC 스킬 원문 232개가 들어 있습니다.
- 이 폴더는 현재 Codex 세션에 자동 로드된 스킬 목록이 아니라, 프로젝트 로컬 참조 자료입니다.
- 특정 스킬이 필요하면 `skills/<skill-name>/SKILL.md`를 읽고 필요한 부분만 적용합니다.
- Codex 자동 로드가 필요하면 선택한 스킬만 `~/.codex/skills` 쪽으로 설치하거나 등록할지 검토합니다.
- `skills/` 전체를 `.codex/skills`나 `~/.codex/skills`로 대량 이동/복사하지 않습니다.

## Mahub 대상 작업 가이드

Mahub 작업은 우선 Java, JSP, DB 중심으로 본다. Go, Python, Django, FastAPI 같은 다른 언어/프레임워크 스킬은 현재 기본 작업 범위에서 제외한다.

현재 로컬에서 실제 확인되는 slash command shim은 `.claude/commands/ecc.md` 하나입니다. 아래 커맨드는 ECC 문서/스킬에서 안내하는 작업 진입 표현이며, 현재 세션에서 직접 slash command로 동작하지 않으면 같은 의도를 자연어로 요청합니다.

| 하고 싶은 것 | 권장 요청 | 우선 참조 스킬 | 사용할 에이전트 |
| --- | --- | --- | --- |
| 새 기능 계획하기 | `/ecc:plan "인증 추가"` | `plan-orchestrate` | `planner` |
| 시스템 아키텍처 설계 | `/ecc:plan "인증 구조 설계" + architect 관점` | `plan-orchestrate`, `springboot-patterns`, `jpa-patterns` | `planner`, `architect` |
| Java 기능을 테스트 먼저 작성하며 구현 | `/tdd "인증 추가"` | `tdd-workflow`, `springboot-tdd`, `java-coding-standards` | `tdd-guide`, `java-reviewer` |
| JSP 화면/폼 변경 검토 | `/code-review "JSP 화면 변경 검토"` | `java-coding-standards`, `security-review`, `e2e-testing` | `java-reviewer`, `security-reviewer` |
| 방금 작성한 코드 리뷰 | `/code-review` | `java-coding-standards`, `security-review` | `java-reviewer`, `code-reviewer` |
| Java/Maven/Gradle 빌드 실패 수정 | `/build-fix` | `springboot-verification`, `verification-loop` | `java-build-resolver`, `build-error-resolver` |
| E2E 테스트 실행 | `/e2e` | `e2e-testing` | `e2e-runner` |
| 보안 취약점 찾기 | `/security-scan` | `springboot-security`, `security-review` | `security-reviewer`, `java-reviewer` |
| 사용하지 않는 코드 제거 | `/refactor-clean` | `verification-loop`, `java-coding-standards` | `refactor-cleaner`, `java-reviewer` |
| 문서 업데이트 | `/update-docs` | `coding-standards` | `doc-updater` |
| DB 스키마/쿼리 리뷰 | `/code-review "DB 변경 검토"` | `jpa-patterns`, `database-migrations`, `postgres-patterns`, `mysql-patterns` | `database-reviewer`, `java-reviewer` |

JSP 전용 스킬은 현재 `skills/`에서 별도로 확인되지 않습니다. JSP 작업은 Java 규칙, Spring/Servlet 보안 관점, 화면 입력값 검증, XSS 방지, E2E 검증을 함께 적용합니다.

## `.ecc/rules` 한글 요약

이 요약은 현재 워크스페이스의 `.ecc/rules` 하위 파일만 근거로 정리한 내용입니다. 플러그인 전체 기능 수나 외부 마켓플레이스 설명이 아니라, 실제 로컬에 들어와 있는 규칙 기준입니다.

### 전체 구성

- `common/`: 언어와 무관한 공통 작업 규칙 10개
- `java/`: Java 파일, Maven, Gradle 작업에 적용되는 Java 전용 규칙 5개
- `typescript/`: TypeScript/JavaScript 작업에 적용되는 규칙 5개
- `web/`: Web/Frontend/Next.js 계열 작업에 적용되는 규칙 7개
- 총 27개 규칙 파일로 구성되어 있습니다.

### 공통 규칙

- `agents.md`: 작업 유형별 에이전트 사용 기준입니다. 계획은 `planner`, 설계는 `architect`, TDD는 `tdd-guide`, 코드 리뷰는 `code-reviewer`, 보안 검토는 `security-reviewer`, 빌드 오류는 `build-error-resolver`를 우선 사용하도록 정의합니다. 이 규칙 파일 기준 사용 가능 에이전트는 11개입니다.
- `development-workflow.md`: 구현 전 조사와 재사용 검토를 먼저 하고, 계획 작성, TDD, 코드 리뷰, 커밋/푸시, 리뷰 전 확인 순서로 진행하는 흐름입니다.
- `coding-style.md`: 불변성을 최우선으로 두고, KISS/DRY/YAGNI 원칙을 따릅니다. 함수는 작게, 파일은 응집도 있게 유지하며, 오류 처리와 입력 검증을 명시적으로 수행합니다.
- `testing.md`: 최소 80% 테스트 커버리지를 목표로 하고, RED-GREEN-IMPROVE 흐름의 TDD를 권장합니다. 테스트는 Arrange-Act-Assert 구조와 설명적인 이름을 사용합니다.
- `code-review.md`: 코드 작성/수정 후, 공유 브랜치 커밋 전, 보안 민감 코드 변경 시 리뷰를 필수로 봅니다. CRITICAL은 병합 차단, HIGH는 병합 전 수정 권고로 분류합니다.
- `security.md`: 커밋 전 하드코딩된 시크릿, 입력 검증, SQL Injection, XSS, CSRF, 인증/인가, Rate Limit, 민감정보 노출 여부를 확인합니다.
- `git-workflow.md`: 커밋 메시지는 `<type>: <description>` 형식을 사용하고, PR은 전체 커밋 히스토리와 base 브랜치 대비 diff를 기준으로 작성합니다.
- `hooks.md`: `PreToolUse`, `PostToolUse`, `Stop` 훅의 용도를 설명합니다. 자동 승인 권한은 신뢰 가능한 계획에만 조심스럽게 사용하고, 위험한 skip 권한은 사용하지 않도록 합니다.
- `patterns.md`: 새 기능 구현 전 검증된 스켈레톤 프로젝트를 찾고, Repository Pattern과 일관된 API 응답 포맷을 사용하도록 안내합니다.
- `performance.md`: 작업 난이도에 따라 모델을 고르고, 큰 리팩터링이나 복잡한 디버깅은 컨텍스트 여유를 확보한 상태에서 진행하도록 합니다.

### Java 전용 규칙

- `java/coding-style.md`: `google-java-format` 또는 Checkstyle을 사용하고, 파일당 하나의 public top-level type을 둡니다. 값 타입에는 `record`, 필드에는 기본적으로 `final`, 공개 API에는 방어적 복사를 권장합니다.
- `java/patterns.md`: 데이터 접근은 Repository 인터페이스로 감싸고, 비즈니스 로직은 Service Layer에 둡니다. 의존성 주입은 필드 주입이 아니라 생성자 주입을 사용합니다.
- `java/testing.md`: JUnit 5, AssertJ, Mockito, Testcontainers를 기준 도구로 둡니다. `src/main/java` 구조를 `src/test/java`에서 미러링하고, JaCoCo 기준 80% 이상 커버리지를 목표로 합니다.
- `java/security.md`: 시크릿은 환경 변수나 Secret Manager를 사용하고, SQL은 항상 파라미터 바인딩으로 작성합니다. 인증/인가와 비밀번호 저장은 검증된 라이브러리와 bcrypt 또는 Argon2를 사용합니다.
- `java/hooks.md`: Java 파일과 Maven/Gradle 설정 변경 후 `google-java-format`, Checkstyle, `./mvnw compile` 또는 `./gradlew compileJava` 같은 후속 검사를 연결하는 기준입니다.

### TypeScript/Web 전용 규칙

- `typescript/`: TypeScript/JavaScript 코딩 스타일, 패턴, 테스트, 보안, 훅 기준입니다.
- `web/`: Web/Frontend/Next.js 계열의 코딩 스타일, 디자인 품질, 패턴, 성능, 테스트, 보안, 훅 기준입니다.

### 현재 로컬 기준으로 확인되는 것

- `.ecc/rules` 안에서 직접 확인되는 규칙 파일은 27개입니다.
- `common/agents.md` 기준 사용 가능 에이전트는 11개입니다.
- `skills/` 안에는 `SKILL.md`를 가진 스킬 원문 232개가 있습니다.
- Java 규칙 파일에는 `springboot-security`, `quarkus-security`, `security-review`, `java-coding-standards`, `jpa-patterns`, `springboot-tdd`, `quarkus-tdd`, `springboot-patterns`, `quarkus-patterns` 스킬 참조가 있습니다.
- `.ecc/rules`만으로는 플러그인 전체 에이전트/스킬/커맨드 수량을 검증하지 않습니다. 전체 수량은 별도 manifest나 설치 결과를 기준으로 확인해야 합니다.
