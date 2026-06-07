local wezterm = require 'wezterm'
local colors = require("colors")

local config = {
  -- Colors
  colors = colors,
  -- Font
  font = wezterm.font_with_fallback({
    'mononoki Nerd Font',
    'FiraCode Nerd Font',
  }),
  warn_about_missing_glyphs = false,
  font_size = 18, -- ⬅️ Increased (you can set 15/16 if you want even bigger)

  -- Window
  window_background_opacity = 0.92,
  window_padding = {
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
  },
  -- UI
  enable_tab_bar = false,           -- no tab bar
  exit_behavior_messaging = "None", -- no confirmation when exiting
  window_close_confirmation = "NeverPrompt",
  check_for_updates = false,        -- optional: avoid update popups
  keys = {
    {
      key = "Tab",
      mods = "CTRL",
      action = wezterm.action.SendKey { key = "Tab", mods = "CTRL" },
    },
    {
      key = "Tab",
      mods = "CTRL|SHIFT",
      action = wezterm.action.SendKey { key = "Tab", mods = "CTRL|SHIFT" },
    },
    {
      key = "LeftArrow",
      mods = "CTRL|SHIFT",
      action = wezterm.action.SendString("\x1b[1;6D"),
    },
    {
      key = "RightArrow",
      mods = "CTRL|SHIFT",
      action = wezterm.action.SendString("\x1b[1;6C"),
    },
    {
      key = "L",
      mods = "CTRL|SHIFT",
      action = wezterm.action.DisableDefaultAssignment,
    },
    {
      key = "D",
      mods = "CTRL|SHIFT",
      action = wezterm.action.ShowDebugOverlay,
    },
  },
}

return config
