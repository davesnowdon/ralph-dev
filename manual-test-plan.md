Manual validation strategy

Use a small matrix with concrete commands, not ad hoc spot checks.

This plan assumes:

- both submodules have already passed their automated checks
- Docker is available locally
- `claude`, `codex`, and `gh` are installed and authenticated on the host
- the `kc-agent` planning document has been updated so it gives a concrete implementation objective rather than only describing architecture
- you are running commands from the superproject root unless stated otherwise

The goal is to validate the cross-repo contract in real conditions:

- delegated mode with Claude
- delegated mode with Codex
- orchestrated mode with custom `SESSION_RUNNER`
- both orchestrated retry strategies
- prompt handoff via `RALPH_PROMPT_FILE`
- linked git worktree handling
- failure surfacing for runner, config, Docker, PRD, tests, and reviewer output edge cases

## Common setup

Choose the target repo and fetch the concrete task document:

```bash
export KC_AGENT_REPO="$HOME/src/kc-agent"
export KC_AGENT_DOC_URL="https://github.com/playkindredcode/kc-agent/blob/main/docs/memory-unification-plan.md"
export RALPH_DEV_ROOT="$(pwd)"
export RPP_DIR="$RALPH_DEV_ROOT/ralph-plus-plus"
export RS_DIR="$RALPH_DEV_ROOT/ralph-sandbox"
```

Create a logs directory and a helper function to wrap each run with `script`
and strip ANSI escapes with `ansifilter`:

```bash
export LOGS_DIR="$RALPH_DEV_ROOT/logs"
mkdir -p "$LOGS_DIR"

run_case() {
  local case_name="$1"; shift
  local raw="$LOGS_DIR/${case_name}-raw.log"
  local clean="$LOGS_DIR/${case_name}-clean.log"
  local cmd
  cmd="$(printf '%q ' "$@")"
  echo "▶ $case_name → $raw"
  echo "$ $cmd" > "$raw"
  script -q -a -c "$cmd" "$raw"
  local rc=$?
  ansifilter -o "$clean" "$raw"
  echo "  exit=$rc  clean log: $clean"
  return $rc
}
```

Confirm the local toolchains and sandbox resolve cleanly:

```bash
cd "$RPP_DIR"
uv run ralph++ config --repo "$KC_AGENT_REPO"
```

Build the sandbox image once up front so the first matrix run is not polluted by build latency:

```bash
cd "$RS_DIR"
docker compose build ralph
```

Use one concrete implementation objective for all happy-path runs. Keep it bounded so the outcome is inspectable. Example objective:

```text
Use docs/memory-unification-plan.md as the requirements source.

Implement only the first concrete slice of the plan:
- define the canonical public retrieval/store protocols
- add backend-agnostic contract tests for those protocols
- do not migrate the runtime to the new store yet
- do not rewrite the full memory subsystem

Success means code, tests, and documentation are updated consistently and the repo's relevant tests pass.
```

Create a dedicated project config in the target repo so every run uses the same tools and prompts unless a case overrides them:

```bash
mkdir -p "$KC_AGENT_REPO/.ralph"

cat >"$KC_AGENT_REPO/.ralph/ralph++.yaml" <<'YAML'
ralph:
  sandbox_dir: /home/dns/ai-ml/agents/ralph-dev/ralph-sandbox
  session_runner: scripts/ralph-single-step.sh

orchestrated:
  run_tests_between_steps: true
  max_iteration_retries: 1
  test_commands:
    - hatch run ci

hooks:
  post_worktree_create:
    - "hatch env create"
YAML
```

For each run below, record:

- exact command run
- created branch and worktree path
- whether sandbox execution reached the expected mode
- whether the right prompt file was used
- whether commits were created when expected
- contents of `scripts/ralph/progress.txt`
- whether local git user config was cleaned up at the end
- whether failures surfaced as infra/test/review causes instead of being absorbed into loops

## Test matrix

1. Delegated mode with Claude
2. Delegated mode with Codex
3. Orchestrated mode with `SESSION_RUNNER`, `backout_on_failure=true`
4. Orchestrated mode with `SESSION_RUNNER`, `backout_on_failure=false`
5. Orchestrated mode with `prompt_template` enabled
6. Direct custom-runner contract check in `ralph-sandbox`
7. Linked git worktree case
8. Fault injection cases

## Case 1: delegated mode with Claude

```bash
cd "$RPP_DIR"
run_case case1-delegated-claude \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --feature "Implement the first concrete slice from $KC_AGENT_DOC_URL using Claude in delegated mode" \
    --mode delegated \
    --claude-config "$HOME/.claude" \
    --max-iters 10
```

Verify after the run:

```bash
git -C "$KC_AGENT_REPO" worktree list
find "$(dirname "$KC_AGENT_REPO")" -maxdepth 1 -type d -name 'ralph-*' -o -name 'feature-*'
```

