#!/bin/bash
set -e

echo "Installing ralph-sandbox deps..."
cd /workspace/ralph-sandbox
uv pip install --system -e ".[dev]" 2>/dev/null || pip install -e ".[dev]"

echo "Installing ralph-plus-plus deps..."
cd /workspace/ralph-plus-plus
uv pip install --system -e ".[dev]" 2>/dev/null || pip install -e ".[dev]"

echo "Dev container ready."
