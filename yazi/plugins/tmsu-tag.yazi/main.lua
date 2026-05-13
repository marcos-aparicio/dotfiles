-- Only return the 'url' userdata, which is Sendable
local get_hovered_url = ya.sync(function()
    local h = cx.active.current.hovered
    return h and h.url or nil
end)

local M = {}

function M:entry()
  local hovered_url = get_hovered_url()

	if not hovered_url then
		ya.notify({ title = "tmsu-tag", content = "there's no file hovered", timeout = 5 })
		return
	end

	-- Show input prompt for tags
	local tags, event = ya.input({
		title = "Add tags: ",
		value = "",
    pos = { "center", w = 40 },

	})

	if event ~= 1 or not tags or tags == "" then
		return
	end
  local file_path = tostring(hovered_url)
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

return M
