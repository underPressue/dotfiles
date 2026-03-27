return {
  "3rd/image.nvim",
  ft = { "markdown" },
  opts = {
    backend = "kitty",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = true,
        only_render_image_at_cursor = true,
        only_render_image_at_cursor_mode = "popup",
        resolve_image_path = function(document_path, image_path, fallback)
          -- try default resolution first (same dir / absolute / relative)
          local default = fallback(document_path, image_path)
          if vim.fn.filereadable(default) == 1 then return default end

          -- search for image in parent directories (Obsidian vault media folders)
          local dir = vim.fn.fnamemodify(document_path, ":h")
          while dir ~= "/" do
            for _, folder in ipairs({ "media", "attachments", "assets", "images" }) do
              local candidate = dir .. "/" .. folder .. "/" .. image_path
              if vim.fn.filereadable(candidate) == 1 then return candidate end
            end
            dir = vim.fn.fnamemodify(dir, ":h")
          end

          return default
        end,
      },
    },
    window_overlap_clear_enabled = true,
    tmux_show_only_in_active_window = true,
    max_width = 100,
    max_height = 30,
    max_height_window_percentage = 40,
  },
}
