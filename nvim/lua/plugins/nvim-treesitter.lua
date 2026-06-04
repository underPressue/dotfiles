return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    dofile(vim.g.base46_cache .. "syntax")

    local parsers = require "plugins.configs.treesitter"
    require("nvim-treesitter").install(parsers)

    local function start_ts(buf)
      if pcall(vim.treesitter.start, buf) then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        start_ts(args.buf)
      end,
    })

    -- FileType for the initial buffer fires before this config runs, so start it manually
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        start_ts(buf)
      end
    end
  end,
}
