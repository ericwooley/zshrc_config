local M = {}

local servers = {
  ts_ls = {
    cmd = { "typescript-language-server", "--stdio" },
    filetypes = {
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
    },
    root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
  },
  pyright = {
    cmd = { "pyright-langserver", "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
  },
  gopls = {
    cmd = { "gopls" },
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_markers = { "go.work", "go.mod", ".git" },
    settings = {
      gopls = {
        gofumpt = true,
        staticcheck = true,
      },
    },
  },
}

local function executable(cmd)
  return type(cmd) == "string" and vim.fn.executable(cmd) == 1
end

local function server_for_filetype(filetype)
  for name, config in pairs(servers) do
    if vim.tbl_contains(config.filetypes, filetype) then
      return name, config
    end
  end
end

local function root_for(config)
  return vim.fs.root(0, config.root_markers) or vim.fn.getcwd()
end

function M.start_for_buffer()
  local name, base_config = server_for_filetype(vim.bo.filetype)
  if not name then
    vim.notify("No safe LSP configured for filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end

  local cmd = base_config.cmd and base_config.cmd[1]
  if not executable(cmd) then
    vim.notify("LSP executable not found on PATH: " .. tostring(cmd), vim.log.levels.WARN)
    return
  end

  local config = vim.deepcopy(base_config)
  config.name = name
  config.root_dir = root_for(base_config)
  config.root_markers = nil

  local ok, blink = pcall(require, "blink.cmp")
  if ok then
    config.capabilities = blink.get_lsp_capabilities(config.capabilities)
  end

  vim.lsp.start(config)
end

function M.setup()
  vim.api.nvim_create_user_command("SafeLspStart", M.start_for_buffer, {
    desc = "Start the configured global LSP for the current buffer",
  })

  vim.keymap.set("n", "<leader>ls", M.start_for_buffer, { desc = "Start safe LSP" })

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("safe_lsp", { clear = true }),
    callback = function()
      if vim.g.safe_lsp_autostart == true then
        M.start_for_buffer()
      end
    end,
  })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lsp_keymaps", { clear = true }),
    callback = function(event)
      local opts = { buffer = event.buf }
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
      vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "References" }))
      vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
      vim.keymap.set({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
    end,
  })
end

return M
