return {
  {
    "zbirenbaum/copilot.lua",
    enabled = true,
    event = "InsertEnter",
    opts = {
      suggestion = {
        enable = false,
      },
      panel = {
        enable = false,
      },
    },
  },

  {
    "zbirenbaum/copilot-cmp",
    enabled = true,
    event = "InsertEnter",
    config = function()
      require("copilot_cmp").setup()
    end,
  },
}
