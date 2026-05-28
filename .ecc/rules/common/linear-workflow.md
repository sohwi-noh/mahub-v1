# Linear Workflow

## Issue Creation Gate

Every new Linear issue must explicitly state whether it is covered by the agent
worklog contract.

Use this section in the issue description:

```md
## 이슈 발행 게이트

- Agent worklog 계약 대상: true|false
- 사유: <why this issue should or should not be enforced by the agent worklog hook>
```

If `Agent worklog 계약 대상` is `true`:

- Add the `agent-worklog` Linear label.
- Treat the issue as covered by the project-local Linear worklog hook.
- Add a Korean `작업 계획:` comment before file edits.
- Add a Korean `작업 결과:` comment before finishing after file edits.

If `Agent worklog 계약 대상` is `false`:

- Do not add the `agent-worklog` label.
- Include the reason in the issue description.
- Do not use broader labels such as `codex` to imply hook enforcement.

## Label Semantics

- `agent-worklog`: this issue requires agent work history to be recorded in
  Linear and is enforced by the project-local hook.
- `codex`: broad tooling or discussion label only. It must not enable the
  worklog hook by itself.

## State And PR Handoff

- `Symphony Ready` is a Symphony queue state, not a worklog hook marker.
- `In Review` means PR requested.
- If work is complete but no PR was created, add a Korean comment containing
  `확인 필요 사유:` or `PR 미진행 사유:` and move the issue to `확인 필요`.
- Once a Linear issue has moved to PR review or has a merged PR, do not add
  follow-up changes to the same issue. Create a related issue, a new branch, and
  a new PR instead.
