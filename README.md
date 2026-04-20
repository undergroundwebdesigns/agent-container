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

## Notes

- The `NET_ADMIN` and `NET_RAW` capabilities are required for the iptables-based firewall
- The firewall initializes automatically via the entrypoint before any command runs
- Volumes persist `.claude` config and command history across runs
