#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ISSUE_RE = /\b[A-Z][A-Z0-9]+-\d+\b/;
const PLAN_RE = /(work plan|plan:|작업\s*계획|계획\s*:)/i;
const RESULT_RE = /(work result|result:|작업\s*결과|결과\s*:)/i;
const PR_MISSING_REASON_RE =
  /(확인\s*필요\s*사유|PR\s*미진행\s*사유|PR\s*실패\s*사유|pull request\s+(not created|failed)|pr\s+(not created|failed))/i;
const NEEDS_REVIEW_STATUS = "확인 필요";
const PR_LINK_RE = /https:\/\/github\.com\/[^\s)]+\/[^\s)]+\/pull\/\d+/i;
const MODIFYING_TOOLS = new Set([
  "apply_patch",
  "Write",
  "Edit",
  "MultiEdit",
  "Bash",
  "shell_command",
  "local_shell",
  "unified_exec",
]);

main().catch((error) => {
  console.error(error && error.message ? error.message : String(error));
  process.exit(1);
});

async function main() {
  const phase = process.argv[2] || "";
  const input = readStdinJson();
  const cwd = input.cwd || process.cwd();
  const state = readState(cwd);
  const sessionId = input.session_id || "unknown-session";

  if (phase === "user-prompt-submit") {
    await handleUserPromptSubmit(input, cwd, state, sessionId);
    return;
  }

  if (phase === "pre-tool-use") {
    await handlePreToolUse(input, cwd, state, sessionId);
    return;
  }

  if (phase === "post-tool-use") {
    handlePostToolUse(input, cwd, state, sessionId);
    return;
  }

  if (phase === "stop") {
    await handleStop(input, cwd, state, sessionId);
  }
}

async function handleUserPromptSubmit(input, cwd, state, sessionId) {
  const prompt = input.prompt || "";
  const issueId = findIssueId(prompt) || findIssueId(currentBranch(cwd));
  if (!issueId) {
    return;
  }

  const issue = await fetchIssue(issueId, false);
  const agentAssigned = issue ? isCodexAssigned(issue) : false;
  const agentIdsConfigured = codexAgentIds().size > 0;
  state.sessions = state.sessions || {};
  state.sessions[sessionId] = {
    issueId,
    agentAssigned,
    changed: false,
    startedAt: new Date().toISOString(),
  };
  writeState(cwd, state);

  if (agentAssigned) {
    writeJson({
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext:
          `Linear ${issueId} is delegated to Codex. Before editing files, add a Korean Linear comment containing "작업 계획:". After changes, add a Korean Linear comment containing "작업 결과:".`,
      },
    });
  } else if (issue && !agentIdsConfigured) {
    writeJson({
      hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext:
          "CODEX_LINEAR_AGENT_IDS is not set. Codex-specific Linear worklog enforcement is disabled for this session. Set CODEX_LINEAR_AGENT_IDS in .env.local before delegating Linear issues to Codex.",
      },
    });
  }
}

async function handlePreToolUse(input, cwd, state, sessionId) {
  if (!isModifyingTool(input)) {
    return;
  }

  const serialized = JSON.stringify(input.tool_input || {});
  if (serialized.includes(".ecc/rules/") || serialized.includes(".ecc/rules")) {
    block(
      "Protected path policy: .ecc/rules/** changes require explicit approval before editing.",
    );
    return;
  }

  const session = activeSession(state, sessionId);
  if (!session || !session.agentAssigned || !session.issueId) {
    return;
  }

  const issue = await fetchIssue(session.issueId, true);
  if (!issue) {
    writeJson({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext:
          `Could not verify Linear ${session.issueId}. Confirm the work plan comment before editing.`,
      },
    });
    return;
  }

  if (!hasComment(issue, PLAN_RE)) {
    block(
      `Linear ${session.issueId} is delegated to Codex. Add a Korean Linear comment containing "작업 계획:" before editing files.`,
    );
  }
}

function handlePostToolUse(input, cwd, state, sessionId) {
  if (!isModifyingTool(input)) {
    return;
  }

  const session = activeSession(state, sessionId);
  if (!session || !session.agentAssigned) {
    return;
  }

  session.changed = true;
  session.changedAt = new Date().toISOString();
  writeState(cwd, state);
}

