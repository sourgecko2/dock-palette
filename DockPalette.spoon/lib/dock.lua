--- Reads the Dock's item order, for ordering the app palette to match it.

local M = {}

local ORDER_SCRIPT = [[
tell application "System Events"
  tell process "Dock"
    return name of every UI element of list 1
  end tell
end tell
]]

--- Names of the Dock's items (running and pinned apps), left to right, as System Events
--- reports them. Runs synchronously: unlike AXShowMenu, listing UI elements does not block on
--- user interaction.
---
--- Returns a list of names, or nil plus an error message.
function M.order()
  local ok, result = hs.osascript.applescript(ORDER_SCRIPT)
  if not ok then
    return nil, (type(result) == "string" and result) or "Couldn't read the Dock's items"
  end
  return result
end

return M
