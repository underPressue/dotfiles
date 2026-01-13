local config = require("core.utils").load_config()

require("lazy").setup({
  { import = "plugins" }
}, config.lazy_nvim)
