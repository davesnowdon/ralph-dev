  Manual validation strategy

  Run a small matrix, not ad hoc spot checks.

  1. delegated mode with claude.
  2. delegated mode with codex.
  3. orchestrated mode with backout_on_failure=true.
  4. orchestrated mode with backout_on_failure=false.
  5. orchestrated mode with prompt_template enabled.
  6. A linked git worktree case, since that is central to the design.

  For each run, verify the branch/worktree creation, sandbox execution, prompt selection, commits, scripts/ralph/progress.txt, and cleanup of local git user config. Also
  inspect whether failures are surfaced as the real cause rather than being absorbed into review loops.

  Then do fault injection: missing runner, missing config dir, broken Docker invocation, malformed prd.json, failing tests, and a reviewer that returns prose containing
  LGTM. Those cases will tell you whether the workflow is actually resilient or only happy-path clean.
