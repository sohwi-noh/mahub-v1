# 참고 스킬 표

이 문서는 자동 호출 대상이 아닌 `.codex/.agents/skills/*/SKILL.md` 원본/reference 목록입니다.

필요한 경우에만 사람이 검토한 뒤 `.codex/skills/`로 승격합니다. 공식 GitHub 기준은 `https://github.com/affaan-m/ECC`입니다.

| 프로젝트 단계 | 스킬명 | 목적 | Symphony 자동 실행 적합 | 토큰 과다 위험 | 로컬 경로 | 공식 GitHub |
| --- | --- | --- | --- | --- | --- | --- |
| 분석 | agent-sort | repo에 맞는 ECC 설치 대상을 DAILY/LIBRARY로 선별 | 조건부 | 높음 | `.codex/.agents/skills/agent-sort/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/agent-sort |
| 분석 | deep-research | Exa/Firecrawl 기반 다중 출처 심층 리서치 | 조건부 | 높음 | `.codex/.agents/skills/deep-research/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/deep-research |
| 분석 | documentation-lookup | Context7 기반 최신 라이브러리/프레임워크 문서 조회 | 적합 | 중간 | `.codex/.agents/skills/documentation-lookup/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/documentation-lookup |
| 분석 | exa-search | Exa MCP 기반 웹/코드/회사/인물 검색 | 조건부 | 중간 | `.codex/.agents/skills/exa-search/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/exa-search |
| 분석 | market-research | 시장 조사, 경쟁 분석, 투자 실사, 산업 리서치 | 조건부 | 높음 | `.codex/.agents/skills/market-research/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/market-research |
| 설계 | api-design | REST API 리소스, 상태 코드, 페이지네이션, 에러 응답 설계 | 적합 | 중간 | `.codex/.agents/skills/api-design/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/api-design |
| 설계 | mcp-server-patterns | Node/TypeScript MCP 서버 도구, 리소스, 프롬프트 패턴 | 적합 | 중간 | `.codex/.agents/skills/mcp-server-patterns/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/mcp-server-patterns |
| 설계 | product-capability | PRD/로드맵을 구현 가능한 capability plan으로 변환 | 조건부 | 높음 | `.codex/.agents/skills/product-capability/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/product-capability |
| 개발 | backend-patterns | Node.js, Express, Next.js API 백엔드 패턴 | 적합 | 중간 | `.codex/.agents/skills/backend-patterns/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/backend-patterns |
| 개발 | bun-runtime | Bun 런타임, 패키지 매니저, 번들러, 테스트 러너 기준 | 적합 | 중간 | `.codex/.agents/skills/bun-runtime/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/bun-runtime |
| 개발 | coding-standards | 범용 코딩 컨벤션과 품질 리뷰 기준 | 적합 | 낮음 | `.codex/.agents/skills/coding-standards/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/coding-standards |
| 개발 | frontend-patterns | React, Next.js, 상태관리, 성능, UI 패턴 | 적합 | 중간 | `.codex/.agents/skills/frontend-patterns/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/frontend-patterns |
| 개발 | mle-workflow | ML 데이터 계약, 재현 학습, 평가, 배포, 모니터링 | 조건부 | 높음 | `.codex/.agents/skills/mle-workflow/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/mle-workflow |
| 개발 | nextjs-turbopack | Next.js 16+와 Turbopack 사용 기준 | 적합 | 중간 | `.codex/.agents/skills/nextjs-turbopack/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/nextjs-turbopack |
| 개발 | security-review | 인증, 입력, 시크릿, 결제/민감 기능 보안 체크 | 적합 | 높음 | `.codex/.agents/skills/security-review/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/security-review |
| 테스트 | e2e-testing | Playwright E2E 테스트 패턴, POM, CI, flaky 대응 | 적합 | 중간 | `.codex/.agents/skills/e2e-testing/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/e2e-testing |
| 테스트 | eval-harness | 평가 기반 개발과 Claude Code 세션 평가 체계 | 조건부 | 높음 | `.codex/.agents/skills/eval-harness/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/eval-harness |
| 테스트 | tdd-workflow | 기능/버그/리팩터링 TDD 흐름과 커버리지 기준 | 조건부 | 높음 | `.codex/.agents/skills/tdd-workflow/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/tdd-workflow |
| 테스트 | verification-loop | 단계별 검증 루프와 검증 리포트 | 적합 | 중간 | `.codex/.agents/skills/verification-loop/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/verification-loop |
| 배포 | dmux-workflows | dmux/tmux 기반 다중 에이전트 오케스트레이션 | 조건부 | 높음 | `.codex/.agents/skills/dmux-workflows/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/dmux-workflows |
| 배포 | everything-claude-code | ECC 저장소 자체 개발 컨벤션 | 부적합 | 중간 | `.codex/.agents/skills/everything-claude-code/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/everything-claude-code |
| 모니터링 | agent-introspection-debugging | 에이전트 실패 원인 캡처, 진단, 복구 리포트 작성 | 조건부 | 중간 | `.codex/.agents/skills/agent-introspection-debugging/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/agent-introspection-debugging |
| 모니터링 | strategic-compact | 긴 작업 중 수동 context compact 제안 | 조건부 | 낮음 | `.codex/.agents/skills/strategic-compact/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/strategic-compact |
| 문서화 | article-writing | 글, 가이드, 블로그, 뉴스레터 장문 작성 | 조건부 | 높음 | `.codex/.agents/skills/article-writing/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/article-writing |
| 문서화 | brand-voice | 실제 글/문서에서 브랜드 보이스 프로필 추출 | 조건부 | 높음 | `.codex/.agents/skills/brand-voice/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/brand-voice |
| 문서화 | content-engine | X, LinkedIn, TikTok, YouTube 등 플랫폼별 콘텐츠 시스템 | 조건부 | 높음 | `.codex/.agents/skills/content-engine/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/content-engine |
| 문서화 | crosspost | X, LinkedIn, Threads, Bluesky 교차 게시물 변환 | 조건부 | 중간 | `.codex/.agents/skills/crosspost/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/crosspost |
| 문서화 | fal-ai-media | fal.ai MCP 기반 이미지, 비디오, 오디오 생성 | 조건부 | 높음 | `.codex/.agents/skills/fal-ai-media/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/fal-ai-media |
| 문서화 | frontend-slides | HTML 기반 애니메이션 프레젠테이션 제작 | 조건부 | 높음 | `.codex/.agents/skills/frontend-slides/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/frontend-slides |
| 문서화 | investor-materials | 피치덱, 원페이저, 투자자 메모, 재무 모델 작성 | 조건부 | 높음 | `.codex/.agents/skills/investor-materials/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/investor-materials |
| 문서화 | investor-outreach | 투자자 콜드메일, 소개 문구, 팔로업, 업데이트 작성 | 조건부 | 중간 | `.codex/.agents/skills/investor-outreach/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/investor-outreach |
| 문서화 | video-editing | AI 보조 비디오 편집, FFmpeg, Remotion, 후반 작업 | 조건부 | 높음 | `.codex/.agents/skills/video-editing/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/video-editing |
| 문서화 | x-api | X/Twitter API 게시, 검색, OAuth, rate limit 패턴 | 조건부 | 중간 | `.codex/.agents/skills/x-api/SKILL.md` | https://github.com/affaan-m/ECC/tree/main/skills/x-api |
