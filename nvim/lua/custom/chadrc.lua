---@type ChadrcConfig
return {
  ui = {
    theme = "tokyonight",
    theme_toggle = { "tokyonight", "tokyonight" },
  },

  plugins = "custom.plugins",

  -- check core.mappings for table structure
  mappings = require "custom.mappings"
}
