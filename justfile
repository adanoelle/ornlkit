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

# Sync .venv-frontier for compute nodes (miniforge3 Python, not Nix)
sync:
    #!/usr/bin/env bash
    set -euo pipefail

    # Load miniforge3 (sets CONDA_PREFIX)
    if type module &>/dev/null; then
        module load miniforge3/23.11.0-0
    fi

    # Use CONDA_PREFIX to find miniforge3 Python (bypasses Nix PATH ordering)
    if [[ -z "${CONDA_PREFIX:-}" || ! -x "${CONDA_PREFIX}/bin/python3" ]]; then
        echo "error: CONDA_PREFIX not set or python3 not found." >&2
        echo "Run 'module load miniforge3/23.11.0-0' first." >&2
        exit 1
    fi
    frontier_python="${CONDA_PREFIX}/bin/python3"
    echo "Syncing .venv-frontier with: ${frontier_python} ($(${frontier_python} --version))"

    UV_PROJECT_ENVIRONMENT=.venv-frontier \
    UV_CACHE_DIR="/tmp/uv-cache-$USER" \
    UV_LINK_MODE=copy \
        uv sync --no-dev --python "$frontier_python" --frozen

    echo ".venv-frontier ready."

# Local run with unified output dir
run *hydra_args:
    #!/usr/bin/env bash
    set -euo pipefail
    timestamp=$(date +%Y%m%d-%H%M%S)
    run_dir="runs/{{ job_name }}/local-${timestamp}"
    mkdir -p "${run_dir}"
    uv run ornlkit hydra.run.dir="${run_dir}" {{ hydra_args }}

# ── SLURM recipes ────────────────────────────────

# Submit a SLURM job — interactive with gum, or just submit account=ABC123
submit *hydra_args:
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ ! -x .venv-frontier/bin/ornlkit ]]; then
        echo "error: .venv-frontier not found. Run 'just sync' first." >&2
        exit 1
    fi

    _account="{{ account }}"
    _script="{{ script }}"
    _nodes="{{ nodes }}"
    _time="{{ time }}"
    _partition="{{ partition }}"
    _hydra_args="{{ hydra_args }}"

    # Interactive mode: account is empty and gum is available
    if [ -z "$_account" ]; then
        if ! command -v gum &>/dev/null; then
            echo "Error: account is required. Usage: just submit account=ABC123 [hydra_args...]" >&2
            exit 1
        fi

        # Account (required — loop until non-empty)
        while [ -z "$_account" ]; do
            _account=$(gum input --prompt "Account: " --placeholder "e.g. ABC123")
        done

        # Script (choose from jobs/*.sbatch)
        _choices=$(printf '%s\n' jobs/*.sbatch)
        _script=$(echo "$_choices" | gum choose --header "Script:" --selected "$_script")

        # Nodes
        _nodes=$(gum input --prompt "Nodes: " --value "$_nodes")

        # Time
        _time=$(gum input --prompt "Time: " --value "$_time")

        # Hydra overrides (optional)
        _hydra_args=$(gum input --prompt "Hydra overrides (optional): " --value "$_hydra_args")

        # Confirmation
        _cmd="sbatch -A $_account -J {{ job_name }} -N $_nodes -t $_time -p $_partition -o runs/{{ job_name }}/%j.log $_script $_hydra_args"
        gum style --border rounded --padding "0 1" --border-foreground 4 \
            "$_cmd"
        gum confirm "Submit?" || { echo "Aborted."; exit 1; }
    fi

    mkdir -p "runs/{{ job_name }}"
    jobid=$(sbatch --parsable \
        -A "$_account" \
        -J {{ job_name }} \
        -N "$_nodes" \
        -t "$_time" \
        -p "$_partition" \
        -o "runs/{{ job_name }}/%j.log" \
        "$_script" $_hydra_args)
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
