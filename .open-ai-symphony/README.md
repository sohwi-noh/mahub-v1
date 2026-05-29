# Symphony Harness

이 디렉터리는 `SPEC.md` 기준으로 다시 설치한 Symphony 하네스입니다.

현재 기본 구현은 Elixir이며, issue tracker는 env로 선택합니다.

```bash
SYMPHONY_TRACKER_KIND=linear
SYMPHONY_TRACKER_KIND=github
```

## 구조

- `SPEC.md`: upstream Symphony 서비스 스펙 원문입니다.
- `elixir/`: SPEC의 핵심 레이어를 구현한 Elixir 기본 런타임입니다.
- `custom/`: 팀별 workflow, hook, routing 확장 위치입니다.

## Tracker 선택

Linear와 GitHub Issues는 같은 `SymphonyElixir.Tracker` behaviour를 구현합니다.

- Linear: 상태 기반 workflow를 사용합니다.
- GitHub Issues: label 기반 workflow를 사용합니다.

GitHub Projects v2 상태 필드는 아직 기본 설치 범위에 포함하지 않습니다.
