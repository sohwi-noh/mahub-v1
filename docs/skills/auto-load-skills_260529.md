# 자동 로드 스킬 표

이 문서는 현재 Codex 세션에서 자동 호출 대상으로 보는 `.codex/skills/*/SKILL.md` 목록입니다.

공식 GitHub 기준은 `https://github.com/affaan-m/ECC`입니다. 표의 자동 실행 적합도와 토큰 위험은 로컬 `SKILL.md` 설명을 기준으로 한 운영 판단입니다.

| 프로젝트 단계 | 스킬명 | 목적 | Symphony 자동 실행 적합 | 토큰 과다 위험 | 로컬 경로 | 공식 GitHub |
| --- | --- | --- | --- | --- | --- | --- |
| 분석 | agent-sort | repo에 맞는 ECC 설치 대상을 DAILY/LIBRARY로 선별 | 조건부 | 높음 | `.codex/skills/agent-sort/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/agent-sort |
| 분석 | code-tour | 실제 파일/라인에 앵커된 CodeTour 생성 | 조건부 | 중간 | `.codex/skills/code-tour/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/code-tour |
| 분석 | council | 모호한 의사결정에서 4개 관점으로 판단 정리 | 조건부 | 중간 | `.codex/skills/council/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/council |
| 분석 | iterative-retrieval | subagent context 문제를 줄이는 점진적 검색 패턴 | 적합 | 중간 | `.codex/skills/iterative-retrieval/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/iterative-retrieval |
| 분석 | skill-scout | 새 skill 작성 전 기존 local/marketplace/GitHub skill 탐색 | 조건부 | 높음 | `.codex/skills/skill-scout/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/skill-scout |
| 개발 | error-handling | TypeScript, Python, Go 에러 처리 패턴 | 적합 | 낮음 | `.codex/skills/error-handling/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/error-handling |
| 개발 | hookify-rules | hookify rule 작성과 설정 패턴 | 조건부 | 중간 | `.codex/skills/hookify-rules/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/hookify-rules |
| 개발 | plankton-code-quality | Plankton 기반 edit-time 품질 검사와 자동 수정 | 조건부 | 높음 | `.codex/skills/plankton-code-quality/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/plankton-code-quality |
| 개발 | tdd-workflow | 기능/버그/리팩터링 TDD 흐름과 커버리지 기준 | 조건부 | 높음 | `.codex/skills/tdd-workflow/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/tdd-workflow |
| 테스트 | ai-regression-testing | AI 개발 회귀 테스트 전략과 샌드박스 API 테스트 | 적합 | 중간 | `.codex/skills/ai-regression-testing/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/ai-regression-testing |
| 테스트 | e2e-testing | Playwright E2E 테스트 패턴, POM, CI, flaky 대응 | 적합 | 중간 | `.codex/skills/e2e-testing/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/e2e-testing |
| 테스트 | eval-harness | 평가 기반 개발과 Claude Code 세션 평가 체계 | 조건부 | 높음 | `.codex/skills/eval-harness/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/eval-harness |
| 테스트 | verification-loop | 단계별 검증 루프와 검증 리포트 | 적합 | 중간 | `.codex/skills/verification-loop/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/verification-loop |
| 테스트 | windows-desktop-e2e | Windows 데스크톱 E2E 테스트 패턴 | 조건부 | 높음 | `.codex/skills/windows-desktop-e2e/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/windows-desktop-e2e |
| 운영 | agent-introspection-debugging | 에이전트 실패 원인 캡처, 진단, 복구 리포트 작성 | 조건부 | 중간 | `.codex/skills/agent-introspection-debugging/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/agent-introspection-debugging |
| 운영 | configure-ecc | ECC skills/rules 설치와 검증 안내 | 부적합 | 높음 | `.codex/skills/configure-ecc/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/configure-ecc |
| 운영 | continuous-learning | v1 학습 추출. v2 사용 권장 | 부적합 | 중간 | `.codex/skills/continuous-learning/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/continuous-learning |
| 운영 | continuous-learning-v2 | 세션 관찰 기반 project-scoped instinct 학습 | 조건부 | 높음 | `.codex/skills/continuous-learning-v2/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/continuous-learning-v2 |
| 운영 | pr-cancel | PR 닫기, 브랜치 삭제, Linear 동기화 안내 | 조건부 | 낮음 | `.codex/skills/pr-cancel/SKILL.md` | 원본 확인 필요 |
| 운영 | production-audit | 출시 전/후 production readiness 감사 | 조건부 | 높음 | `.codex/skills/production-audit/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/production-audit |
| 운영 | skill-stocktake | skill/command 품질 감사와 stocktake | 조건부 | 높음 | `.codex/skills/skill-stocktake/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/skill-stocktake |
| 운영 | strategic-compact | 긴 작업 중 수동 context compact 제안 | 조건부 | 낮음 | `.codex/skills/strategic-compact/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/strategic-compact |
