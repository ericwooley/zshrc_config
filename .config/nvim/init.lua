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

local function prepend_path(path_entry)
  if not path_entry or path_entry == "" or vim.fn.isdirectory(path_entry) ~= 1 then
    return
  end

  local separator = package.config:sub(1, 1) == "\\" and ";" or ":"
  local current_path = vim.env.PATH or ""
  for entry in string.gmatch(current_path, "([^" .. separator .. "]+)") do
    if entry == path_entry then
      return
    end
  end

  vim.env.PATH = path_entry .. separator .. current_path
end

local home = vim.env.HOME or vim.fn.expand("~")
vim.env.N_PREFIX = vim.env.N_PREFIX or (home .. "/.local/n")
prepend_path(vim.env.N_PREFIX .. "/bin")
prepend_path(home .. "/.local/bin")

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
