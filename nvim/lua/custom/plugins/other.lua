---@type NvPluginSpec[]
return {

  {
    "prettier/vim-prettier",
  },

  {
    "jose-elias-alvarez/nvim-lsp-ts-utils",
    event = "VeryLazy",
    -- lazy = false,
    dependencies = {
      -- format & linting
      {
        "nvim-lua/plenary.nvim",
      },
    },
  },

  -- COPILOT STUFF

  {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    lazy = false,
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
    lazy = false,
    config = function()
      require("copilot_cmp").setup()
    end,
  },

  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    event = "VeryLazy",
    opts = {
      debug = false, -- Enable debugging
      -- See Configuration section for rest
      window = {
        layout = "vertical", -- 'vertical', 'horizontal', 'float', 'replace'
        width = 0.7,     -- fractional width of parent, or absolute width in columns when > 1
        height = 0.7,    -- fractional height of parent, or absolute height in rows when > 1
        -- Options below only apply to floating windows
        relative = "editor", -- 'editor', 'win', 'cursor', 'mouse'
        border = "single", -- 'none', single', 'double', 'rounded', 'solid', 'shadow'
        row = nil,       -- row position of the window, default is centered
        col = nil,       -- column position of the window, default is centered
        title = "Copilot", -- title of chat window
        footer = nil,    -- footer of chat window
        zindex = 1,      -- determines if window is on top or below other floating windows
      },
    },
  },
}
