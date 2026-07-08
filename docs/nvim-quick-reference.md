# Neovim Quick Reference

Config lives at: `~/.config/nvim`

Leader key: `Space`

## Safety Model

This setup allows LSPs to start when you open supported files, but avoids
repo-open hooks that run project commands.

Do not add automatic open-time hooks that run:

- `npm`, `pnpm`, `yarn`, `python`, `go`, or repo scripts
- project-local binaries like `./node_modules/.bin/eslint`
- ESLint or Prettier plugins from the current repo
- tool install commands

Linting and formatting are configured to use global tools from `PATH`.

## Everyday Keys

| Key | Action |
| --- | --- |
| `<Esc>` | Clear search highlight |
| `<leader>w` | Save file |
| `<leader>q` | Quit window |
| `<leader>x` | Close buffer |

## Finding Things

Powered by Telescope.

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fg` | Search text in files |
| `<leader>fb` | Switch buffers |
| `<leader>fh` | Search help |
| `<C-j>` / `<C-k>` | Move selection in Telescope insert mode |

Command form:

```vim
:Telescope
```

## File Tree

Powered by nvim-tree.

| Key | Action |
| --- | --- |
| `<leader>e` | Toggle file tree |

Inside the file tree:

| Key | Action |
| --- | --- |
| `Enter` | Open file or folder |
| `a` | Create file or folder |
| `d` | Delete file or folder |
| `r` | Rename file or folder |
| `x` | Cut file or folder |
| `c` | Copy file or folder |
| `p` | Paste file or folder |
| `y` | Copy filename |
| `Y` | Copy relative path |
| `gy` | Copy absolute path |
| `R` | Refresh tree |
| `?` | Show nvim-tree help |

When creating a folder with `a`, include the trailing slash:

```text
src/components/
```

Useful commands:

```vim
:NvimTreeToggle
:NvimTreeFindFile
```

## LSP

Configured for TypeScript/JavaScript, Python, and Go.

LSP starts automatically when you open supported files if the language server is
installed globally and available on `PATH`.

| Key | Action |
| --- | --- |
| `<leader>ls` | Manually start safe LSP for current buffer |
| `gd` | Go to definition |
| `gr` | Find references |
| `K` | Hover docs |
| `<leader>rn` | Rename symbol |
| `<leader>ca` | Code action |

Useful commands:

```vim
:SafeLspStart
:LspInfo
```

Expected language server binaries:

| Language | Binary |
| --- | --- |
| TypeScript / JavaScript | `typescript-language-server` |
| Python | `pyright-langserver` |
| Go | `gopls` |

## Formatting

Powered by conform.nvim.

Formatting on save is enabled.

| Key | Action |
| --- | --- |
| `<leader>f` | Format current buffer or visual selection |

Useful command:

```vim
:ConformInfo
```

Configured formatters:

| File type | Formatter preference |
| --- | --- |
| Go | `goimports`, then `gofmt` |
| Python | `ruff_format`, then `black` |
| TypeScript / JavaScript | `biome` |
| JSON / JSONC | `biome` |

Toggle format-on-save:

```vim
:lua vim.g.safe_format_on_save = false
:lua vim.g.safe_format_on_save = true
```

## Linting

Powered by nvim-lint.

Linting on save is enabled. The config checks that the linter binary is not
inside the project root before running it.

| Key | Action |
| --- | --- |
| `<leader>ll` | Lint current buffer |

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

Toggle lint-on-save:

```vim
:lua vim.g.safe_lint_on_save = false
:lua vim.g.safe_lint_on_save = true
```

## Git

Powered by gitsigns.nvim and LazyGit.

| Key | Action |
| --- | --- |
| `<leader>lg` | Open LazyGit |
| `]h` | Next changed hunk |
| `[h` | Previous changed hunk |
| `<leader>hp` | Preview hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hs` | Stage hunk |

Useful command:

```vim
:LazyGit
```

## Completion

Powered by blink.cmp.

Completion appears in insert mode after the plugin loads. It uses LSP, path,
snippet, and buffer sources.

## Plugin Management

Powered by lazy.nvim.

Useful commands:

```vim
:Lazy
:Lazy sync
:Lazy update
:Lazy clean
```

The plugin lockfile is:

```text
~/.config/nvim/lazy-lock.json
```

## Tools To Install Globally

These need to exist on `PATH` for the full setup to work:

```text
typescript-language-server
pyright-langserver
gopls
biome
ruff
black
goimports
gofmt
staticcheck
lazygit
```
