#!/usr/bin/env bash
# =============================================================================
#  install/dev.sh — Post-Homebrew dev tooling setup
#  Called by bootstrap.sh; safe to re-run (idempotent)
# =============================================================================
set -euo pipefail

log()  { printf '\033[0;32m==>\033[0m %s\n' "$*"; }
info() { printf '\033[0;34m   →\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

# ── tfenv: install terraform versions ────────────────────────────────────────
log "tfenv — Terraform version management"

if ! command -v tfenv &>/dev/null; then
  warn "tfenv not found — skipping terraform install (run after Brewfile install)"
else
  info "tfenv version: $(tfenv --version 2>&1 | head -1)"

  # Install latest stable terraform
  if ! tfenv list 2>/dev/null | grep -q "latest"; then
    info "Installing latest terraform..."
    tfenv install latest
  fi
  tfenv use latest
  info "Active terraform: $(terraform version | head -1)"

  # Also keep 1.5.7 available (last version before BSL licence change)
  if ! tfenv list 2>/dev/null | grep -q "1.5.7"; then
    info "Installing terraform 1.5.7 (pre-BSL)..."
    tfenv install 1.5.7
  else
    info "terraform 1.5.7 already installed"
  fi

  info "Available terraform versions:"
  tfenv list 2>/dev/null | while read -r v; do info "  $v"; done
fi

# ── uv: install global tools ──────────────────────────────────────────────────
log "uv global tools"

if ! command -v uv &>/dev/null; then
  warn "uv not found — skipping global tool install"
else
  info "uv version: $(uv --version)"

  # Global tools installed via 'uv tool' — isolated from project environments
  UV_TOOLS=(
    ruff      # fast Python linter + formatter (useful globally for quick scripts)
    ipython   # enhanced interactive Python REPL
    httpie    # user-friendly curl alternative (`http` command)
  )

  for tool in "${UV_TOOLS[@]}"; do
    if uv tool list 2>/dev/null | grep -q "^${tool} "; then
      info "${tool} already installed"
    else
      info "Installing ${tool} via uv tool..."
      uv tool install "$tool" || warn "Failed to install ${tool}"
    fi
  done
fi

# ── Shell completions ─────────────────────────────────────────────────────────
log "Shell completions"

COMPLETIONS_DIR="${HOME}/.zsh/completions"
mkdir -p "$COMPLETIONS_DIR"

# kubectl completions
if command -v kubectl &>/dev/null; then
  if [[ ! -f "${COMPLETIONS_DIR}/_kubectl" ]]; then
    info "Generating kubectl completions..."
    kubectl completion zsh > "${COMPLETIONS_DIR}/_kubectl"
  else
    info "kubectl completions already present"
  fi
else
  warn "kubectl not found — skipping completions"
fi

# terraform completions (only if terraform is managed by tfenv and available)
if command -v terraform &>/dev/null; then
  if [[ ! -f "${COMPLETIONS_DIR}/_terraform" ]]; then
    info "Generating terraform completions..."
    # terraform -install-autocomplete writes to .zshrc; we do it manually instead
    terraform -install-autocomplete 2>/dev/null || true
  else
    info "terraform completions already present"
  fi
fi

# gh (GitHub CLI) completions
if command -v gh &>/dev/null; then
  if [[ ! -f "${COMPLETIONS_DIR}/_gh" ]]; then
    info "Generating gh completions..."
    gh completion -s zsh > "${COMPLETIONS_DIR}/_gh"
  else
    info "gh completions already present"
  fi
fi

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

# ── pre-commit ────────────────────────────────────────────────────────────────
log "pre-commit"

if command -v pre-commit &>/dev/null; then
  info "pre-commit version: $(pre-commit --version)"
else
  warn "pre-commit not found"
fi

# ── Tool verification ─────────────────────────────────────────────────────────
log "Tool verification"

TOOLS=(python3 python pip uv terraform opentofu tfenv kubectl gh git node rg fd bat fzf zoxide starship pre-commit trufflehog)
for tool in "${TOOLS[@]}"; do
  if command -v "$tool" &>/dev/null; then
    version=$("$tool" --version 2>&1 | head -1)
    info "${tool}: ${version}"
  else
    warn "${tool}: NOT FOUND"
  fi
done

log "dev.sh complete."
