#!/usr/bin/env bash
# select-repo-instructions.sh
# PreToolUse hook. The first time a repo under /workspace is touched in a session,
# injects that repo's standing instructions from /claude-config/repo-notes/<repo>.md
# as additionalContext. Keyed on the /workspace/<repo> path segment. Never blocks.

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# The path that identifies which repo is being worked on: the explicit target for
# file tools, the session cwd for Bash.
case "$TOOL" in
  Bash) CANDIDATE=$(echo "$INPUT" | jq -r '.cwd // empty') ;;
  *)    CANDIDATE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty') ;;
esac

[[ -z "$CANDIDATE" ]] && exit 0

# Repos are direct children of /workspace.
if [[ ! "$CANDIDATE" =~ ^/workspace/([^/]+)(/|$) ]]; then
  exit 0
fi
REPO="${BASH_REMATCH[1]}"

NOTE="/claude-config/repo-notes/${REPO}.md"
[[ -f "$NOTE" ]] || exit 0

# Inject once per repo per session.
SESSION=$(echo "$INPUT" | jq -r '.session_id // "nosession"')
MARKER_DIR="/tmp/claude-repo-notes-${SESSION}"
MARKER="${MARKER_DIR}/${REPO}"
[[ -f "$MARKER" ]] && exit 0

mkdir -p "$MARKER_DIR"
: > "$MARKER"

CONTENT="The following are your standing instructions for the ${REPO} repository (/workspace/${REPO}). Follow them for all work in this repo.

$(cat "$NOTE")"

jq -n --arg ctx "$CONTENT" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
exit 0
