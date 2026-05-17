local M = {}

function M:spot(job)
  local tags_section = { title = 'TMSU Tags' }

  local sections = {}
  local tags_cmd, err = Command("tmsu")
      :arg({ "tags", "-n", "never", tostring(job.file.url) })
      :output()

  if err or not tags_cmd or tags_cmd.stdout == "" then
    require('spot'):spot(job, sections, {})
    return
  end

  local output = tags_cmd.stdout

  -- Parse output: handle escaped spaces in tags
  -- Split by spaces, but respect escaped spaces (\ )
  local tags = {}
  local current_tag = ''
  local i = 1
  while i <= #output do
    local char = output:sub(i, i)
    if char == '\\' and i < #output and output:sub(i + 1, i + 1) == ' ' then
      -- Escaped space - add actual space to current tag
      current_tag = current_tag .. ' '
      i = i + 2
    elseif char == ' ' or char == '\n' then
      -- Unescaped space or newline - end of tag
      if current_tag ~= '' then
        table.insert(tags, current_tag)
        current_tag = ''
      end
      i = i + 1
    else
      current_tag = current_tag .. char
      i = i + 1
    end
  end
  if current_tag ~= '' then
    table.insert(tags, current_tag)
  end

  -- Process parsed tags
  for _, tag_part in ipairs(tags) do
    if tag_part ~= '' then
      local tag, value = tag_part:match('^([^=]+)=(.*)$')
      if tag then
        -- Tag with value
        table.insert(tags_section, { tag, value })
      else
        -- Tag without value
        table.insert(tags_section, { tag_part, '' })
      end
    end
  end

  if #tags_section >= 1 then
    table.insert(sections, tags_section)
  end
  require('spot'):spot(job, sections, {})
end

return M