Inspect the created worktree manually:

```bash
export CASE1_WORKTREE="/path/from-ralph++-output"
git -C "$CASE1_WORKTREE" status
git -C "$CASE1_WORKTREE" log --oneline --decorate -5
sed -n '1,120p' "$CASE1_WORKTREE/scripts/ralph/progress.txt"
git -C "$CASE1_WORKTREE" config --list | rg '^user\.'
```

Expected focus:

- delegated path exercised the built-in Ralph loop, not `SESSION_RUNNER`
- sandbox used Claude config successfully
- worktree was usable and cleanup happened on completion

## Case 2: delegated mode with Codex

```bash
cd "$RPP_DIR"
run_case case2-delegated-codex \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --feature "Implement the first concrete slice from $KC_AGENT_DOC_URL using Codex in delegated mode" \
    --mode delegated \
    --codex-config "$HOME/.codex" \
    --max-iters 10
```

Inspect the created worktree:

```bash
export CASE2_WORKTREE="/path/from-ralph++-output"
git -C "$CASE2_WORKTREE" status
git -C "$CASE2_WORKTREE" log --oneline --decorate -5
sed -n '1,120p' "$CASE2_WORKTREE/scripts/ralph/progress.txt"
git -C "$CASE2_WORKTREE" config --list | rg '^user\.'
```

Expected focus:

- delegated path exercised Codex successfully
- Codex config mount worked in the default runner path

## Case 3: orchestrated mode with custom runner and backout enabled

Create an override config for this case:

```bash
cat >"$KC_AGENT_REPO/.ralph/ralph++-orch-backout.yaml" <<'YAML'
ralph:
  mode: orchestrated
  sandbox_dir: /home/dns/ai-ml/agents/ralph-dev/ralph-sandbox
  session_runner: scripts/ralph-single-step.sh
  max_iterations: 10

orchestrated:
  coder: codex
  reviewer: codex
  fixer: codex
  backout_on_failure: true
  max_iteration_retries: 1
  run_tests_between_steps: true
  test_commands:
    - hatch run ci

hooks:
  post_worktree_create:
    - "hatch env create"
YAML
```

Run:

```bash
cd "$RPP_DIR"
run_case case3-orch-backout \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --config "$KC_AGENT_REPO/.ralph/ralph++-orch-backout.yaml" \
    --feature "Implement the first concrete slice from $KC_AGENT_DOC_URL in orchestrated mode with backout enabled" \
    --codex-config "$HOME/.codex"
```

Inspect the resulting worktree:

```bash
export CASE3_WORKTREE="/path/from-ralph++-output"
git -C "$CASE3_WORKTREE" status
git -C "$CASE3_WORKTREE" log --oneline --decorate -10
sed -n '1,200p' "$CASE3_WORKTREE/scripts/ralph/progress.txt"
sed -n '1,120p' "$CASE3_WORKTREE/scripts/ralph/CLAUDE.md"
```

Expected focus:

- orchestrated path invoked `SESSION_RUNNER`
- retries/backout happened on failure before review acceptance
- infra failures skipped review instead of being reported as findings

## Case 4: orchestrated mode with custom runner and backout disabled

Create an override config:

```bash
cat >"$KC_AGENT_REPO/.ralph/ralph++-orch-fixinplace.yaml" <<'YAML'
ralph:
  mode: orchestrated
  sandbox_dir: /home/dns/ai-ml/agents/ralph-dev/ralph-sandbox
  session_runner: scripts/ralph-single-step.sh
  max_iterations: 10

orchestrated:
  coder: codex
  reviewer: codex
  fixer: codex
  backout_on_failure: false
  max_iteration_retries: 2
  run_tests_between_steps: true
  test_commands:
    - hatch run ci

hooks:
  post_worktree_create:
    - "hatch env create"
YAML
```

Run:

```bash
cd "$RPP_DIR"
run_case case4-orch-fixinplace \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --config "$KC_AGENT_REPO/.ralph/ralph++-orch-fixinplace.yaml" \
    --feature "Implement the first concrete slice from $KC_AGENT_DOC_URL in orchestrated mode with in-place fixing" \
    --codex-config "$HOME/.codex"
```

Inspect the resulting worktree:

```bash
export CASE4_WORKTREE="/path/from-ralph++-output"
git -C "$CASE4_WORKTREE" status
git -C "$CASE4_WORKTREE" log --oneline --decorate -10
sed -n '1,200p' "$CASE4_WORKTREE/scripts/ralph/progress.txt"
test -f "$CASE4_WORKTREE/scripts/ralph/.fix-prompt.md" && sed -n '1,120p' "$CASE4_WORKTREE/scripts/ralph/.fix-prompt.md"
```

