local M = {}

-- State management using ya.sync
local get_tags_cache = ya.sync(function(state)
  state.tags_cache = state.tags_cache or {}
  return state.tags_cache
end)

local set_tags_cache = ya.sync(function(state, file_path, has_tags)
  state.tags_cache = state.tags_cache or {}
  if has_tags == nil then
    state.tags_cache[file_path] = nil  -- Clear cache entry
  else
    state.tags_cache[file_path] = has_tags
  end
end)

local clear_tags_cache = ya.sync(function(state)
  state.tags_cache = {}
end)

local render = ya.sync(function()
  (ui.render or ya.render)()
end)

local TAG_ICON = "󰚋"  -- tag icon (nerd font)

-- Get hovered file URL
local get_hovered_url = ya.sync(function()
  local h = cx.active.current.hovered
  return h and h.url or nil
end)

-- Parse tags from one-line input (handles quoted tags with spaces and key=value pairs)
local function parse_tags_oneline(input)
  local tags = {}
  local pos = 1

  while pos <= #input do
    -- Skip whitespace
    local ws_start, ws_end = input:find('^%s+', pos)
    if ws_start then
      pos = ws_end + 1
    end

    if pos > #input then break end

    -- Try patterns in order (most specific first)
    local patterns = {
      '"[^"]*"="[^"]*"',   -- "key"="value"
      '[%w]+="[^"]*"',     -- key="value"
      '"[^"]+"=[%w%s]+',   -- "key"=value
      '[%w]+=[%w]+',       -- key=value
      '"[^"]+"',           -- "value"
      '[%w]+',             -- value
    }

    local matched = false
    for _, pattern in pairs(patterns) do
      local m_start, m_end, match = input:find('(' .. pattern .. ')', pos)

      if m_start == pos then
        table.insert(tags, match)
        pos = m_end + 1
        matched = true
        break
      end
    end

    if not matched then
      pos = pos + 1
    end
  end

  return tags
end

-- Parse tags from multi-line input
local function parse_tags_multiline(input)
  local tags = {}
  for line in input:gmatch("[^\r\n]+") do
    table.insert(tags, line)
  end
  return tags
end

-- Read file contents using Yazi API
local function read_file(url)
  local fd, err = fs.access():read(true):open(url)
  if not fd then
    return nil, err
  end

  local content = ""
  while true do
    local chunk, err = fd:read(4096)
    if not chunk then
      ya.drop(fd)
      return nil, err
    elseif chunk == "" then
      break -- EOF
    end
    content = content .. chunk
  end

  ya.drop(fd)
  return content
end

-- Get current tags for a file
local function get_current_tags(file_path)
  local output, err = Command("tmsu")
      :arg({ "tags", "-n", "never", file_path })
      :output()

  if not output or err then
    return ""
  end

  return output.stdout
end

