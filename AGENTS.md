# Everything Claude Code (ECC) 에이전트 지침

이 저장소는 `mahub-goal` 워크스페이스에서 ECC 규칙, Codex 로컬 훅, Symphony 실행 계약을 함께 관리하는 하네스입니다.

ECC 번들 기준으로 전문 에이전트, 스킬, 커맨드, 훅 워크플로우를 제공하며, 이 파일은 최상위 작업 지침 역할을 합니다.

**버전:** 2.0.0-rc.1

## 핵심 원칙

1. **에이전트 우선:** 도메인 작업은 가능한 경우 목적에 맞는 전문 에이전트 관점으로 나눠 봅니다.
2. **테스트 주도:** 구현 전에 검증 기준을 먼저 세우고, 위험도가 있는 변경은 테스트로 고정합니다.
3. **보안 우선:** 보안을 타협하지 않고 외부 입력과 시크릿을 명확히 다룹니다.
4. **불변성:** 기존 객체를 직접 변경하기보다 새 값을 만들어 반환합니다.
5. **계획 후 실행:** 복잡한 기능이나 리팩터링은 작업 전 범위와 위험을 정리합니다.

## 프로젝트 로컬 ECC 규칙

프로젝트 규칙 원천은 `.ecc/rules/` 아래의 로컬 ECC 규칙입니다.

- 항상 `.ecc/rules/common/`을 적용합니다.
- Java, Maven, Gradle, Spring 계열 백엔드 작업에는 `.ecc/rules/java/`를 적용합니다.
- Next.js, React, TypeScript, JavaScript, HTML, CSS, 프론트엔드 작업에는 `.ecc/rules/typescript/`와 `.ecc/rules/web/`를 적용합니다.
- 언어/도메인 규칙이 공통 규칙과 충돌하면 더 구체적인 규칙을 우선합니다.
- Mahub 기본 작업 범위는 Java 백엔드와 Next.js/React/TypeScript 프론트엔드입니다.

## 사용 가능 에이전트

| 에이전트 | 목적 | 사용 시점 |
| --- | --- | --- |
| `planner` | 구현 계획 수립 | 복잡한 기능, 리팩터링 |
| `architect` | 시스템 설계와 확장성 검토 | 아키텍처 결정 |
| `tdd-guide` | 테스트 주도 개발 | 새 기능, 버그 수정 |
| `code-reviewer` | 코드 품질과 유지보수성 검토 | 코드 작성/수정 후 |
| `security-reviewer` | 취약점 탐지 | 커밋 전, 민감 코드 변경 |
| `build-error-resolver` | 빌드/타입 오류 해결 | 빌드 실패 시 |
| `e2e-runner` | Playwright E2E 테스트 | 핵심 사용자 흐름 검증 |
| `refactor-cleaner` | 미사용 코드 정리 | 코드 유지보수 |
| `doc-updater` | 문서와 codemap 업데이트 | 문서 업데이트 |
| `cpp-reviewer` | C/C++ 코드 리뷰 | C/C++ 프로젝트 |
| `cpp-build-resolver` | C/C++ 빌드 오류 해결 | C/C++ 빌드 실패 |
| `fsharp-reviewer` | F# 함수형 코드 리뷰 | F# 프로젝트 |
| `docs-lookup` | Context7 기반 문서 조회 | API/문서 확인 |
| `go-reviewer` | Go 코드 리뷰 | Go 프로젝트 |
| `go-build-resolver` | Go 빌드 오류 해결 | Go 빌드 실패 |
| `kotlin-reviewer` | Kotlin 코드 리뷰 | Kotlin/Android/KMP 프로젝트 |
| `kotlin-build-resolver` | Kotlin/Gradle 빌드 오류 해결 | Kotlin 빌드 실패 |
| `database-reviewer` | PostgreSQL/Supabase 검토 | 스키마 설계, 쿼리 최적화 |
| `python-reviewer` | Python 코드 리뷰 | Python 프로젝트 |
| `django-reviewer` | Django 코드 리뷰 | Django, DRF, ORM, 마이그레이션 |
| `django-build-resolver` | Django 빌드/마이그레이션/설정 오류 해결 | Django 실행, 의존성, 마이그레이션, collectstatic 실패 |
| `java-reviewer` | Java/Spring Boot 코드 리뷰 | Java/Spring Boot 프로젝트 |
| `java-build-resolver` | Java/Maven/Gradle 빌드 오류 해결 | Java 빌드 실패 |
| `loop-operator` | 자율 루프 실행 | 루프 실행, stall 감지, 개입 |
| `harness-optimizer` | 하네스 설정 튜닝 | 안정성, 비용, 처리량 개선 |
| `rust-reviewer` | Rust 코드 리뷰 | Rust 프로젝트 |
| `rust-build-resolver` | Rust 빌드 오류 해결 | Rust 빌드 실패 |
| `pytorch-build-resolver` | PyTorch 런타임/CUDA/학습 오류 해결 | PyTorch 빌드/학습 실패 |
| `mle-reviewer` | 운영 ML 파이프라인 검토 | ML 파이프라인, eval, serving, monitoring, rollback |
| `typescript-reviewer` | TypeScript/JavaScript 코드 리뷰 | TypeScript/JavaScript 프로젝트 |

