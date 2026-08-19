#!/bin/bash
# Prefer `just submit` — see justfile for unified run output management.
#SBATCH -A <project_id>
#SBATCH -J ornlkit-hello
#SBATCH -N 1
#SBATCH -t 00:05:00
#SBATCH -p batch
#SBATCH -o logs/ornlkit-hello-%j.log

# --- Frontier smoke test for ornlkit ---
# Submit with:  sbatch jobs/hello.sbatch
#
# CLI overrides (Hydra):
#   uv run ornlkit app.greeting="Hello Frontier"
#   uv run ornlkit --multirun app.greeting="Hello","Hi"

set -euo pipefail

module load miniforge3/23.11.0-0

export PATH="$HOME/.local/bin:$PATH"   # ensure uv is on PATH
export UV_CACHE_DIR="/tmp/uv-cache-$USER"  # Lustre doesn't support file locking

mkdir -p logs

uv run ornlkit
