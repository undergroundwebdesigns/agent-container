#!/usr/bin/env bash
# workspace-repo-audit.sh
# SessionStart hook. Audits every git repo directly under /workspace and reports,
# for each, its current branch and how many commits it is behind origin/main.
# The point: surface stale / off-main clones up front so work never starts on a
# stale base (a repeated failure mode).
#
# Fetches origin/main first (auth: GITHUB_TOKEN_EXTRAS for smile-io-extras
# origins, GITHUB_TOKEN otherwise) so "behind" is measured against the true
# remote tip, not a stale tracking ref. Origins are commonly SSH with no key in
# this environment, so we rewrite to HTTPS and inject the token via an ephemeral
# credential helper. Nothing is persisted to .git/config.
#
# Output is emitted as SessionStart additionalContext (JSON on stdout).
# Fail-soft: any per-repo error is reported as a line, never aborts the audit.

WORKSPACE="/workspace"
FETCH_TIMEOUT=15   # seconds per repo fetch

audit_one() {
  local dir="$1"
  local name; name=$(basename "$dir")
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local branch origin token behind status
  branch=$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null || echo "DETACHED")
  origin=$(git -C "$dir" remote get-url origin 2>/dev/null || echo "")

  if [ -z "$origin" ]; then
    printf '  %-40s branch=%-45s (no origin remote)\n' "$name" "$branch"
    return 0
  fi

  case "$origin" in
    *smile-io-extras*) token="$GITHUB_TOKEN_EXTRAS" ;;
    *)                 token="$GITHUB_TOKEN" ;;
  esac

  # Fetch origin/main using an ephemeral HTTPS credential helper (never persisted).
  status="ok"
  if ! timeout "$FETCH_TIMEOUT" git -C "$dir" \
        -c credential.helper='!f() { echo "username=x-access-token"; echo "password='"$token"'"; }; f' \
        -c url."https://github.com/".insteadOf="git@github.com:" \
        -c url."https://github.com/".insteadOf="ssh://git@github.com/" \
        fetch --quiet origin main >/dev/null 2>&1; then
    status="fetch-failed"
  fi

  # Behind = commits on the fetched origin/main not reachable from HEAD.
  local base
  if [ "$status" = "ok" ]; then
    base="FETCH_HEAD"
  else
    base="origin/main"   # fall back to whatever tracking ref exists locally
  fi
  behind=$(git -C "$dir" rev-list --count "HEAD..$base" 2>/dev/null || echo "?")

  local flag=""
  if [ "$branch" != "main" ]; then
    flag=" <- not on main"
  elif [ "$behind" != "0" ] && [ "$behind" != "?" ]; then
    flag=" <- BEHIND"
  fi
  local note=""
  [ "$status" = "fetch-failed" ] && note=" (fetch failed; behind vs stale ref)"

  printf '  %-40s branch=%-30s behind origin/main=%s%s%s\n' \
    "$name" "$branch" "$behind" "$note" "$flag"
}

REPORT=""
for dir in "$WORKSPACE"/*/; do
  [ -d "${dir}.git" ] || [ -d "${dir%/}/.git" ] || continue
  line=$(audit_one "${dir%/}")
  [ -n "$line" ] && REPORT="${REPORT}${line}"$'\n'
done

if [ -z "$REPORT" ]; then
  REPORT="  (no git repositories found under /workspace)"$'\n'
fi

HEADER="Workspace repo audit (git repos under /workspace). Anything marked 'not on main' or 'BEHIND' MUST be reset to an up-to-date main before starting new work on it, unless it is a task branch you intentionally created off fresh main:"

# Emit as SessionStart additionalContext.
jq -n --arg ctx "$HEADER"$'\n'"$REPORT" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
