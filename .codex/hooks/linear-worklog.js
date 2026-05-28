#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const DEFAULT_CODEX_LINEAR_ID = "39aadd4d-47b0-4cd1-abf9-7ec2187baf78";
const ISSUE_RE = /\b[A-Z][A-Z0-9]+-\d+\b/;
const PLAN_RE = /(work plan|plan:|작업\s*계획|계획\s*:)/i;
const RESULT_RE = /(work result|result:|작업\s*결과|결과\s*:)/i;
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
          assignee { id name displayName }
          delegate { id name displayName }
          comments(first: 50) {
            nodes { body createdAt }
          }
        }
      }`
    : `query Issue($id: String!) {
        issue(id: $id) {
          identifier
          title
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
  const ids = new Set(
    (process.env.CODEX_LINEAR_AGENT_IDS || DEFAULT_CODEX_LINEAR_ID)
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );

  const people = [issue.assignee, issue.delegate].filter(Boolean);
  return people.some((person) => {
    const name = `${person.name || ""} ${person.displayName || ""}`.toLowerCase();
    return ids.has(person.id) || /\bcodex\b/.test(name);
  });
}

function hasComment(issue, regex) {
  const comments =
    issue.comments && Array.isArray(issue.comments.nodes)
      ? issue.comments.nodes
      : [];
  return comments.some((comment) => regex.test(comment.body || ""));
}

function block(reason) {
  console.error(reason);
  process.exit(2);
}

function writeJson(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}
