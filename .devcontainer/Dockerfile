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

FROM buildpack-deps@sha256:f9316c98dd22c69ebfc8ff437381504bf654d9ce1f18d2b637b5af7dd05cde55

ARG TZ

ARG CLAUDE_CODE_VERSION=latest
ARG USERNAME=claude

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
  tmux \
  vim \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m $USERNAME
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

# Install Claude
RUN curl -fsSL https://claude.ai/install.sh | bash
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

USER root

RUN mkdir -p /home/$USERNAME/bin
COPY ./bin/statusline /home/$USERNAME/.local/bin/statusline
RUN chmod +x /home/$USERNAME/.local/bin/statusline

RUN chown -R $USERNAME:$USERNAME /home/$USERNAME

# Copy and set up firewall script + entrypoint
COPY init-firewall.sh /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh && \
  echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall

# Set ENV vars:
ENV TZ="$TZ"
ENV EDITOR=vim
ENV VISUAL=vim
ENV PROMPT_COMMAND='history -a'
ENV HISTFILE=/commandhistory/.bash_history
ENV DEVCONTAINER=true
ENV CLAUDE_CONFIG_DIR="/home/${USERNAME}/.claude"
ENV TERM=xterm-256color

USER $USERNAME
SHELL ["/bin/bash", "-c"]
ENV SHELL=/bin/bash

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
