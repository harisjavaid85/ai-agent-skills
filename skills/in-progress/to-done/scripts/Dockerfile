FROM node:22-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl jq ca-certificates gnupg \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

# Resolves pnpm to the version each project pins in packageManager.
RUN corepack enable

# Installed as root: npm's global prefix is not writable by the agent user.
RUN npm install -g @openai/codex

# Sandcastle checks these against its containerUid/containerGid before starting
# a container, so build-image.sh passes the host user's values.
ARG AGENT_UID=1000
ARG AGENT_GID=1000
RUN groupmod -o -g $AGENT_GID node \
  && usermod -o -u $AGENT_UID -g $AGENT_GID -d /home/agent -m -l agent node
USER ${AGENT_UID}:${AGENT_GID}

ENV PATH="/home/agent/.local/bin:$PATH"

# pnpm 11 reads none of this from .npmrc or npm_config_*; its own config is
# ~/.config/pnpm/config.yaml, in camelCase. The generous fetch timeout is
# because one timed-out tarball fails a whole phase.
RUN mkdir -p /home/agent/.config/pnpm /home/agent/.pnpm-store \
  && printf 'storeDir: /home/agent/.pnpm-store\nfetchTimeout: 600000\nfetchRetries: 5\n' \
       > /home/agent/.config/pnpm/config.yaml

RUN curl -fsSL https://claude.ai/install.sh | bash

# Language toolchains belong to the project's `.to-done/Dockerfile`, which
# builds FROM this image.

# Skills are baked so no phase pays an install cost. Rebuild to pick up an edit.
#
# `#<ref>`, not `@<ref>`: `@` selects a *skill name*, so `repo@<sha>` was
# silently discarded by `--all` and exited 0 while installing the default
# branch. `#<ref>` fails loudly on a bad ref, but takes only branches and
# tags, which is why the pin is a ref rather than a sha.
ARG SKILLS_REPO
ARG SKILLS_REF
# The sha cannot be installed from, but it has to be in this layer's cache key.
# `<ref>` is a branch name, which does not change when the branch moves, so
# without the sha here Docker reuses the cached install, and since the label
# below still gets the new sha, loop.mts compares it to HEAD, sees a match, and
# reports the image current while the agents run whatever the branch held last
# time. A wrong answer with the alarm disabled, so pay a rebuild instead.
ARG SKILLS_SHA
RUN test -n "${SKILLS_REPO}" && test -n "${SKILLS_REF}" && test -n "${SKILLS_SHA}" \
  && npx --yes skills@latest add "${SKILLS_REPO}#${SKILLS_REF}" --all -g -y

LABEL to-done.skills-sha="${SKILLS_SHA}"
LABEL to-done.skills-ref="${SKILLS_REF}"

WORKDIR /home/agent

# Sandcastle bind-mounts the git worktree at /home/agent/workspace and starts
# the container's working directory there.
ENTRYPOINT ["sleep", "infinity"]
