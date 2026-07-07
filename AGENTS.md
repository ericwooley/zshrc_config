# Agent Instructions

This repository is a personal dotfiles setup for zsh, tmux, and Neovim.

## Keep Docs Current

When changing behavior, update the relevant docs in the same change:

- `bootstrap.sh`, `install.sh`, or dependency behavior: update `docs/INSTALL.md`.
- `.zshrc_config/**`: update `docs/ZSH.md`, `docs/HELPERS.md`, or `docs/REMOTE_SYNC.md`.
- `.config/nvim/**`: update `docs/NEOVIM.md` and, when keybindings or workflows change, `.zshrc_config/docs/nvim-quick-reference.md`.
- `.tmux.conf`: update `docs/TMUX.md`.
- public-facing repo structure or setup flow: update `README.md` and `docs/INDEX.md`.

If a change affects users, assume the docs need to change.

## Safety Rules

- Do not commit secrets, tokens, private keys, `.env` files, machine-local overrides, or generated caches.
- Keep `~/.zsh_local` out of the repo.
- Keep generated completion files ignored.
- Before publishing or after sensitive edits, run `gitleaks git` and `gitleaks dir` when available.
- Keep `.githooks/pre-commit` aligned with the installed `gitleaks` CLI.
- Preserve the Neovim safety model: do not add project-open hooks that run repo-local scripts, package managers, installers, or project-local binaries just because a file was opened.

## Editing Notes

- Prefer small, readable shell scripts over dense one-liners.
- Keep zsh functions one function per file under `.zshrc_config/functions/`.
- Keep executable helpers in `.zshrc_config/bin/`.
- Every file in `.zshrc_config/functions/` must have its own entry in `docs/ZSH.md`.
- Every alias in `.zshrc_config/aliases.zsh` must have its own entry in `docs/ZSH.md`.
- Every executable in `.zshrc_config/bin/` must have its own entry in `docs/HELPERS.md`.
- Keep `zshsetup` behavior documented in `docs/REMOTE_SYNC.md` whenever the remote clone or install flow changes.
- Keep README concise and link to deeper docs instead of duplicating every detail.
