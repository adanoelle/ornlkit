#!/bin/bash
#SBATCH -A <project_id>
#SBATCH -J ornlkit
#SBATCH -N 1
#SBATCH -t 00:05:00
#SBATCH -p batch
#SBATCH -o runs/ornlkit/%j.log

# --- Frontier smoke test for ornlkit ---
#
# Via justfile (recommended):
#   just submit account=ABC123
#   just submit account=ABC123 app.greeting="Hi"
#
# Standalone:
#   sbatch jobs/hello.sbatch
#   sbatch -A ABC123 jobs/hello.sbatch app.greeting="Hi"

set -euo pipefail

module load miniforge3/23.11.0-0

export PATH="$HOME/.local/bin:$PATH"   # ensure uv is on PATH
export UV_CACHE_DIR="/tmp/uv-cache-$USER"  # Lustre doesn't support file locking

run_dir="runs/ornlkit/${SLURM_JOB_ID:-local}"
mkdir -p "$run_dir"

uv run ornlkit hydra.run.dir="$run_dir" "$@"
