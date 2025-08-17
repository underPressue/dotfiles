return {
  "nvim-tree/nvim-web-devicons",
  config = function(_, opts)
    require("nvim-web-devicons").setup(opts or {})
  end,
}