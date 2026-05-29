# Symphony Workspace Agent Contract

이 파일은 새 SPEC 기준 기본 설치의 workspace runner 계약입니다.

- tracker는 `SYMPHONY_TRACKER_KIND`로 선택합니다.
- Linear와 GitHub Issues 모두 같은 normalized issue 모델을 사용합니다.
- GitHub Issues는 label 기반 상태 모델을 사용합니다.
- 실제 agent 실행/PR 자동화는 다음 레이어에서 추가합니다.