Expected focus:

- fixer cycles happened in place instead of resetting to `pre_sha`
- failure state remained attributable to tests or findings

## Case 5: orchestrated mode with prompt template enabled

Create an override config:

```bash
cat >"$KC_AGENT_REPO/.ralph/ralph++-orch-template.yaml" <<'YAML'
ralph:
  mode: orchestrated
  sandbox_dir: /home/dns/ai-ml/agents/ralph-dev/ralph-sandbox
  session_runner: scripts/ralph-single-step.sh
  max_iterations: 10

orchestrated:
  coder: codex
  reviewer: codex
  fixer: codex
  backout_on_failure: false
  max_iteration_retries: 1
  run_tests_between_steps: true
  test_commands:
    - hatch run ci
  prompt_template: |
    Read {prd_file} and continue the concrete implementation objective.

    Iteration: {iteration}

    Previous review findings:
    {review_findings}

    Progress so far:
    {progress}

    Make the next smallest coherent change and update tests.

hooks:
  post_worktree_create:
    - "hatch env create"
YAML
```

Run:

```bash
cd "$RPP_DIR"
run_case case5-orch-template \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --config "$KC_AGENT_REPO/.ralph/ralph++-orch-template.yaml" \
    --feature "Implement the first concrete slice from $KC_AGENT_DOC_URL with prompt-template handoff" \
    --codex-config "$HOME/.codex"
```

Inspect prompt handoff:

```bash
export CASE5_WORKTREE="/path/from-ralph++-output"
sed -n '1,200p' "$CASE5_WORKTREE/scripts/ralph/.iteration-prompt.md"
sed -n '1,200p' "$CASE5_WORKTREE/scripts/ralph/progress.txt"
```

Expected focus:

- `RALPH_PROMPT_FILE` handoff actually selected `.iteration-prompt.md`
- progress and prior findings were interpolated into the prompt

## Case 6: direct custom-runner contract check in ralph-sandbox

This case validates the sandbox contract without going through ralph++.

Create a simple runner:

```bash
cat > /tmp/ralph-sandbox-smoke-runner.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
pwd
echo "PROJECT_DIR=${PROJECT_DIR}"
echo "RALPH_TOOL=${RALPH_TOOL:-}"
echo "SESSION_RUNNER=${SESSION_RUNNER:-}"
git status --short
test -d .git -o -f .git
SH
chmod +x /tmp/ralph-sandbox-smoke-runner.sh
```

Run it with Codex selected:

```bash
cd "$RS_DIR"
run_case case6-sandbox-direct \
  bin/ralph-sandbox \
    --project-dir "$KC_AGENT_REPO" \
    --tool codex \
    --session-runner /tmp/ralph-sandbox-smoke-runner.sh \
    -- arg1 arg2
```

Expected focus:

- entrypoint validated `PROJECT_DIR`
- custom runner executed at `/run/ralph/session-runner.sh`
- git worked inside the container
- note whether tool config mounts were still added in practice even though they are documented as optional in custom-runner mode

## Case 7: linked git worktree case

Create a linked worktree manually:

```bash
export KC_AGENT_LINKED_WORKTREE="$(dirname "$KC_AGENT_REPO")/kc-agent-linked-manual"
git -C "$KC_AGENT_REPO" worktree add "$KC_AGENT_LINKED_WORKTREE" -b manual-linked-sandbox-test
```

Validate the sandbox directly inside that linked worktree:

```bash
cd "$RS_DIR"
run_case case7a-sandbox-linked-worktree \
  bin/ralph-sandbox \
    --project-dir "$KC_AGENT_LINKED_WORKTREE" \
    --tool codex \
    --session-runner /tmp/ralph-sandbox-smoke-runner.sh
```

Then validate ralph++ against the same repository family:

```bash
cd "$RPP_DIR"
run_case case7b-rpp-linked-worktree \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --config "$KC_AGENT_REPO/.ralph/ralph++-orch-backout.yaml" \
    --feature "Implement the first concrete slice from $KC_AGENT_DOC_URL while validating linked worktree handling" \
    --codex-config "$HOME/.codex"
```

Expected focus:

- shared git metadata mount made `git status`, branch operations, and commits work inside container
- no path translation issues between host and container for linked worktrees

## Case 8: fault injection

Run the following negative cases and capture the exact surfaced error.

### 8a. Missing runner

```bash
cd "$RS_DIR"
run_case case8a-missing-runner \
  bin/ralph-sandbox \
    --project-dir "$KC_AGENT_REPO" \
    --tool codex \
    --session-runner /tmp/does-not-exist-runner.sh
```

Expected result:

- wrapper fails immediately with a missing-runner error

### 8b. Missing Claude config dir in delegated mode

