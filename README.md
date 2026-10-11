# dev_setup

macOS developer environment dotfiles. Clone and run one command on a fresh Mac to restore the full setup.

## Quick start

```bash
git clone https://github.com/jcakstins/dev_setup.git ~/github/dev_setup
bash ~/github/dev_setup/bootstrap.sh
```

Re-running is safe: anything already installed is skipped, and existing config files that differ are backed up to `~/.dotfiles-backup/<timestamp>/` before being replaced. Then start Docker when needed: `colima start`.

## How it works

| Layer | Tool | Config | Manages |
|-------|------|--------|---------|
| Apps & CLI tools | [Homebrew](https://brew.sh) | `Brewfile` | everything installed system-wide |
| Dotfiles & setup | [chezmoi](https://chezmoi.io) | `home/` | dotfiles, zsh/tmux plugins, `~/.secrets`, macOS defaults, editor extensions, completions |
| Tool versions | [mise](https://mise.jdx.dev) | `home/dot_config/mise/config.toml` | python, terraform, opentofu, tflint, ruff, ipython, httpie |

`bootstrap.sh` installs Homebrew + the Brewfile, then runs `chezmoi apply`, which writes the dotfiles and runs the setup scripts (`mise install`, macOS defaults, …). Each script re-runs only when its own content changes.

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
- [uv](https://docs.astral.sh/uv/) — package/project manager; creates venvs and downloads project Pythons on demand
- One global Python (latest stable) via mise; no other global languages (add per project with `mise use`)
- [pre-commit](https://pre-commit.com/) — git hook framework
- Templates for `pyproject.toml` and `.pre-commit-config.yaml` in `python/`

**Infrastructure**
- Terraform (1.16 + 1.5.7), OpenTofu and tflint via [mise](https://mise.jdx.dev)
- terraform-docs, [tilt](https://tilt.dev/), [trufflehog](https://github.com/trufflesecurity/trufflehog)
- kubectl, [Colima](https://github.com/abiosoft/colima) + Docker CLI + Docker Compose

**Apps**
- 1Password + 1Password CLI, Kitty, Cursor, [Claude Code](https://claude.com/claude-code)

## Repository structure

```
dev_setup/
├── bootstrap.sh                    # run this on a new Mac
├── Brewfile                        # all Homebrew packages and casks
├── .chezmoiroot                    # points chezmoi at home/
├── home/                           # chezmoi source: dot_zshrc → ~/.zshrc, etc.
│   ├── .chezmoi.toml.tmpl          # per-machine data (git email)
│   ├── .chezmoiexternal.toml       # zsh + tmux plugins (git clones, refreshed weekly)
│   ├── .chezmoiscripts/            # macos defaults, mise install, extensions, completions
│   ├── .chezmoitemplates/
│   │   └── cursor-extensions.txt   # editor extension list
│   ├── create_private_dot_secrets  # ~/.secrets template (created once, never overwritten)
│   ├── dot_zshrc, dot_zprofile     # shell config
│   ├── dot_gitconfig.tmpl, dot_gitignore_global
│   ├── dot_tmux.conf, dot_tmux.conf.local   # Oh my tmux! + local overrides
│   ├── dot_ripgreprc
│   ├── dot_docker/modify_config.json        # adds docker-compose plugin path, keeps the rest
│   └── dot_config/
│       ├── kitty/kitty.conf        # Idle Toes theme, Nerd Font, vim-kitty-navigator
│       ├── starship.toml           # prompt modules
│       └── mise/config.toml        # global tool versions
├── python/
│   ├── pyproject.toml.template     # project template (ruff, mypy, pytest, bandit…)
│   └── .pre-commit-config.yaml.template
└── docs/
    └── REFERENCE.md                # full shortcut cheat sheet + tool docs
```

## Editing dotfiles

chezmoi **copies** files into place (the repo is the source of truth), so after editing run `chezmoi apply`:

```bash
chezmoi edit ~/.zshrc        # edit the source file in the repo
chezmoi diff                 # preview what apply would change
chezmoi apply                # write changes (and re-run any changed setup scripts)
chezmoi add ~/.config/foo    # start managing a new file
chezmoi cd                   # jump into the repo's home/ dir
```

Git email defaults to the personal address; on a work Mac set `DOTFILES_GIT_EMAIL` before the first bootstrap (or edit `~/.config/chezmoi/chezmoi.toml`).

## Tool versions (mise)

Edit `home/dot_config/mise/config.toml`, then `chezmoi apply` (runs `mise install`). Per project, put a `mise.toml` or `.terraform-version` in the repo root and the version switches on `cd`.

## API keys

`~/.secrets` is created from the template on first run (mode 600, never overwritten afterwards). Fill in your values; it is sourced by `.zshrc` and ignored by git globally.

```bash
cursor ~/.secrets
```

## Reference

See [`docs/REFERENCE.md`](docs/REFERENCE.md) for the full cheat sheet covering:
- Kitty shortcuts (splits, tabs, font size, scrollback)
- zsh vi mode (INSERT / NORMAL / VISUAL)
- All shell aliases and functions
- fzf, zoxide, uv, mise, chezmoi, git config highlights
- Neovim getting started
