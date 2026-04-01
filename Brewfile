# Brewfile — managed by dev_setup dotfiles
# Run: brew bundle --file=Brewfile
# Generated for macOS 15 Sequoia, Apple Silicon

# ── Core utilities ────────────────────────────────────────────────────────────
brew "bat"            # better cat with syntax highlighting
brew "fd"             # better find
brew "fzf"            # fuzzy finder
brew "gh"             # GitHub CLI
brew "git"            # version control
brew "ripgrep"        # fast grep (rg)
brew "zoxide"         # smarter cd

# ── Shell ─────────────────────────────────────────────────────────────────────
brew "starship"       # cross-shell prompt

# ── Python ────────────────────────────────────────────────────────────────────
brew "python@3.13"    # primary Python (unversioned symlinks via .zprofile)
brew "python@3.14"    # secondary Python
brew "uv"             # fast Python package/project manager
brew "pre-commit"     # git hook framework

# ── Node ──────────────────────────────────────────────────────────────────────
brew "node"           # Node.js (current)

# ── Infrastructure / DevOps ───────────────────────────────────────────────────
# NOTE: terraform is managed by tfenv — do NOT install terraform directly via brew
brew "tfenv"          # terraform version manager (use: tfenv install <version>)
brew "terraform-docs" # generate terraform docs
brew "tflint"         # terraform linter
brew "tilt"           # local dev orchestration for Kubernetes
brew "docker-compose" # Docker Compose v2 (standalone binary, required by tilt)
brew "opentofu"       # open-source Terraform fork
brew "trufflehog"     # secrets scanner
brew "kubectl"        # Kubernetes CLI

# ── Security & code quality ───────────────────────────────────────────────────
# (pre-commit listed above under Python)

# ── Casks ─────────────────────────────────────────────────────────────────────
cask "font-jetbrains-mono-nerd-font"  # monospace font with Nerd Font icons
cask "kitty"                          # GPU-accelerated terminal emulator
cask "cursor"                         # AI code editor (Cursor)
cask "dbeaver-community"              # universal database client
cask "postman"                        # API development & testing
cask "1password"                      # password manager
cask "1password-cli"                  # 1Password CLI (op) for terminal access

# ── Docker runtime (pick ONE) ─────────────────────────────────────────────────
# macOS has no built-in Docker daemon — one of the options below is required.
#
# Option A: OrbStack — best experience, but requires a paid license for commercial use.
#           Disable this if you don't have a license and use Colima instead.
cask "orbstack"
#
# Option B: Colima — free/open-source, no license concerns, works anywhere.
#           Enable this (and uncomment docker CLI below) if you don't have an OrbStack license.
# brew "colima"
# brew "docker"          # Docker CLI (daemon provided by Colima)
