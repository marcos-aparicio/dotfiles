local wezterm = require 'wezterm'

local config = {
  -- Colors
  colors = {
    foreground = "#B3B1AD",
    background = "#0A0E14",
    cursor_bg = "#B3B1AD",
    cursor_border = "#B3B1AD",
    cursor_fg = "#0A0E14",
    selection_bg = "#afd7ff",
    selection_fg = "#000000",

    ansi = {
      "#01060E", "#EA6C73", "#91B362", "#F9AF4F",
      "#268bd2", "#FAE994", "#90E1C6", "#C7C7C7",
    },

    brights = {
      "#686868", "#F07178", "#C2D94C", "#FFB454",
      "#00afff", "#FFEE99", "#95E6CB", "#FFFFFF",
    },
  },

  -- Font
  font = wezterm.font("mononoki Nerd Font"),
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