## 에이전트 활용 기준

작업 유형에 따라 아래 관점을 우선 적용합니다.

- 복잡한 기능 요청: `planner`
- 코드 작성/수정 직후: `code-reviewer`
- 버그 수정 또는 새 기능: `tdd-guide`
- 아키텍처 결정: `architect`
- 보안 민감 코드: `security-reviewer`
- 자율 루프/루프 모니터링: `loop-operator`
- 하네스 안정성/비용 튜닝: `harness-optimizer`

서로 독립적인 작업은 병렬로 검토하거나 실행할 수 있습니다. 단, 실제 subagent 실행 가능 여부와 방식은 현재 실행 환경의 지침을 따릅니다.

## 보안 지침

커밋 전 반드시 확인합니다.

- API key, password, token 같은 시크릿을 하드코딩하지 않습니다.
- 모든 사용자 입력을 검증합니다.
- SQL injection은 parameterized query로 방지합니다.
- XSS 방지를 위해 HTML을 sanitize합니다.
- CSRF 보호를 활성화합니다.
- 인증과 인가를 검증합니다.
- endpoint에는 필요한 rate limit을 적용합니다.
- 오류 메시지에 민감정보가 노출되지 않게 합니다.

**시크릿 관리:** 시크릿은 환경변수나 secret manager를 사용합니다. 필수 시크릿은 시작 시 검증하고, 노출된 시크릿은 즉시 회전합니다.

**보안 이슈 발견 시:** 작업을 멈추고 보안 리뷰 관점으로 재검토합니다. CRITICAL 이슈를 먼저 수정하고, 노출된 시크릿을 회전하며, 유사 문제가 있는지 코드베이스를 확인합니다.

## 코딩 스타일

**불변성:** 기존 객체를 직접 변경하지 않습니다. 변경이 필요한 경우 새 복사본을 반환합니다.

**파일 구성:** 큰 파일 몇 개보다 작고 응집도 높은 파일을 선호합니다. 일반적으로 200-400줄, 최대 800줄을 기준으로 하며, 타입이 아니라 기능/도메인 기준으로 구성합니다.

**오류 처리:** 모든 계층에서 오류를 처리합니다. UI 코드에는 사용자 친화적인 메시지를 제공하고, 서버 측에는 상세 context를 기록합니다. 오류를 조용히 삼키지 않습니다.

**입력 검증:** 시스템 경계에서 모든 외부 입력을 검증합니다. 가능하면 schema 기반 검증을 사용하고, 명확한 메시지로 빠르게 실패합니다.

**코드 품질 체크리스트**

- 함수는 작게 유지합니다. 50줄 미만을 목표로 합니다.
- 파일은 집중된 책임을 갖게 합니다. 800줄을 넘기지 않습니다.
- 4단계 이상 깊은 중첩을 피합니다.
- 오류 처리를 명시하고 하드코딩된 값을 피합니다.
- 식별자는 읽기 쉽고 의도가 드러나게 짓습니다.

