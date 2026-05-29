# Symphony Elixir

SPEC 기준 기본 Elixir 설치입니다. 기존 커스텀 런타임을 복구하지 않고, tracker adapter를 분리한 최소 실행 구조로 다시 시작합니다.

## 실행

```bash
cd .open-ai-symphony/elixir
mise exec -- mix deps.get
mise exec -- mix test
mise exec -- mix escript.build
mise exec -- ./bin/symphony doctor ./WORKFLOW.md
mise exec -- ./bin/symphony poll ./WORKFLOW.md
mise exec -- ./bin/symphony serve ./WORKFLOW.md
```

`serve`는 현재 tracker polling daemon의 기본 골격입니다. agent 실행/PR 자동화는 다음 레이어에서 붙입니다.

## Tracker

`WORKFLOW.md`의 `tracker.kind`는 env 값을 사용할 수 있습니다.

```yaml
tracker:
  kind: $SYMPHONY_TRACKER_KIND
```

지원 값:

- `linear`
- `github`

## GitHub Issues 상태 모델

GitHub Issues는 Linear처럼 커스텀 상태가 없으므로 label을 상태로 사용합니다.

- ready label: dispatch 후보
- running label: 작업 중
- review label: PR 요청 또는 검토 상태
- done label: 완료 표시

기본 설치는 GitHub Projects v2 status field를 다루지 않습니다.
