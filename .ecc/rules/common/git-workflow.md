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

## Linear Issue Transitions

- Once a Linear issue has moved to PR review, do not add follow-up changes to the same issue. Create a related Linear issue, a new branch, and a new PR instead.
- In this workflow, `In Review` means PR requested.
- If the work result is acceptable but no PR was created, add a Korean comment explaining the PR-missing or PR-failure reason and move the issue to `확인 필요`.
- Only move an issue to `Done` after the PR has been merged or the requested PR outcome has otherwise been confirmed.

> For the full development process (planning, TDD, code review) before git operations,
> see [development-workflow.md](./development-workflow.md).
