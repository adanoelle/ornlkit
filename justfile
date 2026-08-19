# ornlkit justfile — dev workflows and SLURM submission

# --- SLURM defaults (override on CLI or via env) ---
account      := env("ORNLKIT_ACCOUNT", "")
script       := "jobs/hello.sbatch"
job_name     := "ornlkit"
nodes        := "1"
time         := "00:05:00"
partition    := "batch"

# ── Dev recipes ──────────────────────────────────

# List available recipes
default:
    @just --list

# Run pytest
test *args:
    uv run pytest {{ args }}

# Lint with ruff
lint:
    uv run ruff check .

# Format with ruff
fmt:
    uv run ruff format . && uv run ruff check --fix .

# Type-check with ty
typecheck:
    uv run ty check

# Run lint, typecheck, and tests
check: lint typecheck test

# Local run with unified output dir
run *hydra_args:
    #!/usr/bin/env bash
    set -euo pipefail
    timestamp=$(date +%Y%m%d-%H%M%S)
    run_dir="runs/{{ job_name }}/local-${timestamp}"
    mkdir -p "${run_dir}"
    uv run ornlkit hydra.run.dir="${run_dir}" {{ hydra_args }}

# ── SLURM recipes ────────────────────────────────

# Submit a SLURM job (requires account=<project_id>)
submit *hydra_args:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ account }}" ]; then
        echo "Error: account is required. Usage: just submit account=ABC123 [hydra_args...]" >&2
        exit 1
    fi
    mkdir -p "runs/{{ job_name }}"
    jobid=$(sbatch --parsable \
        -A {{ account }} \
        -J {{ job_name }} \
        -N {{ nodes }} \
        -t {{ time }} \
        -p {{ partition }} \
        -o "runs/{{ job_name }}/%j.log" \
        {{ script }} {{ hydra_args }})
    echo "Submitted job ${jobid}"
    echo "  SLURM log: runs/{{ job_name }}/${jobid}.log"
    echo "  Hydra dir: runs/{{ job_name }}/${jobid}/"

# Show running jobs for this project
jobs:
    squeue -u "$USER" -n {{ job_name }} -o "%.10i %.9P %.20j %.8u %.2t %.10M %.6D %R"

# Print the most recent SLURM log
last-log:
    #!/usr/bin/env bash
    set -euo pipefail
    log=$(ls -t runs/{{ job_name }}/*.log 2>/dev/null | head -1)
    if [ -z "$log" ]; then
        echo "No logs found in runs/{{ job_name }}/" >&2
        exit 1
    fi
    echo "==> ${log}"
    cat "$log"

# ── Cleanup ──────────────────────────────────────

# Remove all runs
clean-runs:
    rm -rf runs/

# Remove legacy output dirs (outputs/, multirun/, logs/)
clean-legacy:
    rm -rf outputs/ multirun/ logs/

# Remove all generated output
clean: clean-runs clean-legacy