async function handleStop(input, cwd, state, sessionId) {
  const session = activeSession(state, sessionId);
  if (!session || !session.agentAssigned || !session.issueId || !session.changed) {
    return;
  }

  const issue = await fetchIssue(session.issueId, true);
  if (!issue) {
    block(
      `Could not verify Linear ${session.issueId}. Add a Korean result comment containing "작업 결과:" before finishing.`,
    );
    return;
  }

  if (!hasComment(issue, RESULT_RE)) {
    block(
      `Linear ${session.issueId} is delegated to Codex and files changed. Add a Korean Linear comment containing "작업 결과:" before finishing.`,
    );
  }

  if (!hasPullRequestReference(issue)) {
    const statusName = issueStatusName(issue);
    const hasMissingReason = hasComment(issue, PR_MISSING_REASON_RE);

    if (statusName !== NEEDS_REVIEW_STATUS || !hasMissingReason) {
      block(
        `Linear ${session.issueId} has "작업 결과:" but no PR link. Before finishing, move the issue to "${NEEDS_REVIEW_STATUS}" and add a Korean comment containing "확인 필요 사유:" or "PR 미진행 사유:".`,
      );
    }
  }
}

function readStdinJson() {
  const raw = fs.readFileSync(0, "utf8").trim();
  if (!raw) {
    return {};
  }
  return JSON.parse(raw);
}

function readState(cwd) {
  const file = statePath(cwd);
  if (!fs.existsSync(file)) {
    return { sessions: {} };
  }
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return { sessions: {} };
  }
}

function writeState(cwd, state) {
  const file = statePath(cwd);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(state, null, 2)}\n`);
}

function statePath(cwd) {
  return path.join(cwd, ".codex", "state", "linear-worklog.json");
}

function activeSession(state, sessionId) {
  return state.sessions && state.sessions[sessionId];
}

function findIssueId(value) {
  const match = String(value || "").match(ISSUE_RE);
  return match ? match[0] : null;
}

function currentBranch(cwd) {
  try {
    return execFileSync("git", ["branch", "--show-current"], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch {
    return "";
  }
}

function isModifyingTool(input) {
  const toolName = input.tool_name || "";
  if (MODIFYING_TOOLS.has(toolName)) {
    return true;
  }

  const serialized = JSON.stringify(input.tool_input || {});
  return /(^|[^A-Za-z])(apply_patch|cat >|tee |>|>>|mv |cp |touch |mkdir |rm )/.test(
    serialized,
  );
}

async function fetchIssue(issueId, includeComments) {
  const mock = process.env.LINEAR_WORKLOG_MOCK_ISSUE_JSON;
  if (mock) {
    return JSON.parse(mock);
  }

  const token = process.env.LINEAR_API_KEY;
  if (!token) {
    return null;
  }

  const query = includeComments
    ? `query Issue($id: String!) {
        issue(id: $id) {
          identifier
          title
          state { name type }
          assignee { id name displayName }
          delegate { id name displayName }
          attachments(first: 50) {
            nodes { title url }
          }
          comments(first: 50) {
            nodes { body createdAt }
          }
        }
      }`
    : `query Issue($id: String!) {
        issue(id: $id) {
          identifier
          title
          state { name type }
          assignee { id name displayName }
          delegate { id name displayName }
        }
      }`;

  const response = await fetch("https://api.linear.app/graphql", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: token,
    },
    body: JSON.stringify({ query, variables: { id: issueId } }),
  });

  if (!response.ok) {
    return null;
  }

  const payload = await response.json();
  if (payload.errors && payload.errors.length) {
    return null;
  }
  return payload.data && payload.data.issue ? payload.data.issue : null;
}

function isCodexAssigned(issue) {
  const ids = codexAgentIds();
  if (ids.size === 0) {
    return false;
  }

  const people = [issue.assignee, issue.delegate].filter(Boolean);
  return people.some((person) => ids.has(person.id));
}

function codexAgentIds() {
  return new Set(
    (process.env.CODEX_LINEAR_AGENT_IDS || "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

function hasComment(issue, regex) {
  const comments =
    issue.comments && Array.isArray(issue.comments.nodes)
      ? issue.comments.nodes
      : [];
  return comments.some((comment) => regex.test(comment.body || ""));
}

function issueStatusName(issue) {
  if (typeof issue.status === "string") {
    return issue.status;
  }
  if (issue.state && typeof issue.state.name === "string") {
    return issue.state.name;
  }
  return "";
}

function hasPullRequestReference(issue) {
  const attachments = issueAttachments(issue);
  const attachmentHasPr = attachments.some((attachment) =>
    PR_LINK_RE.test(`${attachment.title || ""} ${attachment.url || ""}`),
  );
  if (attachmentHasPr) {
    return true;
  }

  const comments =
    issue.comments && Array.isArray(issue.comments.nodes)
      ? issue.comments.nodes
      : [];
  return comments.some((comment) => PR_LINK_RE.test(comment.body || ""));
}

function issueAttachments(issue) {
  if (Array.isArray(issue.attachments)) {
    return issue.attachments;
  }
  if (issue.attachments && Array.isArray(issue.attachments.nodes)) {
    return issue.attachments.nodes;
  }
  return [];
}

function block(reason) {
  console.error(reason);
  process.exit(2);
}

function writeJson(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}
