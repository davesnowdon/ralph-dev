# .devcontainer/Dockerfile
FROM python:3.12-slim

# Install system deps
RUN apt-get update && apt-get install -y \
    bash \
    bash-completion \
    git \
    ca-certificates \
    make \
    && rm -rf /var/lib/apt/lists/*

# Use bash for subsequent RUN steps, including injected devcontainer feature installs.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Enable bash completion for interactive shells in the devcontainer.
RUN printf '\nif [ -f /usr/share/bash-completion/bash_completion ]; then\n  . /usr/share/bash-completion/bash_completion\nfi\n' >> /etc/bash.bashrc

# Install uv and shell linting tools
RUN pip install uv shellcheck-py shfmt-py

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME

USER $USERNAME
WORKDIR /workspace
