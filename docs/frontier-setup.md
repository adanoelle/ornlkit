# Frontier setup

One-time setup for a comfortable dev environment on Frontier, where Nix is not
available. Covers shell, CLI tools (`just`, `gum`), UV, and project bootstrap.

## 1. Shell — fish via Homebrew

Frontier offers bash and zsh but not fish. Install it via Linuxbrew into your
project space so it survives across sessions:

```bash
# Install Homebrew to project space (one-time, takes a few minutes)
export HOMEBREW_PREFIX="/ccs/proj/<project_id>/$USER/.linuxbrew"
git clone https://github.com/Homebrew/brew "$HOMEBREW_PREFIX/Homebrew"
mkdir -p "$HOMEBREW_PREFIX/bin"
ln -sf "$HOMEBREW_PREFIX/Homebrew/bin/brew" "$HOMEBREW_PREFIX/bin/brew"
eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"

# Install fish
brew install fish
```

Add to your `~/.bashrc` (the login shell) so it auto-launches fish:

```bash
# --- Linuxbrew + fish ---
export HOMEBREW_PREFIX="/ccs/proj/<project_id>/$USER/.linuxbrew"
eval "$($HOMEBREW_PREFIX/bin/brew shellenv)"
if [ -t 1 ] && command -v fish &>/dev/null; then
  exec fish -l
fi
```

After this, every new SSH session or interactive allocation drops straight into
fish. Non-interactive shells (sbatch scripts, srun commands) are unaffected
since they use `#!/bin/bash` and `[ -t 1 ]` is false.

### fish config

Create `~/.config/fish/config.fish`:

```fish
# Project space tools
set -gx PATH /ccs/proj/<project_id>/$USER/.local/bin $PATH

# UV
set -gx UV_PYTHON_PREFERENCE only-system
set -gx UV_CACHE_DIR /tmp/uv-cache-$USER
```

## 2. CLI tools

### just

Download a static binary — no build step required:

```bash
# Pick the latest release from https://github.com/casey/just/releases
curl -L https://github.com/casey/just/releases/latest/download/just-x86_64-unknown-linux-musl.tar.gz \
  | tar xz -C /ccs/proj/<project_id>/$USER/.local/bin just
just --version
```

### gum (optional)

Enables the interactive `just submit` prompts. Without it, `just submit` falls
back to the non-interactive path (provide args on the CLI).

```bash
brew install gum
```

Or grab the static binary:

```bash
# Check https://github.com/charmbracelet/gum/releases for latest version
GUM_VERSION="0.16.0"
curl -L "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_x86_64.tar.gz" \
  | tar xz -C /ccs/proj/<project_id>/$USER/.local/bin gum
gum --version
```

## 3. UV + Python

```bash
# Load the system Python
module load miniforge3/23.11.0-0

# Install UV (one-time)
curl -LsSf https://astral.sh/uv/install.sh \
  | env UV_INSTALL_DIR=/ccs/proj/<project_id>/$USER/.local/bin sh
```

## 4. Project bootstrap

```bash
module load miniforge3/23.11.0-0

cd /ccs/proj/<project_id>/$USER
git clone <repo-url> ornlkit && cd ornlkit
just sync                         # build compute venv

# Verify
just submit account=<project_id>  # submit a test job
```

> `just sync` creates `.venv-frontier/` for compute nodes using miniforge3 Python.
> Dev commands (`just test`, `just lint`) use a separate `.venv/` managed automatically by uv.

## 5. Submit a job

```bash
# Interactive (requires gum)
just submit

# Non-interactive
just submit account=ABC123
just submit account=ABC123 nodes=2 time=00:30:00

# Monitor
just jobs
just last-log
```

## Checklist

- [ ] Linuxbrew + fish installed to project space
- [ ] `~/.bashrc` auto-launches fish
- [ ] `~/.config/fish/config.fish` sets PATH and UV env vars
- [ ] `just` binary in `~/.local/bin`
- [ ] `gum` binary in `~/.local/bin` (optional)
- [ ] UV installed
- [ ] `just sync` succeeds in the repo
- [ ] `just check` passes
- [ ] `just submit account=<project_id>` submits successfully
