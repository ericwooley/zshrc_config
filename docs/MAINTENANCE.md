# Maintenance

This repo is designed to stay publishable and easy to sync.

## Documentation Rule

When behavior changes, update docs in the same change.

- Installer changes: `docs/INSTALL.md`
- zsh load order, plugins, functions, or environment changes: `docs/ZSH.md`
- helper commands: `docs/HELPERS.md`
- Neovim plugins, keymaps, or workflows: `docs/NEOVIM.md` and `.zshrc_config/docs/nvim-quick-reference.md`
- tmux keybindings or behavior: `docs/TMUX.md`
- remote sync behavior: `docs/REMOTE_SYNC.md`
- public-facing repo overview: `README.md` and `docs/INDEX.md`

`AGENTS.md` repeats this rule for future coding agents.

## Secret Scanning

Before publishing or after sensitive edits:

```sh
gitleaks git . --redact --verbose --no-color --no-banner
gitleaks dir . --redact --verbose --no-color --no-banner
```

This repo also includes a versioned pre-commit hook:

```text
.githooks/pre-commit
```

Enable it in a clone with:

```sh
git config core.hooksPath .githooks
```

The hook runs:

```sh
gitleaks git --pre-commit --staged --redact --no-color --no-banner
```

If `gitleaks` is not installed, the hook fails closed and tells you to install
it. For an intentional one-time bypass, use `git commit --no-verify`.

The repo should not contain:

- `.env` files
- private keys
- API tokens
- SSH keys
- machine-local credentials
- `~/.zshrc_local`

## Ignored Files

Generated and scratch files should stay ignored:

```text
.zshrc_config/generated-completions/
work/
outputs/
*.log
```

## Validation Checklist

After config edits, run the relevant checks:

```sh
zsh -n .zshrc_config/init.zsh
zsh -n .zshrc_config/functions/*.zsh
zsh -n .zshrc_config/bin/*
zsh -n .zshrc_config/scripts/*.zsh
sh -n bootstrap.sh
sh -n install.sh
```

For Neovim config edits:

```sh
nvim --headless -i NONE +qa
```

For gitleaks before publishing:

```sh
gitleaks git .
gitleaks dir .
```

## Release Flow

1. Make the config change.
2. Update matching docs.
3. Run syntax checks.
4. Run `git status --short`.
5. Run gitleaks before publishing.
6. Commit with a short, descriptive message.
