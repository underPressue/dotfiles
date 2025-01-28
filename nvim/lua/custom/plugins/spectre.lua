return {
  "nvim-pack/nvim-spectre",
  dependencies = {
    {
      "nvim-lua/plenary.nvim",
    },
  },
  config = function()
    require("spectre").setup({
      open_cmd = "new",
    })
  end,
}
