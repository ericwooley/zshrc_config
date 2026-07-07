return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer local keymaps",
      },
    },
    opts = {
      preset = "modern",
      delay = 200,
      spec = {
        { "<leader>d", group = "diagnostics" },
        { "<leader>f", group = "find" },
        { "<leader>h", group = "git hunks" },
        { "<leader>l", group = "language" },
        { "<leader>q", group = "quit/session" },
      },
      win = {
        border = "rounded",
      },
    },
  },
}
