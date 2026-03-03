return {
  "esmuellert/codediff.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = "CodeDiff",
  keys = {
    { "<leader>gd", "<cmd>CodeDiff<cr>", desc = "CodeDiff" }
  },
  opts = {},
  config = function(_, opts)
    require("codediff").setup(opts)
    -- Patch nui tree render to guard against invalid buffers (upstream bug)
    local Tree = require("nui.tree")
    local original_render = Tree.render
    Tree.render = function(self, ...)
      if self.bufnr and not vim.api.nvim_buf_is_valid(self.bufnr) then
        return
      end
      return original_render(self, ...)
    end
  end,
}
