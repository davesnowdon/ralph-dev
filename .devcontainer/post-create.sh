#!/bin/bash
set -euo pipefail

echo "Ralph dev container bootstrap"
echo "Workspace: $(pwd)"

echo
echo "Available tools:"
python --version
git --version
uv --version
docker --version || true

echo
echo "Docker socket:"
if [ -S /var/run/docker.sock ]; then
  ls -l /var/run/docker.sock
else
  echo "Docker socket not mounted at /var/run/docker.sock"
fi

echo
echo "Submodules:"
git submodule status || true

echo
echo "Dev container ready. No package installation was performed."
