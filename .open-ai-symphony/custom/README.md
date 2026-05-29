# Symphony 커스텀 엔트리포인트

이 폴더는 이 저장소에서 팀이 공유하는 Symphony 커스텀 엔트리포인트를 담습니다.

upstream 런타임은 `.open-ai-symphony/elixir`에 둡니다. 이 폴더의 파일은 해당 런타임을 어떻게 실행할지, 이슈별 작업공간을 어떻게 준비할지, 하네스 공통 Git 인증을 어떻게 사용할지 정의합니다.

실행 엔트리로 들어온 작업의 정책 hook은 저장소 루트의 `.codex/hooks/**` 아래에 둡니다. 이 폴더는 Symphony 엔트리포인트와 Symphony 작업공간 hook 전용입니다.

`.open-ai-symphony/elixir` 아래의 `_build`, `deps`, `bin`, `log` 같은 Elixir 생성물은 `.open-ai-symphony/elixir/.gitignore`가 무시합니다.

## 파일

- `bin/tmux.sh`: 로컬 Symphony 생명주기 실행 진입점입니다.
  - `start`: Symphony를 지속 실행 tmux session으로 시작합니다.
  - `status`: tmux session 상태를 확인합니다.
  - `stop`: tmux session을 중지합니다.
  - `attach`: tmux session에 붙습니다.
  - `logs`: `.symphony-logs/symphony-*.log`를 출력합니다.
- `AGENTS.md`: Symphony가 만든 이슈별 작업공간에 연결되는 최소 실행자 계약입니다.
- `WORKFLOW.md`: 프로젝트별 Symphony workflow입니다.
- `bin/run.sh`: `custom/WORKFLOW.md` template를 checkout별 실제 경로로 렌더링한 뒤 `.open-ai-symphony/elixir/bin/symphony`를 시작합니다.
- `hooks/workspace-setup.sh`: `custom/WORKFLOW.md`의 `after_create`, `before_run` 시점에 호출되어 이슈별 작업공간의 repo와 branch를 준비합니다.
- `lib/git-askpass-harness-token.sh`: `HARNESS_GITHUB_TOKEN`으로 비대화형 HTTPS Git 인증을 처리하는 helper입니다.

## 하네스 Git 환경변수

작업 repo 연결 값은 Symphony 전용 설정이 아니라 하네스 공통 Git 설정입니다. 실제 토큰은 루트 `.env.local`에 둡니다.

- `HARNESS_TARGET_REPO_URL`: 하네스가 clone/push할 작업 repo의 GitHub HTTPS URL입니다. 예: `https://github.com/OWNER/REPO.git`
- `HARNESS_GITHUB_TOKEN`: 하네스 Git 인증용 GitHub 토큰입니다.
- `SYMPHONY_BRANCH_PREFIX`: 이슈 작업 branch prefix입니다. 기본값은 `codex/`입니다.

Symphony는 이 하네스 Git 설정을 소비해 이슈별 작업공간을 준비합니다. `HARNESS_TARGET_REPO_URL`과 `HARNESS_GITHUB_TOKEN`이 없거나 URL에 토큰을 직접 넣으면 시작하지 않습니다. 운영체제 credential helper와 project-local GitHub MCP connector에는 의존하지 않습니다.

## 호출 흐름

```text
.open-ai-symphony/custom/bin/tmux.sh start
  -> .open-ai-symphony/custom/bin/run.sh
    -> .symphony-logs/WORKFLOW.<mode>.generated.md
      -> .open-ai-symphony/elixir/bin/symphony
      -> .open-ai-symphony/custom/hooks/workspace-setup.sh after-create|before-run
        -> .open-ai-symphony/custom/lib/git-askpass-harness-token.sh
```
