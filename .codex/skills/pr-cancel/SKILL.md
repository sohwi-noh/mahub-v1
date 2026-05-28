---
name: pr-cancel
description: PR 취소, PR 닫기, pull request cancel/close, PR branch 삭제, GitHub PR 취소와 Linear 상태/댓글 동기화가 필요할 때 사용합니다.
---

# PR 취소

PR 흐름을 중단하고 이력을 남겨야 할 때 사용합니다.

## 목표

- 열린 PR, 남은 branch, 잘못된 Linear 상태를 방치하지 않습니다.
- 취소 전후 이력을 Linear에 남깁니다.
- 이미 merge된 PR은 취소하지 않습니다. 후속 이슈와 새 PR로 처리합니다.

## 절차

1. 대상을 확인합니다.
   - Linear 이슈키, PR 번호, branch 이름, base branch를 확인합니다.
   - 대상이 모호하면 GitHub 또는 Linear를 변경하기 전에 질문합니다.

2. PR 상태를 확인합니다.
   - PR이 열려 있으면 URL, 제목, head branch, base branch, 최신 head SHA를 확인합니다.
   - PR이 없으면 PR 생성 전 branch/work 취소로 기록합니다.
   - PR이 이미 merge 또는 close 상태이면 명시 요청 없이 다시 열거나 이력을 고치지 않습니다.

3. Git branch 경로를 중단합니다.
   - 취소 대상 작업에만 속한 로컬 미커밋 변경을 원복합니다.
   - 로컬 branch 삭제 전 다른 branch로 이동합니다.
   - 원격 branch는 취소 대상 PR/work에 속할 때만 삭제합니다.

4. PR이 있으면 닫습니다.
   - GitHub PR을 merge하지 않고 close합니다.
   - 도구가 지원하면 짧은 close 사유를 남깁니다.
   - PR 본문과 기존 이력은 보존합니다.

5. Linear를 업데이트합니다.
   - 한국어 댓글에 취소 사유, PR URL 또는 `PR 생성 전`, branch 삭제 결과, 필요한 후속 이슈를 남깁니다.
   - 작업을 폐기하면 이슈를 `Canceled`로 옮깁니다.
   - 사람이 추가 확인해야 하면 이슈를 `확인 필요`로 옮깁니다.

## 보고

아래 사실만 짧게 보고합니다.

- PR 취소 전후 상태
- branch 정리 결과
- Linear 이슈 상태/댓글 결과
- 남은 후속 작업
