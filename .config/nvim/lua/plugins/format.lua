return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = { "n", "x" },
        desc = "Format buffer",
      },
    },
    opts = {
      notify_on_error = true,
      format_on_save = function()
        if vim.g.safe_format_on_save == false then
          return nil
        end
        return {
          timeout_ms = 2000,
          lsp_format = "fallback",
        }
      end,
      formatters_by_ft = {
        go = { "goimports", "gofmt", stop_after_first = true },
        python = { "ruff_format", "black", stop_after_first = true },
        javascript = { "biome", stop_after_first = true },
        javascriptreact = { "biome", stop_after_first = true },
        typescript = { "biome", stop_after_first = true },
        typescriptreact = { "biome", stop_after_first = true },
        json = { "biome", stop_after_first = true },
        jsonc = { "biome", stop_after_first = true },
      },
    },
  },
}
