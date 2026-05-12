require("zoxide"):setup {
  update_db = true,
}

require('spot'):setup({
  metadata_section = {
    enable = true,
    hash_cmd = 'xxhsum', -- other hashing commands may be slower
    hash_filesize_limit = 150, -- in MB, set 0 to disable
    relative_time = true, -- 2026-01-01 or n days ago
    time_format = '%Y-%m-%d %H:%M', -- https://www.man7.org/linux/man-pages/man3/strftime.3.html
    show_compression = 'size', ---@type false|"size"|"percentage"
  },
  plugins_section = {
    enable = true,
  },
  style = {
    section = 'green',
    key = 'reset',
    value = 'blue',
    selected = 'blue',
    colorize_metadata = true,
    height = 20,
    width = 60,
    key_length = 15,
  },
})
