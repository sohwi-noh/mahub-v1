# Symphony Custom

팀별 Symphony 확장은 이 디렉터리에 둡니다.

기본 설치는 `.open-ai-symphony/elixir/WORKFLOW.md`를 사용합니다. 프로젝트별 workflow, workspace hook, repo routing은 여기에서 추가합니다.

현재 tracker 선택은 env가 담당합니다.

```bash
SYMPHONY_TRACKER_KIND=linear
SYMPHONY_TRACKER_KIND=github
```

GitHub Issues 모드는 label 기반 상태 모델을 사용합니다.

## 실행

```bash
.open-ai-symphony/custom/bin/run.sh doctor
.open-ai-symphony/custom/bin/run.sh poll
.open-ai-symphony/custom/bin/run.sh serve
```

tmux 실행은 다음 진입점을 사용합니다.

```bash
.open-ai-symphony/custom/bin/tmux.sh start
.open-ai-symphony/custom/bin/tmux.sh status
.open-ai-symphony/custom/bin/tmux.sh stop
```
