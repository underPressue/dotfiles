return {
  {
    "folke/sidekick.nvim",
    enabled = true,
    event = "VeryLazy",
    dependencies = { "github/copilot.vim" },
    opts = {},
    keys = {
      {
        "<tab>",
        function()
          if not require("sidekick").nes_jump_or_apply() then
            return "<Tab>"
          end
        end,
        expr = true,
        desc = "Goto/Apply Next Edit Suggestion",
      },
      { "<c-.>", function() require("sidekick.cli").toggle() end, desc = "Toggle Sidekick CLI" },
      { "<leader>aa", function() require("sidekick.cli").toggle() end, desc = "Toggle Sidekick CLI" },
      { "<leader>as", function() require("sidekick.cli").select() end, desc = "Select CLI tool" },
      { "<leader>ap", function() require("sidekick.cli").prompt() end, desc = "Select prompt" },
    },
  },
  {
    "github/copilot.vim",
    cmd = "Copilot",
    event = "VeryLazy",
  },
}
