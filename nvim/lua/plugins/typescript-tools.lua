return {
  "pmizio/typescript-tools.nvim",
  event = "User FilePost",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "neovim/nvim-lspconfig",
  },
  config = function()
    local lsp = require "plugins.configs.lspconfig"

    require("typescript-tools").setup {
      on_attach = function(client, bufnr)
        lsp.on_attach(client, bufnr)
        local opts = { silent = true, buffer = bufnr }
        vim.keymap.set("n", "gs", "<cmd>TSToolsOrganizeImports<cr>", opts)
        vim.keymap.set("n", "gr", "<cmd>TSToolsRenameFile<cr>", opts)
        vim.keymap.set("n", "gi", "<cmd>TSToolsAddMissingImports<cr>", opts)
      end,
      on_init = lsp.on_init,
      capabilities = lsp.capabilities,
      settings = {
        expose_as_code_action = "all",
      },
    }
  end,
}
