# Custom Symphony Entrypoints

This folder contains the team custom Symphony entrypoints for this repository.

The upstream runtime lives in `.open-ai-symphony/elixir`. These files define how this project runs that runtime, prepares workspaces, and handles noninteractive GitHub auth.

Codex-owned hooks stay under the repository root `.codex/` directory. This folder is only for Symphony entrypoints and workspace hooks.

Elixir generated artifacts under `.open-ai-symphony/elixir` such as `_build`, `deps`, `bin`, and `log` are ignored by `.open-ai-symphony/elixir/.gitignore`.

## Files

- `bin/tmux.sh`: user entrypoint for local Symphony lifecycle.
  - `start`: run Symphony in a persistent tmux session.
  - `status`: check the tmux session.
  - `stop`: stop the tmux session.
  - `attach`: attach to the session.
  - `logs`: tail `.symphony-logs/symphony-*.log`.
- `AGENTS.md`: minimal runner contract linked into Symphony-created issue workspaces.
- `WORKFLOW.md`: project-specific Symphony workflow.
- `bin/run.sh`: starts `.open-ai-symphony/elixir/bin/symphony` with `custom/WORKFLOW.md`.
- `hooks/workspace-setup.sh`: called by `custom/WORKFLOW.md` on `after_create` and `before_run`.
- `lib/git-askpass-github-token.sh`: token helper used by the runner and workspace hook when `GH_TOKEN` or `GITHUB_TOKEN` is set.

## GitHub Env

GitHub values belong in the root `.env.local`, not in these scripts.

- `SYMPHONY_TARGET_REPO_URL`: remote URL for workspace repositories. If empty, the project root `origin` is used.
- `GH_TOKEN` or `GITHUB_TOKEN`: token for HTTPS Git operations.
- `GITHUB_USERNAME`: optional HTTPS username, defaults to `x-access-token`.
- `SYMPHONY_GITHUB_SSH_KEY`: optional SSH private key path when using SSH remotes.
- `SYMPHONY_BRANCH_PREFIX`: branch prefix for issue workspaces, defaults to `codex/`.

## Call Flow

```text
.open-ai-symphony/custom/bin/tmux.sh start
  -> .open-ai-symphony/custom/bin/run.sh
    -> .open-ai-symphony/elixir/bin/symphony .open-ai-symphony/custom/WORKFLOW.md
      -> .open-ai-symphony/custom/hooks/workspace-setup.sh after-create|before-run
        -> .open-ai-symphony/custom/lib/git-askpass-github-token.sh
```
