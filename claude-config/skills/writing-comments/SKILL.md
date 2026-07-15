---
name: writing-comments
description: >-
  Use whenever writing or editing a comment in ANY file (code, config, YAML,
  Dockerfiles) or user-facing prose docs (README, architecture, guides).
  Enforces that comments/docs describe only the current state of the code, with
  no history and no contrasts to concepts the codebase no longer has. Apply on
  every comment you author or touch, and especially after any "change it" /
  "remove it" / "do it differently" instruction.
---

# Writing comments (and user-facing docs)

A comment or doc describes **only what the code/app does today**. It must stand
on its own for a reader who has never seen the prior design. Comments are
user-facing docs — the same rule applies to both.

## The test
Before keeping any clause, ask: *would a reader who never knew the old design be
confused by this?* If the clause only makes sense as a contrast to something the
codebase no longer contains, **delete it — don't reword it.**

## Delete on sight
- **History / transition:** "no longer", "used to", "previously", "formerly",
  "still does X", "after <TICKET> lands", "overwritten by the first run",
  "(not all of them)". Git history already records the change.
- **Contrast to a removed/absent concept:** "not baked", "there is no in-cluster
  X", "no longer generated", "instead of the old Y". Naming a thing that doesn't
  exist introduces a term the reader can't resolve — worse than noise.
- **"What we're NOT doing"** and restating what the code plainly does.

## Keep
- Present-tense rationale for why the current code is the way it is (the
  non-obvious *why*).
- Contrasts where **both sides exist in the current app** (dev vs cluster, host
  vs pod, changed vs unchanged, this-service vs that-service).
- A plain current fact stated once, without contrast (e.g. "X is baked into the
  image at build time" — fine; "X is *still* baked, unlike Y which moved" — not).

## Examples
- Bad: `# No longer bakes the manifest; it's delivered per-env now.`
  Good: `# Delivered per-env as a mounted ConfigMap, read at runtime.`
- Bad: `# MCP servers are remote-only: there is no in-cluster MCP image.`
  Good: `# MCP servers are remote services registered in mcp_servers.yml.`
- Bad: `# Placeholder, overwritten by the first CI run after ENG-927 lands.`
  Good: `# Placeholder; CI pins the real digest the next time it builds this.`

## When editing existing code
After a "change/remove X" instruction, scan the touched files (and any comment
your change invalidates) and strip contrasting/historical commentary too — not
just the logic. A change that removes a concept must remove every comment that
references it.
