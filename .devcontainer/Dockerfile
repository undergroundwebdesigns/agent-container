FROM buildpack-deps@sha256:f9316c98dd22c69ebfc8ff437381504bf654d9ce1f18d2b637b5af7dd05cde55 AS asdf-builder

ARG TARGETARCH

ENV ASDF_DATA_DIR="/builder/.asdf"
ENV ASDF_VERSION="v0.18.0"
ENV ARCH=darwin-amd64

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    extract \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $ASDF_DATA_DIR/bin

RUN echo $TARGETARCH

# 1. Download the actual binary release from GitHub
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        ASDF_ARCH="linux-arm64"; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
        ASDF_ARCH="linux-amd64"; \
    else \
        ASDF_ARCH="linux-amd64"; \
    fi && \
    curl -L -O "https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-${ASDF_ARCH}.tar.gz" \
    && tar -xzf "asdf-${ASDF_VERSION}-${ASDF_ARCH}.tar.gz" -C $ASDF_DATA_DIR/bin

# 2. Setup environment for the builder to use asdf
ENV PATH="${ASDF_DATA_DIR}/bin:${ASDF_DATA_DIR}/shims:${PATH}"

RUN ls ${ASDF_DATA_DIR}

RUN apt-get update && apt-get install -y git build-essential libssl-dev zlib1g-dev 

RUN asdf plugin add ruby
RUN asdf plugin add nodejs
RUN asdf plugin add pnpm
RUN asdf plugin add python

FROM buildpack-deps@sha256:f9316c98dd22c69ebfc8ff437381504bf654d9ce1f18d2b637b5af7dd05cde55

ARG TZ

ARG USERNAME=claude

RUN apt-get update && apt-get install -y ca-certificates curl

RUN install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/docker.asc \
  && echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  postgresql \
  glow \
  docker-ce-cli docker-compose-plugin \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install herdr
RUN curl -L -o /tmp/herdr https://github.com/ogulcancelik/herdr/releases/download/v0.7.1/herdr-linux-x86_64
RUN cp /tmp/herdr /usr/local/bin/herdr
RUN chmod +x /usr/local/bin/herdr

RUN useradd -m $USERNAME
ENV HOMEBREW_NO_SANDBOX_LINUX=1
ENV PATH="/home/$USERNAME/.local/bin:/home/$USERNAME/.asdf/bin:/home/$USERNAME/.asdf/shims:$PATH"

# Persist bash history.
RUN mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/$USERNAME/.claude && \
  chown -R $USERNAME:$USERNAME /workspace /home/$USERNAME/.claude

WORKDIR /workspace

RUN mkdir -p /home/linuxbrew/.linuxbrew
RUN chown $USERNAME /home/linuxbrew/.linuxbrew

# Some installs need to run as the user, not root:
USER $USERNAME

# Install homebrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Install pup, the DataDog CLI tool:
RUN eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew tap datadog-labs/pack && \
    brew install datadog-labs/pack/pup

USER root

RUN mkdir /plugins/
# Install DataDog Claude Plugin
RUN cd /plugins/ && \
    git clone https://github.com/DataDog/datadog-api-claude-plugin.git

# Setup tmux:
RUN mkdir -p /tmp/tmux-1001 && \
    chown $USERNAME:$USERNAME /tmp/tmux-1001 && \
    chmod 700 /tmp/tmux-1001

# Copy in ASDF:
COPY --from=asdf-builder /builder/.asdf /home/$USERNAME/.asdf
RUN chown -R $USERNAME:$USERNAME /home/$USERNAME/.asdf

USER $USERNAME
RUN asdf install nodejs latest && \
    asdf set --home nodejs latest
# Install PNPM:
RUN asdf install pnpm latest && \
    asdf set --home pnpm latest
# Install datadog API claude skills
RUN pnpm install skills && \
    pnpm exec skills add -g -y /plugins/datadog-api-claude-plugin

RUN asdf install ruby 3.2.1
RUN asdf install ruby 4.0.1
RUN asdf install python 3.13.0

# Install Claude
ARG CLAUDE_CODE_VERSION=2.1.176
ENV CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}
RUN curl -fsSL https://claude.ai/install.sh | bash -s $CLAUDE_CODE_VERSION
USER root

RUN mkdir -p /home/$USERNAME/bin
COPY ./.devcontainer/./bin/statusline /home/$USERNAME/.local/bin/statusline
RUN chmod +x /home/$USERNAME/.local/bin/statusline


COPY ./claude-config/claude.json /home/claude/.claude/.claude.json
RUN chmod 444 /home/claude/.claude/.claude.json
COPY ./claude-config/.gitconfig /home/claude/.gitconfig
RUN chmod 444 /home/claude/.gitconfig

COPY ./claude-config/settings.json /home/claude/.claude/settings.json
RUN chmod 444 /home/claude/.claude/settings.json
COPY ./claude-config/CLAUDE.md /home/claude/.claude/CLAUDE.md
RUN chmod 444 /home/claude/.claude/CLAUDE.md

#COPY ./claude-config/commands /home/claude/.claude/commands
#RUN chmod 444 /home/claude/.claude/commands
COPY ./claude-config/agents/* /home/claude/.claude/agents/
RUN chmod 444 /home/claude/.claude/agents/*

RUN chown -R $USERNAME:$USERNAME /home/$USERNAME

# Copy and set up firewall script + entrypoint
COPY ./.devcontainer/init-firewall.sh /usr/local/bin/
COPY ./.devcontainer/azure-storage-cidrs.txt /usr/local/share/azure-storage-cidrs.txt
COPY ./.devcontainer/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh && \
  echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  echo "$USERNAME ALL=(root) NOPASSWD: cp --remove-destination -rs /claude-config/* ~/.claude/" > /etc/sudoers.d/copy-configs && \
  chmod 0440 /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/copy-configs

# Set ENV vars:
ENV TZ="$TZ"
ENV EDITOR=vim
ENV VISUAL=vim
ENV PROMPT_COMMAND='history -a'
ENV HISTFILE=/commandhistory/.bash_history
ENV DEVCONTAINER=true
ENV CLAUDE_CONFIG_DIR="/home/${USERNAME}/.claude"
ENV TERM=xterm-256color
ENV CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY=1

USER $USERNAME
SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
