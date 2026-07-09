#!/usr/bin/env bash
# guard-bash-commands.sh
# PreToolUse (Bash) hook. Blocks irreversible or policy-violating shell commands.
# exit 2 blocks the call and shows the stderr message to the agent.

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0

block() {
  echo "Blocked: $1" >&2
  exit 2
}

# git force-push, any spelling
if echo "$CMD" | grep -Eq '\bgit\b.*\bpush\b'; then
  if echo "$CMD" | grep -Eq -- '(--force-with-lease|--force|[[:space:]]-f([[:space:]]|$))'; then
    block "force-push is never allowed under any circumstances."
  fi
fi

# git rebase
if echo "$CMD" | grep -Eq '\bgit\b.+\brebase\b'; then
  block "git rebase is never allowed under any circumstances."
fi

# rewriting the origin remote
if echo "$CMD" | grep -Eq '\bgit\b.+\bremote\b.+\bset-url\b.+\borigin\b'; then
  block "rewriting the 'origin' remote is not allowed; keep the user's origin and pass auth via a credential helper / ENV."
fi

if echo "$CMD" | grep -Eq '\bgit\b'; then
  # credentials embedded in a URL: https://user:token@host
  if echo "$CMD" | grep -Eq 'https?://[^/[:space:]]+:[^/@[:space:]]+@'; then
    block "do not embed credentials in a git URL; clone clean and pass auth via a credential helper / ENV at invocation."
  fi
  # a token var interpolated into a URL
  if echo "$CMD" | grep -Eq '\$\{?GITHUB_[A-Z_]*TOKEN[A-Z_]*\}?@|https?://[^[:space:]]*\$\{?GITHUB_'; then
    block "do not interpolate a token into a git URL; use a credential helper / ENV at invocation instead."
  fi
  # packages-only token misused for git operations
  if echo "$CMD" | grep -Eq 'GITHUB_PACKAGES_TOKEN'; then
    block "GITHUB_PACKAGES_TOKEN is packages:read only and must never be used for git ops; use \$GITHUB_TOKEN (or the repo-specific token)."
  fi
fi

# supply-chain / verification bypass flags
if echo "$CMD" | grep -Eq -- '--no-verify|--no-audit'; then
  block "supply-chain / verification bypass flags (--no-verify, --no-audit) are not allowed."
fi
if echo "$CMD" | grep -Eq -- 'minimumReleaseAgeStrict[[:space:]=:]*false|minimumReleaseAge[[:space:]=:]*0'; then
  block "do not weaken minimumReleaseAge(Strict); fix the underlying cause or surface the failure."
fi

exit 0
