#!/bin/bash
set -e

# Initialize firewall (requires NET_ADMIN + NET_RAW capabilities)
sudo /usr/local/bin/init-firewall.sh

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 4. Execute the command inside tmux
# If no command is passed ($@ is empty), default to an interactive bash shell
if [ $# -eq 0 ]; then
  exec tmux new-session -s "claude" /bin/bash
else
  # Wrap the CMD arguments so tmux runs them as a single command string
  exec tmux new-session -s "claude" "/bin/bash -c \"$*\""
fi
