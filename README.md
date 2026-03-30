# ralph-dev

Superproject for working on [`ralph-sandbox`](./ralph-sandbox) and
[`ralph-plus-plus`](./ralph-plus-plus) together in one VS Code workspace.

The goal of this repo is coordination, not packaging:

- `ralph-sandbox` owns the container runtime and sandbox entrypoint contract.
- `ralph-plus-plus` owns higher-level orchestration around PRD generation,
  worktree management, and sandbox execution.
- `.devcontainer/` is a convenience environment for editing both repos together.

## Repository Layout

```text
.
├── .devcontainer/      VS Code devcontainer for cross-repo development
├── ralph-plus-plus/    Orchestrator
├── ralph-sandbox/      Docker sandbox runtime
└── ralph.code-workspace
```

## Clone And Init

```bash
git clone git@github.com:davesnowdon/ralph-dev.git
cd ralph-dev
git submodule update --init --recursive
```

To update both submodules to the latest `main` branch tips:

```bash
git submodule update --remote --merge
```

The `.gitmodules` file declares `branch = main` for both submodules so that
`git submodule update --remote` has an explicit tracking branch contract.

## Working Model

This repo is intended for local development and review across both submodules.
It does not try to install both repos into one Python environment by default.

The devcontainer is intentionally minimal:

- Provides Python, Git, `uv`, GitHub CLI, and Docker CLI.
- Mounts the host Docker socket so `docker` commands can target the host daemon.
- Avoids editable installs during container creation.

That keeps startup cheap and avoids pretending both repos share one Python
packaging model when they do not.

## Integration Model

The intended integration is:

1. `ralph-plus-plus` prepares worktree state and orchestration inputs.
2. `ralph-plus-plus` invokes `ralph-sandbox` through its supported wrapper.
3. `ralph-sandbox` runs either its default Ralph loop or a custom
   `SESSION_RUNNER`.

This workspace exists so both sides of that contract can be developed and
validated together.

## Devcontainer

Open the repository in VS Code and select "Reopen in Container" if you want a
consistent editor environment. The devcontainer is optional; if your host
already has Python, Docker, Git, and the required CLIs configured, you can work
outside it.

## Useful Commands

Check submodule state:

```bash
git submodule status
```

Sync submodule URLs/branch metadata after pulling changes:

```bash
git submodule sync --recursive
```

Run the sandbox wrapper directly:

```bash
cd ralph-sandbox
bin/ralph-sandbox --help
```

Run the orchestrator directly:

```bash
cd ralph-plus-plus
python -m ralph_pp.cli --help
```
