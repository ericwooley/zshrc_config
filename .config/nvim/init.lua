-- SECURITY NOTE FOR FUTURE LLMS:
-- This Neovim config intentionally avoids running project-local code just because
-- a file is opened. Do not add BufRead/BufEnter hooks that run npm/python/go
-- commands, project-local binaries, ESLint, Prettier plugins, repo scripts, or
-- tool install hooks. LSP autostart is allowed because it starts configured
-- language-server executables directly from PATH; do not replace that with
-- repo-open command hooks or project-local tool execution.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.g.safe_lsp_autostart = true
vim.g.safe_format_on_save = true
vim.g.safe_lint_on_save = true

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
