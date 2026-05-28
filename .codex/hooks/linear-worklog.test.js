#!/usr/bin/env node

const assert = require("assert");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..", "..");
const hookScript = path.join(repoRoot, ".codex", "hooks", "linear-worklog.js");

const tests = [
  [
    "blocks file edits when the Linear issue has the codex label and no plan comment",
    () => {
      const cwd = tempCwd();
      const sessionId = "labeled-session";
      const issue = {
        identifier: "KTD-77",
        labels: { nodes: [{ name: "codex" }] },
      };

      runHook("user-prompt-submit", {
        cwd,
        session_id: sessionId,
        prompt: "KTD-77 작업 진행",
      }, issue);

      const result = runHook("pre-tool-use", {
        cwd,
        session_id: sessionId,
        tool_name: "apply_patch",
        tool_input: { path: "README.md" },
      }, {
        ...issue,
        state: { name: "In Progress" },
        comments: { nodes: [] },
      });

      assert.strictEqual(result.status, 2);
      assert.match(result.stderr, /작업 계획/);
    },
  ],
  [
    "does not enforce worklog comments when the Linear issue lacks the codex label",
    () => {
      const cwd = tempCwd();
      const sessionId = "unlabeled-session";
      const issue = {
        identifier: "KTD-77",
        delegate: { id: "codex-agent-id", name: "Codex" },
        labels: { nodes: [{ name: "환경구성" }] },
      };
      const env = { CODEX_LINEAR_AGENT_IDS: "codex-agent-id" };

      runHook("user-prompt-submit", {
        cwd,
        session_id: sessionId,
        prompt: "KTD-77 작업 진행",
      }, issue, env);

      const result = runHook("pre-tool-use", {
        cwd,
        session_id: sessionId,
        tool_name: "apply_patch",
        tool_input: { path: "README.md" },
      }, {
        ...issue,
        state: { name: "In Progress" },
        comments: { nodes: [] },
      }, env);

      assert.strictEqual(result.status, 0);
      assert.strictEqual(result.stderr, "");
    },
  ],
  [
    "supports overriding the active Linear label list with CODEX_LINEAR_LABELS",
    () => {
      const cwd = tempCwd();
      const sessionId = "custom-label-session";
      const issue = {
        identifier: "KTD-77",
        labels: { nodes: [{ name: "ai" }] },
      };
      const env = { CODEX_LINEAR_LABELS: "ai" };

      runHook("user-prompt-submit", {
        cwd,
        session_id: sessionId,
        prompt: "KTD-77 작업 진행",
      }, issue, env);

      const result = runHook("pre-tool-use", {
        cwd,
        session_id: sessionId,
        tool_name: "apply_patch",
        tool_input: { path: "README.md" },
      }, {
        ...issue,
        state: { name: "In Progress" },
        comments: { nodes: [] },
      }, env);

      assert.strictEqual(result.status, 2);
      assert.match(result.stderr, /작업 계획/);
    },
  ],
];

let failed = 0;
for (const [name, test] of tests) {
  try {
    test();
    console.log(`ok - ${name}`);
  } catch (error) {
    failed += 1;
    console.error(`not ok - ${name}`);
    console.error(error && error.stack ? error.stack : String(error));
  }
}

if (failed > 0) {
  process.exit(1);
}

function tempCwd() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "linear-worklog-test-"));
}

function runHook(phase, input, issue, extraEnv = {}) {
  return spawnSync(process.execPath, [hookScript, phase], {
    cwd: repoRoot,
    input: `${JSON.stringify(input)}\n`,
    encoding: "utf8",
    env: {
      ...process.env,
      CODEX_LINEAR_AGENT_IDS: "",
      CODEX_LINEAR_LABELS: "",
      LINEAR_API_KEY: "",
      LINEAR_WORKLOG_MOCK_ISSUE_JSON: JSON.stringify(issue),
      ...extraEnv,
    },
  });
}
