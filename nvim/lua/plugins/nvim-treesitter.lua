return {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSInstall", "TSBufEnable", "TSBufDisable", "TSModuleInfo" },
  build = ":TSUpdate",
  opts = function()
    return require "plugins.configs.treesitter"
  end,
  config = function(_, opts)
    dofile(vim.g.base46_cache .. "syntax")
    require("nvim-treesitter.configs").setup(opts)
  end,
}