return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    workspaces = {
      {
        name = "elBrain",
        path = "~/Library/Mobile Documents/com~apple~CloudDocs/elBrain",
      },
    },
    attachments = {
      img_folder = "media",
    },
    notes_subdir = "",
    new_notes_location = "current_dir",
    completion = {
      nvim_cmp = false,
      min_chars = 2,
    },
    mappings = {
      ["gf"] = {
        action = function()
          return require("obsidian").util.gf_passthrough()
        end,
        opts = { noremap = false, expr = true, buffer = true },
      },
      ["<cr>"] = {
        action = function()
          return require("obsidian").util.smart_action()
        end,
        opts = { buffer = true, expr = true },
      },
    },
    ui = {
      enable = false, -- markview handles rendering
    },
  },
}
