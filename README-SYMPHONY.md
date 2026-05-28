# Symphony 운영 안내

Symphony는 이 하네스에서 Linear 이슈를 workspace 단위로 실행하는 런타임입니다.

이 문서는 상위 안내만 다룹니다. 실행 흐름, hook, GitHub 인증, workflow 세부 내용은 `.open-ai-symphony/custom/` 아래 문서를 기준으로 봅니다.

## 기준 위치

- `.open-ai-symphony/custom/README.md`: Symphony custom entrypoint, hook, GitHub auth helper의 파일 단위 설명.
- `.open-ai-symphony/custom/WORKFLOW.md`: Linear tracker, Codex runner prompt, 완료 기준.
- `.open-ai-symphony/custom/AGENTS.md`: Symphony가 만든 workspace에 연결되는 최소 runner 계약.

## 위치 원칙

- 최상위에 별도 `SYMPHONY_AGENTS.md`나 `WORKFLOW.md`를 두지 않습니다.
- Symphony 전용 실행 계약과 hook은 `.open-ai-symphony/custom/` 아래에 둡니다.
- Codex 로컬 훅은 `.codex/hooks.json`과 `.codex/hooks/**`에 둡니다.
- 환경변수 스키마는 `.env.example`, 실제 값은 `.env.local`에 둡니다.
