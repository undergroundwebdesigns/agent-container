#!/bin/bash
set -e

# Initialize firewall (requires NET_ADMIN + NET_RAW capabilities)
sudo /usr/local/bin/init-firewall.sh

if [ -e /claude-config/claude.json ] && [ ! -e ~/.claude/.claude.json ]; then
  cp /claude-config/claude.json ~/.claude/.claude.json
fi

cp /claude-config/.gitconfig ~/.claude/.gitconfig
cp /claude-config/settings.json ~/.claude/settings.json
cp /claude-config/CLAUDE.md ~/.claude/CLAUDE.md

mkdir -p ~/.claude/agents
mkdir -p ~/.claude/commands

#cp /claude-config/commands/* ~/.claude/commands/
cp /claude-config/agents/* ~/.claude/agents/

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 4. Execute the command inside tmux
# If no command is passed ($@ is empty), default to an interactive bash shell
if [ $# -eq 0 ]; then
  exec tmux new-session -s "claude" /bin/bash
else
  # Wrap the CMD arguments so tmux runs them as a single command string
  exec tmux new-session -s "claude" "/bin/bash -c \"$*\""
fi