-- Edit tags action (opens editor)
local function edit_tags_action(file_path)
  local current_tags = get_current_tags(file_path)

  -- Create temp file
  local tmp_dir = Url(os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp")
  local tmp_url = fs.unique("file", tmp_dir:join(".tmp_myfile"))
  if not tmp_url then
    ya.notify({ title = "tmsu-tag", content = "Failed to create temp file", timeout = 5 })
    return
  end
  fs.write(tmp_url, current_tags)

  -- Hide yazi UI before spawning editor
  local permit = ui.hide()

  -- Open in editor
  local editor = os.getenv("EDITOR") or "vim"
  local child, err = Command(editor)
      :arg(tostring(tmp_url))
      :stdin(Command.INHERIT)
      :stdout(Command.INHERIT)
      :stderr(Command.INHERIT)
      :spawn()

  if not child then
    ya.notify({ title = "tmsu-tag", content = string.format("Failed to start editor: %s", err), timeout = 5 })
    fs.remove("file", tmp_url)
    permit:drop()
    return
  end

  -- Wait for editor to close
  local output, err = child:wait_with_output()
  permit:drop()

  if not output then
    ya.notify({ title = "tmsu-tag", content = string.format("Editor error: %s", err), timeout = 5 })
    fs.remove("file", tmp_url)
    return
  end

  -- Read edited tags
  local new_tags, _ = read_file(tmp_url)
  if not new_tags then
    ya.notify({ title = "tmsu-tag", content = "Failed to read temp file", timeout = 5 })
    fs.remove("file", tmp_url)
    return
  end
  fs.remove("file", tmp_url)

  if new_tags == current_tags then
    ya.notify({ title = "tmsu-tag", content = "No changes made", timeout = 3 })
    return
  end

  local confirm_new_tags = ya.confirm {
    pos = { "center", w = 40, h = 10 },
    title = "Confirm tags",
    body = new_tags,
  }

  if not confirm_new_tags then
    ya.notify({ title = "tmsu-tag", content = "Cancelled", timeout = 2 })
    return
  end

  -- Remove all existing tags
  if not current_tags or current_tags ~= "" then
    local child = Command("tmsu")
        :arg({ "untag", "-a", file_path })
        :stdout(Command.NULL)
        :stderr(Command.NULL)
        :spawn()

    if child then
      child:wait()
    end
  end

  if not new_tags or new_tags == "" then
    set_tags_cache(file_path, false)
    ya.notify({ title = "tmsu-tag", content = "Tags deleted", timeout = 2 })
    render()
    return
  end

  -- Add new tags
  local parsed = parse_tags_multiline(new_tags)

  local child2 = Command("tmsu")
      :arg({ "tag", file_path, table.unpack(parsed) })
      :stdout(Command.NULL)
      :stderr(Command.NULL)
      :spawn()

  if child2 then
    child2:wait()
  end

  set_tags_cache(file_path, true)
  ya.notify({
    title = "tmsu-tag",
    content = string.format("Tags updated:\n%s", new_tags),
    timeout = 3
  })
  render()
end

-- Add tags action (simple input prompt)
local function add_tags_action(file_path)
  local tags, event = ya.input({
    title = "Add tags: ",
    value = "",
    pos = { "center", w = 40 },
  })

  if event ~= 1 or not tags or tags == "" then
    return
  end

  local parsed_tags = parse_tags_oneline(tags)

  local child, err = Command("tmsu")
      :arg({ "tag", file_path, table.unpack(parsed_tags) })
      :stdout(Command.NULL)
      :stderr(Command.NULL)
      :spawn()

  if not child then
    ya.notify({
      title = "tmsu-tag",
      content = string.format("Failed to tag file: %s", err),
      timeout = 5
    })
    return
  end

  local output, err2 = child:wait_with_output()
  if not output or not output.status.success or err2 then
    ya.notify({
      title = "tmsu-tag",
      content = "Failed to tag file",
      timeout = 5
    })
    return
  end

  set_tags_cache(file_path, true)
  ya.notify({
    title = "tmsu-tag",
    content = string.format("Tagged: %s", tags),
    timeout = 3
  })
  render()
end

-- Entry: Called when user invokes the plugin
function M:entry(job)
  local hovered_url = get_hovered_url()

  if not hovered_url then
    ya.notify({ title = "tmsu-tag", content = "No file hovered", timeout = 5 })
    return
  end

  local file_path = tostring(hovered_url)

  -- Check which action was called
  if job.args[1] == "edit" then
    edit_tags_action(file_path)
  else
    add_tags_action(file_path)
  end
end

-- Fetch: Called by Yazi to load file metadata
function M:fetch(job)
  local cache = get_tags_cache()

  for _, file in ipairs(job.files) do
    local file_path = tostring(file.url)

    -- Skip if already cached
    if cache[file_path] ~= nil then
      goto continue
    end

    -- Query tmsu for this file
    local output, err = Command("tmsu")
        :arg({ "tags", "--count", "--name", "never", file_path })
        :output()

    if output and not err then
      local count = tonumber(output.stdout:match("%d+"))
      set_tags_cache(file_path, (count and count > 0) or false)
    else
      set_tags_cache(file_path, false)
    end

    ::continue::
  end

  render()
  return true
end

-- Setup: Register the renderer
function M:setup()
  Linemode:children_add(function(_self)
    -- Skip directories
    if _self._file.is_dir then
      return ""
    end

    local file_path = tostring(_self._file.url)
    local cache = get_tags_cache()
    local has_tags = cache[file_path]

    if has_tags == true then
      return ui.Line(ui.Span(TAG_ICON):style(ui.Style():fg("blue")))
    end

    return ""
  end, 500)
end

return M
