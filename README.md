# dev_setup

macOS developer environment dotfiles. Clone and run one command on a fresh Mac to restore the full setup.

## Quick start

```bash
git clone https://github.com/jcakstins/dev_setup.git ~/github/dev_setup
bash ~/github/dev_setup/bootstrap.sh
```

Then install OrbStack manually: https://orbstack.dev

## What gets installed

**Terminal & shell**
- [Kitty](https://sw.kovidgoyal.net/kitty/) — GPU-accelerated terminal (Idle Toes theme, JetBrainsMono Nerd Font)
- [Starship](https://starship.rs/) — prompt showing git, python, terraform, k8s context
- [zsh-vi-mode](https://github.com/jeffreytse/zsh-vi-mode) — vim keybindings in the shell
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) — inline history suggestions
- [fzf](https://github.com/junegunn/fzf) + [zoxide](https://github.com/ajeetdsouza/zoxide) + [bat](https://github.com/sharkdp/bat) + [ripgrep](https://github.com/BurntSushi/ripgrep) + [fd](https://github.com/sharkdp/fd) + [jq](https://jqlang.org/)
- [tmux](https://github.com/tmux/tmux) on the [Oh my tmux!](https://github.com/gpakosz/.tmux) config (`tmux/`) — session persistence layered on top of kitty, which still owns pane splits/nav and tabs. Prefix is `Ctrl+a`. [sesh](https://github.com/joshmedeski/sesh) + fzf for session switching (`<prefix> T`, or `tm`/`tma` aliases before tmux is even running), [tmuxp](https://github.com/tmux-python/tmuxp) for YAML-defined project layouts, tmux-resurrect + tmux-continuum (via TPM) for auto-saved/restored sessions. Nothing auto-attaches — tmux is opt-in

**Editor**
- [Cursor](https://cursor.sh/) with 16 extensions (Python, Git, containers, YAML/TOML)
- [vim-kitty-navigator](https://github.com/knubie/vim-kitty-navigator) — seamless `Ctrl+hjkl` navigation between kitty panes and nvim splits

**Python**
- Python 3.13 + 3.14 via Homebrew
- [uv](https://docs.astral.sh/uv/) — fast package/project manager
- [pre-commit](https://pre-commit.com/) — git hook framework
- Templates for `pyproject.toml` and `.pre-commit-config.yaml` in `python/`

**Infrastructure**
- [tfenv](https://github.com/tfutils/tfenv) — terraform version manager (installs latest + 1.5.7)
- terraform-docs, tflint, [tilt](https://tilt.dev/), [opentofu](https://opentofu.org/), [trufflehog](https://github.com/trufflesecurity/trufflehog)
- kubectl, [OrbStack](https://orbstack.dev/) (Docker + Linux VMs)

**Apps**
- 1Password + 1Password CLI, Postman, DBeaver, Kitty, Cursor

## Repository structure

```
dev_setup/
├── bootstrap.sh                    # run this on a new Mac
├── Brewfile                        # all Homebrew packages and casks
├── .secrets.example                # template for API keys → copy to ~/.secrets
├── zsh/
│   ├── .zshrc                      # interactive shell config
│   └── .zprofile                   # login shell (Homebrew, Python path, OrbStack)
├── git/
│   ├── .gitconfig                  # aliases, rebase pull, SSH rewrite, cursor diff
│   └── .gitignore_global           # global ignore (Python, Node, Terraform, secrets)
├── kitty/
│   └── kitty.conf                  # Idle Toes theme, Nerd Font, vim-kitty-navigator
├── starship/
│   └── starship.toml               # prompt modules
├── tmux/
│   ├── .tmux.conf                  # Oh my tmux! base (don't edit — see .tmux.conf.local)
│   └── .tmux.conf.local            # prefix Ctrl+a, mouse, vi copy-mode, sesh picker, resurrect/continuum
├── cursor/
│   └── extensions.txt              # extension list (installed by install/apps.sh)
├── python/
│   ├── pyproject.toml.template     # project template (ruff, mypy, pytest, bandit…)
│   └── .pre-commit-config.yaml.template
├── install/
│   ├── macos.sh                    # macOS system defaults
│   ├── dev.sh                      # tfenv versions, uv tools, shell completions
│   └── apps.sh                     # Cursor + VS Code extension installer
└── docs/
    └── REFERENCE.md                # full shortcut cheat sheet + tool docs
```

## Dotfiles are symlinked

`bootstrap.sh` symlinks config files into place rather than copying them, so edits in the repo take effect immediately:

```
~/.zshrc                   → dev_setup/zsh/.zshrc
~/.zprofile                → dev_setup/zsh/.zprofile
~/.gitconfig               → dev_setup/git/.gitconfig
~/.gitignore_global        → dev_setup/git/.gitignore_global
~/.config/kitty/kitty.conf → dev_setup/kitty/kitty.conf
~/.config/starship.toml    → dev_setup/starship/starship.toml
~/.tmux.conf               → dev_setup/tmux/.tmux.conf
~/.tmux.conf.local         → dev_setup/tmux/.tmux.conf.local
```

`bootstrap.sh` also clones [TPM](https://github.com/tmux-plugins/tpm) and the tmux-resurrect/tmux-continuum plugins into `~/.tmux/plugins/` (git clones, not symlinks — same spot tmux itself expects them).

## API keys

Copy `.secrets.example` to `~/.secrets` and fill in your values. It is sourced by `.zshrc` and ignored by git globally.

```bash
cp ~/github/dev_setup/.secrets.example ~/.secrets
chmod 600 ~/.secrets
cursor ~/.secrets
```

## Reference

See [`docs/REFERENCE.md`](docs/REFERENCE.md) for the full cheat sheet covering:
- Kitty shortcuts (splits, tabs, font size, scrollback)
- zsh vi mode (INSERT / NORMAL / VISUAL)
- All shell aliases and functions
- fzf, zoxide, uv, tfenv, git config highlights
- Neovim getting started
