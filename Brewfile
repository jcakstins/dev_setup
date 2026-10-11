# Brewfile — managed by dev_setup dotfiles
# Run: brew bundle --file=Brewfile
# macOS 15 Sequoia, Apple Silicon

# ── Core utilities ────────────────────────────────────────────────────────────
brew "bat"            # better cat with syntax highlighting
brew "fd"             # better find
brew "fzf"            # fuzzy finder
brew "gh"             # GitHub CLI
brew "git"            # version control
brew "jq"             # JSON processor
brew "ripgrep"        # fast grep (rg)
brew "zoxide"         # smarter cd

# ── Shell ─────────────────────────────────────────────────────────────────────
brew "starship"       # cross-shell prompt

# ── Terminal multiplexing ─────────────────────────────────────────────────────
brew "tmux"           # terminal multiplexer
brew "tmuxp"          # tmux session layouts from YAML/JSON
brew "sesh"           # fast tmux session switcher (fzf + zoxide aware)

# ── Dotfiles & tool versions ──────────────────────────────────────────────────
brew "chezmoi"        # dotfiles manager (home/ in this repo)
brew "mise"           # tool versions: terraform, opentofu, tflint, ruff… (~/.config/mise/config.toml)
brew "uv"             # Python package/project manager (creates venvs, downloads Pythons per project)

# ── Infrastructure / DevOps ───────────────────────────────────────────────────
# terraform, opentofu and tflint versions are managed by mise, not Homebrew
brew "terraform-docs" # generate docs from Terraform modules
brew "tilt"           # local dev orchestration for Kubernetes
brew "kubectl"        # Kubernetes CLI
brew "colima"         # container runtime (Docker daemon)
brew "docker"         # Docker CLI
brew "docker-compose" # Docker Compose v2

# ── Security & code quality ───────────────────────────────────────────────────
brew "trufflehog"     # secrets scanner
brew "pre-commit"     # git hook framework

# ── Casks ─────────────────────────────────────────────────────────────────────
cask "font-jetbrains-mono-nerd-font"  # monospace font with Nerd Font icons
cask "kitty"                          # GPU-accelerated terminal emulator
cask "cursor"                         # AI code editor
cask "1password"                      # password manager
cask "1password-cli"                  # 1Password CLI (op)
cask "claude-code"                    # Claude Code CLI (claude)
