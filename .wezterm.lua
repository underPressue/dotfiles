local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices
config.font = wezterm.font 'JetBrainsMono Nerd Font Mono'
config.font_size = 15.2
config.line_height = 1.15
config.enable_tab_bar = false
config.window_decorations = 'RESIZE'
config.window_background_opacity = 0.8
config.macos_window_background_blur = 15
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.color_scheme = 'Night Owl'
config.automatically_reload_config = true

-- and finally, return the configuration to wezterm
return config