```bash
cd "$RS_DIR"
run_case case8b-missing-claude-config \
  bin/ralph-sandbox \
    --project-dir "$KC_AGENT_REPO" \
    --tool claude \
    --claude-config-dir /tmp/does-not-exist-claude-config \
    -- 1
```

Expected result:

- wrapper fails before Docker execution with a missing-directory error

### 8c. Broken Docker invocation

Use an invalid service name:

```bash
cd "$RS_DIR"
run_case case8c-bad-service \
  bin/ralph-sandbox \
    --project-dir "$KC_AGENT_REPO" \
    --tool codex \
    --service does-not-exist \
    -- 1
```

Expected result:

- Docker/Compose error is surfaced as infra failure, not review failure

### 8d. Malformed `prd.json`

Corrupt the file in a throwaway worktree created by an orchestrated run, then rerun inside that worktree:

```bash
export CASE8D_WORKTREE="/path/from-a-previous-orchestrated-run"
printf '{ invalid json\n' > "$CASE8D_WORKTREE/scripts/ralph/prd.json"

cd "$RPP_DIR"
run_case case8d-malformed-prd \
  uv run ralph++ \
    --repo "$CASE8D_WORKTREE" \
    --config "$KC_AGENT_REPO/.ralph/ralph++-orch-backout.yaml" \
    --feature "Resume malformed prd.json test" \
    --codex-config "$HOME/.codex"
```

Expected result:

- malformed PRD path fails clearly and early

### 8e. Failing tests in orchestrated mode

Add a guaranteed failing command:

```bash
cat >"$KC_AGENT_REPO/.ralph/ralph++-orch-failing-tests.yaml" <<'YAML'
ralph:
  mode: orchestrated
  sandbox_dir: /home/dns/ai-ml/agents/ralph-dev/ralph-sandbox
  session_runner: scripts/ralph-single-step.sh
  max_iterations: 2

orchestrated:
  coder: codex
  reviewer: codex
  fixer: codex
  backout_on_failure: true
  max_iteration_retries: 1
  run_tests_between_steps: true
  test_commands:
    - /bin/false

hooks:
  post_worktree_create:
    - "hatch env create"
YAML
```

Run:

```bash
cd "$RPP_DIR"
run_case case8e-failing-tests \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --config "$KC_AGENT_REPO/.ralph/ralph++-orch-failing-tests.yaml" \
    --feature "Exercise failing-test handling for $KC_AGENT_DOC_URL" \
    --codex-config "$HOME/.codex"
```

Expected result:

- tests are reported as the cause
- reviewer approval alone does not allow acceptance

### 8f. Reviewer returns prose containing `LGTM`

Create a config that uses a fake reviewer command:

```bash
cat >"$KC_AGENT_REPO/.ralph/ralph++-orch-fake-reviewer.yaml" <<'YAML'
ralph:
  mode: orchestrated
  sandbox_dir: /home/dns/ai-ml/agents/ralph-dev/ralph-sandbox
  session_runner: scripts/ralph-single-step.sh
  max_iterations: 1

tools:
  fake-reviewer:
    type: cli
    command: bash
    args:
      - -lc
      - 'printf "Reviewed changes.\nLGTM\nBut also fix these issues.\n"'
  codex:
    type: cli
    command: codex
    args: ["{prompt}"]
  claude:
    type: cli
    command: claude
    args: ["--print"]
    stdin: "{prompt}"
    allowed_tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash(git:*)"]

orchestrated:
  coder: codex
  reviewer: fake-reviewer
  fixer: codex
  backout_on_failure: false
  max_iteration_retries: 1
  run_tests_between_steps: false
YAML
```

Run:

```bash
cd "$RPP_DIR"
run_case case8f-fake-reviewer \
  uv run ralph++ \
    --repo "$KC_AGENT_REPO" \
    --config "$KC_AGENT_REPO/.ralph/ralph++-orch-fake-reviewer.yaml" \
    --feature "Exercise non-terminal LGTM parsing for $KC_AGENT_DOC_URL" \
    --codex-config "$HOME/.codex"
```

Expected result:

- reviewer output containing prose plus `LGTM` is not treated as terminal approval

## Suggested execution order

Run in this order so the early cases establish baseline confidence before the noisy failures:

1. Case 6
2. Case 1
3. Case 2
4. Case 3
5. Case 4
6. Case 5
7. Case 7
8. Case 8

## Exit criteria

The manual pass is good enough to proceed only if:

- both delegated tools work end to end against the same non-trivial repo task
- orchestrated mode works with `SESSION_RUNNER` in both retry strategies
- prompt-template handoff is visibly correct
- linked worktrees work inside the container
- the main negative cases fail at the right layer with the right error class
- no unexpected git config residue is left in produced worktrees
- any remaining issues are understood operational quirks rather than unexplained contract failures
