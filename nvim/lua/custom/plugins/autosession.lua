return {
  "rmagatti/auto-session",
  lazy = false,
  config = function()
    require("auto-session").setup({
      log_level = "error",
      silent_restore = false,
      auto_session_suppress_dirs = { "~/", "~/Projects", "~/Downloads", "/" },
    })
  end,
}