## 테스트 요구사항

**최소 커버리지 목표: 80%**

필요한 테스트 유형:

1. **Unit test:** 개별 함수, 유틸리티, 컴포넌트
2. **Integration test:** API endpoint, database operation
3. **E2E test:** 핵심 사용자 흐름

**TDD workflow**

1. 테스트를 먼저 작성합니다. RED 단계에서는 실패해야 합니다.
2. 최소 구현을 작성합니다. GREEN 단계에서는 통과해야 합니다.
3. 리팩터링합니다. IMPROVE 단계에서 커버리지와 회귀 여부를 확인합니다.

테스트 실패를 해결할 때는 테스트 격리, mock, 구현을 순서대로 확인합니다. 테스트 자체가 틀린 경우가 아니라면 테스트를 맞추기 위해 기대값을 임의로 낮추지 않습니다.

## 개발 워크플로우

1. **Plan:** 의존성과 위험을 확인하고 단계별 계획을 세웁니다.
2. **TDD:** 테스트를 먼저 작성하고 구현, 리팩터링을 진행합니다.
3. **Review:** 코드 리뷰 관점으로 CRITICAL/HIGH 이슈를 즉시 처리합니다.
4. **지식 기록 위치를 구분합니다.**
   - 개인 디버깅 메모, 선호, 임시 context: 자동 memory
   - 팀/프로젝트 지식, 아키텍처 결정, API 변경, runbook: 프로젝트 기존 문서 구조
   - 현재 작업 산출물이 이미 관련 문서나 주석을 포함하면 같은 내용을 중복 기록하지 않습니다.
   - 명확한 문서 위치가 없으면 새 최상위 파일을 만들기 전에 확인합니다.
5. **Commit:** Conventional commit 형식과 충분한 PR 요약을 사용합니다.

## Workflow Surface 정책

- `skills/`가 canonical workflow surface입니다.
- 새 workflow 기여는 우선 `skills/`에 둡니다.
- `commands/`는 legacy slash-entry 호환 surface입니다. migration 또는 cross-harness parity에 필요한 shim만 추가/수정합니다.

## Git 워크플로우

**커밋 형식:** `<type>: <description>`

사용 가능한 type: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

**PR workflow:** 전체 commit history와 base branch 대비 diff를 분석하고, 요약과 test plan을 작성한 뒤, push 시 `-u`를 사용합니다.

## 아키텍처 패턴

**API 응답 포맷:** success indicator, data payload, error message, pagination metadata를 포함하는 일관된 envelope를 사용합니다.

**Repository pattern:** 데이터 접근은 표준 interface 뒤에 캡슐화합니다. 비즈니스 로직은 구체 저장소가 아니라 추상 interface에 의존합니다.

**Skeleton project:** 새 구조를 만들기 전에 검증된 template을 찾고, 보안/확장성/적합성을 평가한 뒤 proven structure 안에서 반복 개선합니다.

## 성능

**Context 관리:** 큰 리팩터링과 다중 파일 기능 작업은 context window 마지막 20%에 진입하기 전에 정리합니다. 단일 수정, 문서, 단순 수정처럼 민감도가 낮은 작업은 더 높은 사용률도 허용됩니다.

**빌드 문제 해결:** 빌드 오류는 원인을 분석하고 작은 단위로 수정한 뒤 매 단계 검증합니다.

## 프로젝트 구조

```text
agents/          # 전문 subagent
skills/          # workflow skill과 domain knowledge
commands/        # slash command
hooks/           # trigger 기반 자동화
rules/           # 항상 따르는 공통/언어별 지침
scripts/         # cross-platform Node.js utility
mcp-configs/     # MCP server 설정
tests/           # test suite
```

`commands/`는 호환성을 위해 유지하지만, 장기 방향은 skills-first입니다.

## 성공 기준

- 테스트가 통과하고 80% 이상 커버리지를 만족합니다.
- 보안 취약점이 없습니다.
- 코드는 읽기 쉽고 유지보수 가능합니다.
- 성능이 허용 범위 안에 있습니다.
- 사용자 요구사항이 충족됩니다.
