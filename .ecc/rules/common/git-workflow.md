# Git Workflow

## Commit Message Format
```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

Note: Attribution disabled globally via ~/.claude/settings.json.

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch

## Pull Request Title Rule

- PR titles MUST start with the Linear issue ID at the far left:
  - Format: `<ISSUE-ID> <concise issue summary>`
  - Example: `KTD-87 PR 제목 스타일을 ECC Git workflow 규칙에 고정`
- Do not use conventional commit prefixes or scopes in PR titles:
  - Wrong: `docs: add PR title rule`
  - Wrong: `docs(KTD-87): add PR title rule`
  - Wrong: `feat: KTD-87 PR title rule`
  - Wrong: `Codex/ktd 87`
- Commit messages still use conventional commit format. PR titles do not.
- Before opening or updating a PR, verify the title together with the base/head branch pair.
- If a tool creates a PR with the wrong title, edit the PR title immediately before moving the Linear issue to `In Review`.
- Only deviate from this rule when the user explicitly approves an exception, and record the exception in the PR body or Linear comment.

## Issue Branch and PR Safety

- One Linear issue maps to one active PR.
- The PR head branch must be that issue's own branch, for example `codex/ktd-81` for `KTD-81`.
- Push only to the branch for the issue currently being worked on.
- Do not push follow-up issue commits into another issue's branch.
- The PR base branch must be the integration branch, normally `main`, unless the user explicitly approves a stacked PR.
- Before creating or updating a PR, verify the base/head pair and diff:
  - `git branch --show-current`
  - `git diff --name-status origin/main...HEAD`
  - `gh pr view --json baseRefName,headRefName,state,url` when a PR already exists
- If a replacement PR is unavoidable, mark the older PR/Linear link as superseded and leave a Korean Linear comment explaining why.

## Linear Issue Transitions

- See [linear-workflow.md](./linear-workflow.md) for Linear issue creation,
  agent worklog labels, state transitions, and PR handoff rules.

> For the full development process (planning, TDD, code review) before git operations,
> see [development-workflow.md](./development-workflow.md).
