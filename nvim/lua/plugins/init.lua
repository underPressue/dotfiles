-- All plugins have lazy=true by default,to load a plugin on startup just lazy=false
-- List of all default plugins & their definitions
local default_plugins = {
  
  -- Basic dependencies and utilities
  require("plugins.plenary"),
  require("plugins.prettier"),

  -- NvChad core plugins (disabled)
  -- require("plugins.base46"),
  -- require("plugins.ui"),
  require("plugins.nvterm"),
  require("plugins.colorizer"),
  require("plugins.nvim-web-devicons"),

  -- Syntax and treesitter
  require("plugins.nvim-treesitter"),

  -- Git integration
  require("plugins.gitsigns"),

  -- LSP and language tools
  require("plugins.mason"),
  require("plugins.nvim-lspconfig"),

  -- Code editing
  require("plugins.comment"),

  -- File management and navigation
  require("plugins.nvim-tree"),
  require("plugins.telescope"),

  -- UI and keybindings
  require("plugins.which-key"),

  -- AI assistance
  require("plugins.copilot"),

  -- Custom plugins
  require("plugins.autosession"),
  require("plugins.blink"),
  require("plugins.copilot_chat"),
  require("plugins.lsp-ts-utils"),
  require("plugins.prisma"),
  require("plugins.snacks"),
  require("plugins.spectre"),
}

local config = require("core.utils").load_config()

require("lazy").setup(default_plugins, config.lazy_nvim)