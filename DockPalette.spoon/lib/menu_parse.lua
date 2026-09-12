--- Extracts window entries from plain menu snapshots.
---
--- Snapshot items are plain tables produced by `ax_menu.lua`:
---
---     { title = "Bring All to Front", mark = "", cmdChar = "", enabled = true,
---       hasSubmenu = false, children = nil | { item, ... } }
---
--- Array positions match Accessibility child indices, separators included, so the `path`
--- of a result can be pressed later without searching by title. Pure Lua; no `hs.*`.

local M = {}

M.DEFAULTS = {
  windowMenuTitles = { "Window" },
  bringAllToFrontTitles = { "Bring All to Front" },
  minimisedMarks = { "◆", "♦", "-", "–" },
  currentMarks = { "✓", "✔" },
  windowMenuExcludeTitles = {
    "Arrange in Front",
    "Remove Window from Set",
    "Cycle Through Windows",
    "Show Previous Tab",
    "Show Next Tab",
    "Move Tab to New Window",
    "Merge All Windows",
    "Show Progress Window",
  },
}

--- Returns `opts` with every missing key filled from `M.DEFAULTS` (explicit `false` is kept).
function M.withDefaults(opts)
  local merged = {}
  for key, value in pairs(M.DEFAULTS) do
    merged[key] = value
  end
  for key, value in pairs(opts or {}) do
    merged[key] = value
  end
  return merged
end

local function titleIn(title, list)
  if type(title) ~= "string" then
    return false
  end
  local lowered = title:lower()
  for _, candidate in ipairs(list or {}) do
    if lowered == candidate:lower() then
      return true
    end
  end
  return false
end

local function contains(list, value)
  for _, candidate in ipairs(list or {}) do
    if candidate == value then
      return true
    end
  end
  return false
end

local function isSeparator(item)
  return item.title == nil or item.title == ""
end

local function hasSubmenu(item)
  return item.hasSubmenu == true or item.children ~= nil
end

--- Finds the first top-level menu whose title is in `titles` (case-insensitive).
--- Returns its index and entry, or nil.
function M.findMenu(menuBar, titles)
  for index, menu in ipairs(menuBar or {}) do
    if titleIn(menu.title, titles) then
      return index, menu
    end
  end
  return nil
end

--- Lists the windows an app shows at the bottom of its Window menu.
---
--- AppKit appends one item per window after "Bring All to Front", including windows on
--- other Spaces and minimised ones. macOS's Window Sets feature can insert its own commands
--- ("Arrange in Front", "Remove Window from Set") in that same run; titles in
--- `opts.windowMenuExcludeTitles` are skipped rather than treated as windows. When the
--- "Bring All to Front" anchor is missing (a localised or non-AppKit menu), falls back to the
--- run of plain items after the last separator. The fallback gives up if that run contains
--- anything with a shortcut or a submenu, since window entries never have either.
---
--- Returns a list of `{ title, index, minimised, current }` and a boolean that is true
--- when the fallback was used.
function M.windowItems(items, opts)
  opts = M.withDefaults(opts)
  items = items or {}

  local anchor
  for index, item in ipairs(items) do
    if titleIn(item.title, opts.bringAllToFrontTitles) then
      anchor = index
    end
  end

  local heuristic = anchor == nil
  if heuristic then
    for index, item in ipairs(items) do
      if isSeparator(item) then
        anchor = index
      end
    end
    if anchor == nil then
      return {}, true
    end
  end

  local windows = {}
  for index = anchor + 1, #items do
    local item = items[index]
    if not isSeparator(item) and not titleIn(item.title, opts.windowMenuExcludeTitles) then
      local looksLikeCommand = hasSubmenu(item) or (item.cmdChar ~= nil and item.cmdChar ~= "")
      if heuristic and looksLikeCommand then
        return {}, true
      end
      if not hasSubmenu(item) then
        windows[#windows + 1] = {
          title = item.title,
          index = index,
          minimised = contains(opts.minimisedMarks, item.mark),
          current = contains(opts.currentMarks, item.mark),
        }
      end
    end
  end
  return windows, heuristic
end

return M
