return {
  {
    "neovim/nvim-lspconfig",
    event = "VeryLazy",
    config = function()
      require("config.safe_lsp").setup()
    end,
  },
}
