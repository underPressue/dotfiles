return {
  "zbirenbaum/nvterm",
  init = function()
    require("core.utils").load_mappings "nvterm"
  end,
  config = function(_, opts)
    require "base46.term"
    require("nvterm").setup(opts)
  end,
}