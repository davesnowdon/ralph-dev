# AGENTS

## Repo Purpose

`ralph-dev` is the superproject used to develop `ralph-plus-plus` and
`ralph-sandbox` together.

- `ralph-plus-plus/` owns orchestration, PRD generation, worktree management,
  and sandbox invocation.
- `ralph-sandbox/` owns the container runtime, entrypoint contract, wrapper
  script, and custom-runner support.
- The superproject owns coordination between the two repos, submodule state,
  and shared developer workflow.

This repo is not a combined Python package. Changes should normally be made in
the relevant submodule, with the superproject only updated when coordination,
documentation, or submodule pointers need to change.

## Change Rules For Agents

When making changes from the superproject:

- keep repo responsibilities clear; do not move sandbox concerns into
  `ralph-plus-plus` or orchestration concerns into `ralph-sandbox` without a
  deliberate contract change
- update submodule-specific docs/tests in the submodule where the behavior
  actually lives
- if a change affects the integration contract between the two repos, update
  both repos together
- if submodule pointers change, make sure the referenced submodule commits have
  already passed their required checks

## Done Criteria

A change is not done until the relevant checks for the touched repos pass.

If only `ralph-plus-plus/` changed, run:

```bash
cd ralph-plus-plus
uv sync --group dev
make check
```

If only `ralph-sandbox/` changed, run:

```bash
cd ralph-sandbox
make check
```

If both submodules changed, run both check suites.

If the change affects the contract between the orchestrator and sandbox, also
perform a manual integration pass covering:

- delegated sandbox execution
- orchestrated custom-runner execution
- linked git worktree handling
- prompt handoff into the sandbox via `SESSION_RUNNER` / `RALPH_PROMPT_FILE`

## References

- [README.md](/home/dns/ai-ml/agents/ralph-dev/README.md)
- [ralph-plus-plus/AGENTS.md](/home/dns/ai-ml/agents/ralph-dev/ralph-plus-plus/AGENTS.md)
- [ralph-sandbox/AGENTS.md](/home/dns/ai-ml/agents/ralph-dev/ralph-sandbox/AGENTS.md)
