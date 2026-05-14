-- Only return the 'url' userdata, which is Sendable
local get_hovered_url = ya.sync(function()
  local h = cx.active.current.hovered
  return h and h.url or nil
end)

local M = {}

local function get_current_tags(file_path)
  local cmd = string.format("tmsu tags -n never %q 2>/dev/null", file_path)
  local handle = io.popen(cmd)
  if not handle then return "" end

  local output = handle:read("*a")
  handle:close()
  return output:gsub("\n$", "")
end

local function edit_tags_action(file_path)
  -- Get current tags
  local current_tags = get_current_tags(file_path)

  -- Create temp file
  local temp_file = os.tmpname()
  local f = io.open(temp_file, "w")
  if not f then
    ya.notify({ title = "tmsu-tag", content = "Failed to create temp file", timeout = 5 })
    return
  end
  f:write(current_tags)
  f:close()

  -- Hide yazi UI before spawning editor
  local permit = ui.hide()

  -- Open in editor using Command API
  local editor = os.getenv("EDITOR") or "vim"
  local child, err = Command(editor)
      :arg(temp_file)
      :stdin(Command.INHERIT)
      :stdout(Command.INHERIT)
      :stderr(Command.INHERIT)
      :spawn()

  if not child then
    ya.notify({ title = "tmsu-tag", content = string.format("Failed to start editor: %s", err), timeout = 5 })
    os.remove(temp_file)
    permit:drop()
    return
  end

  -- Wait for editor to close
  local output, err = child:wait_with_output()

  -- Restore yazi UI
  permit:drop()

  if not output then
    ya.notify({ title = "tmsu-tag", content = string.format("Editor error: %s", err), timeout = 5 })
    os.remove(temp_file)
    return
  end

  -- Read edited tags
  f = io.open(temp_file, "r")
  if not f then
    ya.notify({ title = "tmsu-tag", content = "Failed to read temp file", timeout = 5 })
    os.remove(temp_file)
    return
  end
  local new_tags = f:read("*a")
  f:close()

  -- Clean up temp file
  os.remove(temp_file)

  -- Rest of your existing logic...
  new_tags = new_tags:gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")

  if new_tags == current_tags then
    ya.notify({ title = "tmsu-tag", content = "No changes made", timeout = 3 })
    return
  end

  local choice, event = ya.input({
    title = "Confirm new tags: ",
    value = new_tags,
    pos = { "center", w = 60 },
  })

  if event ~= 1 or not choice then
    ya.notify({ title = "tmsu-tag", content = "Cancelled", timeout = 2 })
    return
  end

  local clear_cmd = string.format("tmsu untag -a %q 2>/dev/null", file_path)
  os.execute(clear_cmd)

  if choice ~= "" then
    local set_cmd = string.format("tmsu tag %q %s", file_path, choice)
    local success = os.execute(set_cmd)

    if success == 0 or success == true then
      ya.notify({
        title = "tmsu-tag",
        content = string.format("Tags updated: %s", choice),
        timeout = 3
      })
    else
      ya.notify({
        title = "tmsu-tag",
        content = "Failed to update tags",
        timeout = 5
      })
    end
  else
    ya.notify({
      title = "tmsu-tag",
      content = "All tags removed",
      timeout = 3
    })
  end
end

local function add_tags(file_path)
  -- Show input prompt for tags
  local tags, event = ya.input({
    title = "Add tags: ",
    value = "",
    pos = { "center", w = 40 },
  })

  if event ~= 1 or not tags or tags == "" then
    return
  end

  -- Execute tmsu tag command
  local cmd = string.format("tmsu tag %q %s", file_path, tags)

  local success = os.execute(cmd)

  if success == 0 or success == true then
    ya.notify({
      title = "tmsu-tag",
      content = string.format("Tagged: %s", tags),
      timeout = 3
    })
  else
    ya.notify({
      title = "tmsu-tag",
      content = "Failed to tag file",
      timeout = 5
    })
  end
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
    add_tags(file_path)
  end
end

return M
