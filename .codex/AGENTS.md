# ECC for Codex CLI

This supplements the root `AGENTS.md` with Codex-specific guidance.

## Model Recommendations

| Task Type | Recommended Model |
|-----------|------------------|
| Routine coding, tests, formatting | GPT 5.4 |
| Complex features, architecture | GPT 5.4 |
| Debugging, refactoring | GPT 5.4 |
| Security review | GPT 5.4 |

## Skills Discovery

Codex에서 자동 호출되어도 되는 project-local skill surface는
`.codex/skills/`입니다.

- `.codex/skills/<skill-name>/SKILL.md`: 현재 프로젝트에서 자동 호출 가능한
  선별 skill입니다.
- `.codex/.agents/skills/<skill-name>/SKILL.md`: ECC가 들고 온 원본/reference
  surface입니다. 자동 호출 대상으로 보지 않습니다.
- `.codex/skills/`에 없는 skill은 먼저 사람 판단으로 필요성을 확인한 뒤,
  필요한 경우에만 `.codex/.agents/skills/`에서 참조하거나 승격합니다.
- `.codex/.agents/skills/` 전체를 자동 로드 대상으로 설명하거나 대량
  승격하지 않습니다.
- 자동 호출 가능한 skill 목록은 파일 시스템의 `.codex/skills/*/SKILL.md`를
  기준으로 확인합니다.

## MCP Servers

project-local `.codex/config.toml`을 ECC의 기본 Codex baseline으로 봅니다. 현재 ECC baseline은 GitHub, Context7, Exa, Linear, Memory, Playwright, Sequential Thinking을 켭니다. Linear 이슈 관리와 기본 GitHub PR/branch 운영은 MCP를 사용합니다. 더 무거운 MCP는 실제 작업에 필요할 때만 `~/.codex/config.toml`에 둡니다.

실제 배포할 서비스의 배포/CI/CD 인증 토큰은 하네스 운영 MCP와 분리합니다. 서비스 repo는 여러 개가 될 수 있으므로 하네스 루트에 단일 service repo/token을 고정하지 않습니다. 서비스별 env 파일이나 배포 환경에서 `<SERVICE_NAME>_GITHUB_TOKEN`, `<SERVICE_NAME>_DEPLOY_TOKEN` 같은 이름으로 분리합니다.

ECC's canonical Codex section name is `[mcp_servers.context7]`. The launcher package remains `@upstash/context7-mcp`; only the TOML section name is normalized for consistency with `codex mcp list` and the reference config.

### Automatic config.toml merging

The sync script (`scripts/sync-ecc-to-codex.sh`) uses a Node-based TOML parser to safely merge ECC MCP servers into `~/.codex/config.toml`:

- **Add-only by default** — missing ECC servers are appended; existing servers are never modified or removed.
- **관리 대상 7개 서버** — GitHub, Playwright, Context7, Exa, Linear, Memory, Sequential Thinking.
- **Canonical naming** — ECC manages Context7 as `[mcp_servers.context7]`; legacy `[mcp_servers.context7-mcp]` entries are treated as aliases during updates.
- **Package-manager aware** — uses the project's configured package manager (npm/pnpm/yarn/bun) instead of hardcoding `pnpm`.
- **Drift warnings** — if an existing server's config differs from the ECC recommendation, the script logs a warning.
- **`--update-mcp`** — explicitly replaces all ECC-managed servers with the latest recommended config (safely removes subtables like `[mcp_servers.supabase.env]`).
- **User config is always preserved** — custom servers, args, env vars, and credentials outside ECC-managed sections are never touched.

## External Action Boundaries

Treat networked tools as read-only by default. Search, inspect, and draft freely within the user's requested scope, but require explicit user approval before posting, publishing, pushing, merging, opening paid jobs, dispatching remote agents, changing third-party resources, or modifying credentials.

When approval is ambiguous, produce a local plan or draft artifact instead of taking the external action. Preserve user config and private state unless the user specifically asks for a scoped change.

## Multi-Agent Support

Codex now supports multi-agent workflows behind the experimental `features.multi_agent` flag.

- Enable it in `.codex/config.toml` with `[features] multi_agent = true`
- Define project-local roles under `[agents.<name>]`
- Point each role at a TOML layer under `.codex/agents/`
- Use `/agent` inside Codex CLI to inspect and steer child agents

Sample role configs in this repo:
- `.codex/agents/explorer.toml` — read-only evidence gathering
- `.codex/agents/reviewer.toml` — correctness/security review
- `.codex/agents/docs-researcher.toml` — API and release-note verification

## Key Differences from Claude Code

| Feature | Claude Code | Codex CLI |
|---------|------------|-----------|
| Hooks | 8+ event types | Project-local hooks via `.codex/hooks.json` |
| Context file | CLAUDE.md + AGENTS.md | AGENTS.md only |
| Skills | Skills loaded via plugin | `.codex/skills/` only; `.codex/.agents/skills/` is reference-only |
| Commands | `/slash` commands | Instruction-based |
| Agents | Subagent Task tool | Multi-agent via `/agent` and `[agents.<name>]` roles |
| Security | Hook-based enforcement | Instruction + sandbox + project-local hooks |
| MCP | Full support | Supported via `config.toml` and `codex mcp add` |

## Security And Project-Local Hooks

Codex uses instruction-based enforcement, sandboxing, and this repository's
project-local hooks:
1. Always validate inputs at system boundaries
2. Never hardcode secrets — use environment variables
3. Run `npm audit` / `pip audit` before committing
4. Review `git diff` before every push
5. Use `sandbox_mode = "workspace-write"` in config
6. Treat `.codex/hooks.json` and `.codex/hooks/**` as execution devices for
   rules whose source of truth lives under `.ecc/rules/common/**`
