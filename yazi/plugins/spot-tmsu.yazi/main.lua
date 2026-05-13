local M = {}

function M:spot(job)
  local tags_section = { title = 'TMSU Tags' }

  -- Get file path from job
  local file = tostring(job.file.url)

  -- Build command with -n never to suppress filename in output
  local cmd = 'tmsu tags -n never ' .. string.format("%q", file) .. ' 2>/dev/null'

  -- Execute tmsu tags command
  local handle = io.popen(cmd)
  if handle then
    local output = handle:read('*a')
    handle:close()

    -- Parse output: each line is "tag" or "tag=value" separated by spaces
    for tag_part in output:gmatch('%S+') do
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
  end

  -- Only include tags section if there are actual tags (more than just the title)
  local sections = {}
  if #tags_section >= 1 then
    table.insert(sections, tags_section)
  end
  require('spot'):spot(job, sections, {})
end

return M
