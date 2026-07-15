## DISCLAIMER: 
This is very much a work in progress. No guarantees are made about it's suitablity or completeness for any purpose. Use at your own risk. All rights reserved by the author.

# Claude Code Sandbox

Sandboxed container for running Claude Code headless/agentic, based on the [Anthropic reference devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer).

## What's included

- **Node 20** base image with Claude Code CLI pre-installed
- **Whitelist-only firewall** (iptables + ipset) — only GitHub, npm, Anthropic APIs, and Sentry/Statsig are reachable; initialized automatically on container start
- **ZSH** with Powerlevel10k, git-delta, fzf
- Persistent volumes for `.claude` config and command history

## Setup

Export your API key (or add to `.env`):

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

## Run interactively

```bash
docker compose run --rm claude
```

## Run Claude headless

```bash
docker compose run --rm claude claude --dangerously-skip-permissions -p "your prompt here"
```

## Build only

```bash
docker compose build
```

## Configuration architecture

The agent's configuration lives in `claude-config/` (mounted read-only at `/claude-config`
and symlinked into the persistent `~/.claude` volume). Rules that must hold every time are
enforced in code rather than left to the agent's prose instructions, because prompt/CLAUDE.md
instructions are advisory and followed only probabilistically. Under this container's
`bypassPermissions` mode both `permissions.deny` rules and `exit 2` PreToolUse hooks are still
enforced deterministically.

### Guardrail hooks (`claude-config/hooks/`)

- **`block-lockfile-edits.sh`** (Edit/Write) — blocks direct edits to package-manager
  lockfiles and auto-generated files (`schema.rb`, `structure.sql`). Regenerate them via the
  package manager or a migration instead.
- **`guard-bash-commands.sh`** (Bash) — blocks irreversible or policy-violating shell
  commands: git force-push (any spelling), `git rebase`, rewriting the `origin` remote,
  credentials embedded/interpolated into a git URL, `GITHUB_PACKAGES_TOKEN` used for git ops,
  supply-chain bypass flags (`--no-verify`, `--no-audit`, weakened `minimumReleaseAge`), and
  `git config` writes that persist auth/URL rewrites (`insteadOf`, `credential.helper`,
  `remote.origin.url`) into a repo's shared `.git/config` (pass auth inline via `git -c ...`).
- `npm`/`npx` are blocked via `permissions.deny` in `settings.json` (use `pnpm`/`pnpx`).

### Per-repo instructions (`claude-config/repo-notes/`)

`/workspace` holds many checked-out repos, and tasks span them, so per-repo instructions can't
live in each product repo (they're shared) or in the always-loaded global config (bloat). Each
repo's standing instructions live in `claude-config/repo-notes/<repo>.md`, named exactly after
its `/workspace/<repo>` directory. The **`select-repo-instructions.sh`** hook (Edit/Write/Read/Bash)
watches the target path, and the first time a repo is touched in a session it injects that repo's
notes as context — once per repo per session. This keeps the always-on context small: nothing
loads until a repo is actually worked on.

### Per-repo workflows (`claude-config/skills/`)

Repo-specific *procedures* (multi-step build/test loops) are skills rather than notes, so they
load on demand and can be invoked directly. One skill per distinct workflow (e.g.
`smile-agents-local-dev`, `incident-sync-host-tests`).

Instruction files (`CLAUDE.md`, `SKILL.md`, hooks, notes) are written for the agent. This README
is the place for human-facing explanation of how the configuration works.

## Notes

- The `NET_ADMIN` and `NET_RAW` capabilities are required for the iptables-based firewall
- The firewall initializes automatically via the entrypoint before any command runs
- Volumes persist `.claude` config and command history across runs
