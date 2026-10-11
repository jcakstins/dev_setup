#!/usr/bin/env bash
# =============================================================================
#  install/dev.sh — Post-Homebrew dev tooling setup
#  Called by bootstrap.sh; safe to re-run (idempotent)
# =============================================================================
set -euo pipefail

log()  { printf '\033[0;32m==>\033[0m %s\n' "$*"; }
info() { printf '\033[0;34m   →\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

# uv-managed pythons and uv tools live here; make them visible to this script
export PATH="${HOME}/.local/bin:${PATH}"

# ── uv: Python interpreters ───────────────────────────────────────────────────
log "uv — Python interpreters"

PYTHON_DEFAULT="3.13"         # becomes `python` / `python3` in ~/.local/bin
PYTHON_EXTRA=(3.14)           # also available as `python3.14`

if ! command -v uv &>/dev/null; then
  warn "uv not found — skipping Python install (run after Brewfile install)"
else
  info "uv version: $(uv --version)"

  info "Installing Python ${PYTHON_DEFAULT} (default)..."
  uv python install --default --preview-features python-install-default "$PYTHON_DEFAULT" \
    || warn "Failed to install Python ${PYTHON_DEFAULT}"

  for v in "${PYTHON_EXTRA[@]}"; do
    info "Installing Python ${v}..."
    uv python install "$v" || warn "Failed to install Python ${v}"
  done
fi

# ── uv: global tools ──────────────────────────────────────────────────────────
log "uv global tools"

if command -v uv &>/dev/null; then
  # Global tools installed via 'uv tool' — isolated from project environments
  UV_TOOLS=(
    ruff      # fast Python linter + formatter (useful globally for quick scripts)
    ipython   # enhanced interactive Python REPL
    httpie    # user-friendly curl alternative (`http` command)
  )

  for tool in "${UV_TOOLS[@]}"; do
    if grep -q "^${tool} " <<<"$(uv tool list 2>/dev/null)"; then
      info "${tool} already installed"
    else
      info "Installing ${tool} via uv tool..."
      uv tool install "$tool" || warn "Failed to install ${tool}"
    fi
  done
fi

# ── tenv: Terraform + OpenTofu versions ───────────────────────────────────────
log "tenv — Terraform / OpenTofu version management"

if ! command -v tenv &>/dev/null; then
  warn "tenv not found — skipping terraform/tofu install (run after Brewfile install)"
else
  info "tenv version: $(tenv --version 2>&1)"

  # `install` is a no-op if the version is already present
  info "Installing latest Terraform..."
  tenv tf install latest
  tenv tf use latest

  # Also keep 1.5.7 available (last version before the BSL licence change)
  info "Installing Terraform 1.5.7 (pre-BSL)..."
  tenv tf install 1.5.7

  info "Installing latest OpenTofu..."
  tenv tofu install latest
  tenv tofu use latest

  info "Terraform versions: $(tenv tf list 2>/dev/null | tr -s '[:space:]' ' ')"
  info "OpenTofu versions:  $(tenv tofu list 2>/dev/null | tr -s '[:space:]' ' ')"
fi

# ── Docker (Colima runtime) ───────────────────────────────────────────────────
log "Docker CLI plugins"

# Let the docker CLI find Homebrew's docker-compose as `docker compose`
DOCKER_CONFIG_FILE="${HOME}/.docker/config.json"
PLUGINS_DIR="${HOMEBREW_PREFIX:-/opt/homebrew}/lib/docker/cli-plugins"
mkdir -p "$(dirname "$DOCKER_CONFIG_FILE")"
[[ -s "$DOCKER_CONFIG_FILE" ]] || echo '{}' > "$DOCKER_CONFIG_FILE"

if jq -e --arg d "$PLUGINS_DIR" '(.cliPluginsExtraDirs // []) | index($d)' "$DOCKER_CONFIG_FILE" &>/dev/null; then
  info "cliPluginsExtraDirs already includes ${PLUGINS_DIR}"
else
  info "Adding ${PLUGINS_DIR} to cliPluginsExtraDirs..."
  tmp="$(mktemp)"
  jq --arg d "$PLUGINS_DIR" '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$d])' \
    "$DOCKER_CONFIG_FILE" > "$tmp" && mv "$tmp" "$DOCKER_CONFIG_FILE"
fi

# ── Shell completions ─────────────────────────────────────────────────────────
log "Shell completions"

COMPLETIONS_DIR="${HOME}/.zsh/completions"
mkdir -p "$COMPLETIONS_DIR"

# name → command that prints a zsh completion script
gen_completion() {
  local name="$1"; shift
  if ! command -v "$name" &>/dev/null; then
    warn "${name} not found — skipping completions"
  elif [[ -f "${COMPLETIONS_DIR}/_${name}" ]]; then
    info "${name} completions already present"
  else
    info "Generating ${name} completions..."
    "$@" > "${COMPLETIONS_DIR}/_${name}" || warn "Failed to generate ${name} completions"
  fi
}

gen_completion kubectl kubectl completion zsh
gen_completion gh      gh completion -s zsh
gen_completion docker  docker completion zsh
gen_completion colima  colima completion zsh
gen_completion uv      uv generate-shell-completion zsh
# terraform completions are wired up in .zshrc via bashcompinit

# ── ripgrep config ────────────────────────────────────────────────────────────
log "ripgrep config"

RIPGREP_RC="${HOME}/.ripgreprc"
if [[ ! -f "$RIPGREP_RC" ]]; then
  info "Creating ${RIPGREP_RC}..."
  cat > "$RIPGREP_RC" << 'EOF'
# ripgrep configuration file (~/.ripgreprc)
# Referenced by: RIPGREP_CONFIG_PATH in .zshrc

--smart-case
--follow
--glob=!.git/*
--glob=!node_modules/*
--glob=!.venv/*
--glob=!__pycache__/*
--glob=!*.pyc
--glob=!.terraform/*
--glob=!.DS_Store
--max-columns=200
--max-columns-preview
EOF
else
  info "${RIPGREP_RC} already exists"
fi

# ── Tool verification ─────────────────────────────────────────────────────────
log "Tool verification"

TOOLS=(
  git gh jq rg fd bat fzf zoxide starship
  tmux tmuxp sesh
  uv python python3 ruff
  tenv terraform tofu terraform-docs tflint tilt kubectl
  colima docker docker-compose
  trufflehog pre-commit op claude
)
for tool in "${TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    # Capture whole output then keep line 1 — piping to `head` can SIGPIPE under pipefail
    case "$tool" in
      kubectl) version=$(kubectl version --client 2>&1 || true) ;;
      tmux)    version=$(tmux -V 2>&1 || true) ;;
      tilt)    version=$(tilt version 2>&1 || true) ;;
      *)       version=$("$tool" --version 2>&1 || true) ;;
    esac
    version="${version%%$'\n'*}"
    info "${tool}: ${version}"
  else
    warn "${tool}: NOT FOUND"
  fi
done

log "dev.sh complete."
