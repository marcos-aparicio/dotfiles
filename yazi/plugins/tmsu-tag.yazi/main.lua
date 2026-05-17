-- Only return the 'url' userdata, which is Sendable
local get_hovered_url = ya.sync(function()
  local h = cx.active.current.hovered
  return h and h.url or nil
end)


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

local function parse_tags_multiline(input)
  local tags = {}
  for line in input:gmatch("[^\r\n]+") do
    table.insert(tags, line)
  end
  return tags
end

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

local M = {}

local function get_current_tags(file_path)
  local output, err = Command("tmsu")
      :arg({ "tags", "-n", "never", file_path })
      :output()

  if not output or err then
    return ""
  end

  return output.stdout
end

local function edit_tags_action(file_path)
  -- Get current tags
  local current_tags = get_current_tags(file_path)

  -- Create temp file
  -- Cross-platform: use TMPDIR/TEMP/TMP env vars
  local tmp_dir = Url(os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp")
  local tmp_url = fs.unique("file", tmp_dir:join(".tmp_myfile"))
  if not tmp_url then
    ya.notify({ title = "tmsu-tag", content = "Failed to create temp file", timeout = 5 })
    return
  end
  fs.write(tmp_url, current_tags)

  -- Hide yazi UI before spawning editor
  local permit = ui.hide()

  -- Open in editor using Command API
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

  -- Restore yazi UI
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
  -- Clean up temp file
  fs.remove("file", tmp_url)

  -- Rest of your existing logic...

  if new_tags == current_tags then
    ya.notify({ title = "tmsu-tag", content = "No changes made", timeout = 3 })
    return
  end

  local confirm_new_tags = ya.confirm {
    -- Position
    pos = { "center", w = 40, h = 10 },
    -- Title
    title = "Test",
    -- Body
    body = new_tags,
  }

  if not confirm_new_tags then
    ya.notify({ title = "tmsu-tag", content = "Cancelled", timeout = 2 })
    return
  end

  if not current_tags or current_tags ~= "" then
    local status_untag, error_untag = Command("tmsu")
        :arg({ "untag", "-a", file_path })
        :status()

    if (status_untag and not status_untag.success) or error_untag then
      ya.notify({ title = "tmsu-tag", content = "Error untagging file", timeout = 2 })
      return
    end
  end

  if not new_tags or new_tags == "" then
    ya.notify({ title = "tmsu-tag", content = "Tags deleted", timeout = 2 })
    return
  end

  local status_tag, error_tag = Command("tmsu")
      :arg({ "tag", file_path, table.unpack(parse_tags_multiline(new_tags)) })
      :stdout(Command.NULL)
      :stderr(Command.NULL)
      :status()

  if (status_tag and not status_tag.success) or error_tag then
    ya.notify({ title = "tmsu-tag", content = "Error re tagging file", timeout = 2 })
    return
  end

  ya.notify({
    title = "tmsu-tag",
    content = string.format("Tags updated:\n%s", new_tags),
    timeout = 3
  })
end

local function add_tags_action(file_path)
  -- Show input prompt for tags
  local tags, event = ya.input({
    title = "Add tags: ",
    value = "",
    pos = { "center", w = 40 },
  })

  if event ~= 1 or not tags or tags == "" then
    return
  end


  local parsed_tags = parse_tags_oneline(tags)
  ya.dbg(tags)
  ya.dbg(table.concat(parsed_tags, ", "))
  -- Execute tmsu tag command
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

  ya.notify({
    title = "tmsu-tag",
    content = string.format("Tagged: %s", tags),
    timeout = 3
  })
end

function M:entry(job)
  local hovered_url = get_hovered_url()

  if not hovered_url then
    ya.notify({ title = "tmsu-tag", content = "there's no file hovered", timeout = 5 })
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

return M
