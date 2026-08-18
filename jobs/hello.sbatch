#!/bin/bash
#SBATCH -A <project_id>
#SBATCH -J ornlkit-hello
#SBATCH -N 1
#SBATCH -t 00:05:00
#SBATCH -p batch
#SBATCH -o logs/ornlkit-hello-%j.out
#SBATCH -e logs/ornlkit-hello-%j.err

# --- Frontier smoke test for ornlkit ---
# Submit with:  sbatch jobs/hello.sbatch

set -euo pipefail

module load miniforge3/23.11.0-0

export PATH="$HOME/.local/bin:$PATH"   # ensure uv is on PATH

mkdir -p logs

uv run python3 -u -m ornlkit
