return {
  "neovim/nvim-lspconfig",
  event = "User FilePost",
  config = function()
    require "plugins.configs.lspconfig"
  end,
}