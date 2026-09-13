--- Reads the Dock's item order, for ordering the app palette to match it.

local M = {}

-- Newline-joined rather than the default comma-joined AppleScript list text, since item
-- names can themselves contain commas.
local ORDER_SCRIPT = [[
tell application "System Events"
  tell process "Dock"
    set itemNames to name of every UI element of list 1
  end tell
end tell
set AppleScript's text item delimiters to linefeed
return itemNames as text
]]

--- Names of the Dock's items (running and pinned apps), left to right, as System Events
--- reports them. Runs osascript as a background task so it never blocks Hammerspoon's run
--- loop — talking to System Events over Apple Events can take a noticeable fraction of a
--- second, which would otherwise delay every palette summon that orders by Dock position.
---
--- Calls `callback(names)` on success, or `callback(nil, errorMessage)` on failure.
function M.orderAsync(callback)
  local task = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
    if exitCode ~= 0 then
      callback(nil, (stdErr ~= "" and stdErr) or "Couldn't read the Dock's items")
      return
    end
    local names = {}
    for line in stdOut:gmatch("[^\n]+") do
      names[#names + 1] = line
    end
    callback(names)
  end, { "-e", ORDER_SCRIPT })
  task:start()
end

return M
