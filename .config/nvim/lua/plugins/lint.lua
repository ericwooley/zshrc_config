local function is_under(path, dir)
  if not path or not dir then
    return false
  end
  local real_path = vim.uv.fs_realpath(path) or path
  local real_dir = vim.uv.fs_realpath(dir) or dir
  return real_path == real_dir or real_path:sub(1, #real_dir + 1) == real_dir .. "/"
end

local function linter_command(linter)
  if type(linter.cmd) == "function" then
    return linter.cmd()
  end
  return linter.cmd
end

local function configured_linters_for_filetype(lint, filetype)
  local names = {}
  local exact = lint.linters_by_ft[filetype]
  if exact then
    vim.list_extend(names, exact)
  end

  for part in filetype:gmatch("[^.]+") do
    local part_linters = lint.linters_by_ft[part]
    if part_linters then
      vim.list_extend(names, part_linters)
    end
  end

  return vim.fn.uniq(names)
end

local function safe_linters_for_buffer(lint)
  local root = vim.fs.root(0, { ".git", "package.json", "pyproject.toml", "go.mod" }) or vim.fn.getcwd()
  local names = configured_linters_for_filetype(lint, vim.bo.filetype)
  local allowed = {}

  for _, name in ipairs(names) do
    local linter = lint.linters[name]
    local cmd = linter and linter_command(linter)
    local resolved = cmd and vim.fn.exepath(cmd) or ""

    if resolved == "" then
      vim.notify("Linter not found on PATH: " .. name, vim.log.levels.DEBUG)
    elseif is_under(resolved, root) then
      vim.notify("Skipped project-local linter: " .. resolved, vim.log.levels.WARN)
    else
      table.insert(allowed, name)
    end
  end

  return allowed
end

local function try_safe_lint()
  local ok, lint = pcall(require, "lint")
  if not ok then
    return
  end

  local linters = safe_linters_for_buffer(lint)
  if #linters > 0 then
    lint.try_lint(linters)
  end
end

return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufWritePost" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        go = { "staticcheck" },
        javascript = { "biomejs" },
        javascriptreact = { "biomejs" },
        python = { "ruff" },
        typescript = { "biomejs" },
        typescriptreact = { "biomejs" },
      }

      vim.api.nvim_create_user_command("SafeLint", try_safe_lint, {
        desc = "Run configured global linters for the current buffer",
      })

      vim.keymap.set("n", "<leader>ll", try_safe_lint, { desc = "Lint buffer" })

      vim.api.nvim_create_autocmd("BufWritePost", {
        group = vim.api.nvim_create_augroup("safe_lint", { clear = true }),
        callback = function()
          if vim.g.safe_lint_on_save == true then
            try_safe_lint()
          end
        end,
      })
    end,
  },
}
