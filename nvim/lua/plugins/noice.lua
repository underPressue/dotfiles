return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  init = function()
    vim.o.cmdheight = 0 -- reclaim the bottom row; cmdline lives in the popup
  end,
  opts = {
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
    },
    messages = { enabled = false },
    notify = { enabled = false },
    lsp = { progress = { enabled = false } },
    popupmenu = { enabled = true },
  },
}
