# .devcontainer/Dockerfile
FROM python:3.12-slim

# Install system deps
RUN apt-get update && apt-get install -y \
    git \
    ca-certificates \
    make \
    && rm -rf /var/lib/apt/lists/*

# Install uv and shell linting tools
RUN pip install uv shellcheck-py shfmt-py

# Create non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

USER $USERNAME
WORKDIR /workspace
