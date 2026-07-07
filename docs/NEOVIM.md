# Neovim

The Neovim config lives in:

```text
~/.config/nvim
```

The repo copy lives at:

```text
.config/nvim
```

## Safety Model

This config intentionally avoids running project-local code just because a file
is opened.

Allowed:

- LSP autostart from configured language-server binaries on `PATH`
- format-on-save with global tools
- lint-on-save with global tools

Avoid:

- `BufRead` or `BufEnter` hooks that run `npm`, `pnpm`, `yarn`, `python`, `go`, or repo scripts
- project-local binaries such as `./node_modules/.bin/eslint`
- project-local Prettier or ESLint plugins
- automatic tool installation on project open

The security note in `.config/nvim/init.lua` exists so future edits preserve
this behavior.

## Startup

Main entrypoint:

```text
.config/nvim/init.lua
```

It sets:

```text
mapleader = Space
maplocalleader = \
safe_lsp_autostart = true
safe_format_on_save = true
safe_lint_on_save = true
```

Then it loads:

```text
lua/config/options.lua
lua/config/keymaps.lua
lua/config/autocmds.lua
lua/config/lazy.lua
```

## Plugin Manager

Plugins are managed by `lazy.nvim`.

Useful commands:

```vim
:Lazy
:Lazy sync
:Lazy update
:Lazy clean
```

Plugin specs live in:

```text
lua/plugins/
```

The lockfile is:

```text
lazy-lock.json
```

## Keymaps

Common global mappings:

| Key | Action |
| --- | --- |
| `<Esc>` | Clear search highlight |
| `<leader>w` | Write file |
| `<leader>q` | Quit window |
| `<leader>x` | Close buffer |
| `]d` | Next diagnostic |
| `[d` | Previous diagnostic |
| `<leader>dd` | Line diagnostics |
| `<leader>dq` | Diagnostics list |

The user quick reference lives at:

```text
~/.zshrc_config/docs/nvim-quick-reference.md
```

When keymaps change, update that file too.

## Finding

Telescope mappings:

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fc` | Commands |
| `<leader>fh` | Help tags |
| `<leader>fk` | Keymaps |

## File Tree

`nvim-tree.lua` is mapped to:

```text
<leader>e
```

Inside the tree, use `a` to create, `d` to delete, `r` to rename, and `?` for
the tree help.

## LSP

Language support targets:

- TypeScript/JavaScript
- Python
- Go

LSP configuration lives in:

```text
lua/config/safe_lsp.lua
lua/plugins/lsp.lua
```

Useful commands:

```vim
:SafeLspStart
:LspInfo
```

Expected language-server binaries:

| Language | Binary |
| --- | --- |
| TypeScript / JavaScript | `typescript-language-server` |
| Python | `pyright-langserver` |
| Go | `gopls` |

## Completion

Completion is powered by `blink.cmp`.

Configured sources:

- LSP
- path
- snippets
- buffer

## Formatting

Formatting is powered by `conform.nvim`.

Format-on-save is enabled by default and can be toggled:

```vim
:lua vim.g.safe_format_on_save = false
:lua vim.g.safe_format_on_save = true
```

Useful command:

```vim
:ConformInfo
```

Formatter preferences:

| File type | Formatter |
| --- | --- |
| Go | `goimports`, then `gofmt` |
| Python | `ruff_format`, then `black` |
| TypeScript / JavaScript | `biome` |
| JSON / JSONC | `biome` |

## Linting

Linting is powered by `nvim-lint`.

Lint-on-save is enabled by default and can be toggled:

```vim
:lua vim.g.safe_lint_on_save = false
:lua vim.g.safe_lint_on_save = true
```

Useful command:

```vim
:SafeLint
```

Configured linters:

| File type | Linter |
| --- | --- |
| Go | `staticcheck` |
| Python | `ruff` |
| TypeScript / JavaScript | `biomejs` |

## Sessions

Sessions are powered by `persistence.nvim`.

Keymaps:

| Key | Action |
| --- | --- |
| `<leader>qs` | Save session |
| `<leader>qS` | Select session |
| `<leader>ql` | Load last session |
| `<leader>qd` | Stop session tracking |

## Which-key

`which-key.nvim` shows available keybindings as you type leader sequences.

Useful mapping:

```text
<leader>?
```

This shows buffer-local keymaps.
