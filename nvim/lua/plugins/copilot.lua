return {
  {
    "folke/sidekick.nvim",
    enabled = true,
    event = "VeryLazy",
    dependencies = { "github/copilot.vim" },
    opts = {
      cli = {
        claude = {
          cmd = "claude",
          args = { "--dangerously-skip-permissions" },
        },
        win = {
          layout = "float",
          float = {
            width = 0.9,
            height = 0.7,
            border = "rounded",
          },
        },
      },
    },
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
      { "<c-t>",      function() require("sidekick.cli").toggle() end, desc = "Toggle Sidekick CLI", mode = { "n", "t" } },
      { "<leader>aa", function() require("sidekick.cli").toggle() end, desc = "Toggle Sidekick CLI" },
      { "<leader>as", function() require("sidekick.cli").select() end, desc = "Select CLI tool" },
      { "<leader>ap", function() require("sidekick.cli").prompt() end, desc = "Select prompt" },
      {
        "<leader>at",
        function() require("sidekick.cli").send({ msg = "{this}" }) end,
        mode = { "x", "n" },
        desc = "Send This",
      },
      {
        "<leader>af",
        function() require("sidekick.cli").send({ msg = "{file}" }) end,
        desc = "Send File",
      },
      {
        "<leader>av",
        function() require("sidekick.cli").send({ msg = "{selection}" }) end,
        mode = { "x" },
        desc = "Send Visual Selection",
      },
    },
  },
  {
    "github/copilot.vim",
    cmd = "Copilot",
    event = "VeryLazy",
  },
}
