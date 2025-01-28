---@type ChadrcConfig
return {
  ui = {
    theme = "github_dark",
    theme_toggle = { "github_dark", "github_dark" },
  },

  plugins = "custom.plugins",

  -- check core.mappings for table structure
  mappings = require "custom.mappings"
}
