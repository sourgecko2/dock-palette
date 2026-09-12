--- Reads and presses an app's menu bar items through hs.axuielement.
---
--- Hammerspoon-only adapter. It returns plain tables (see menu_parse.lua), so the parsing
--- logic stays testable without macOS. Pressing uses AXPress directly on the item, the same
--- mechanism as hs.application:selectMenuItem(), so no menu opens on screen.

local M = {}

--- Seconds to wait for an unresponsive app before giving up on an Accessibility query.
M.timeout = 1.5

local function attr(element, name)
  if element == nil then
    return nil
  end
  local value = element:attributeValue(name)
  return value
end

local function children(element)
  return attr(element, "AXChildren") or {}
end

local function submenuOf(element)
  local first = children(element)[1]
  if first ~= nil and attr(first, "AXRole") == "AXMenu" then
    return first
  end
  return nil
end

local function menuBar(app)
  local appElement = hs.axuielement.applicationElement(app)
  if appElement == nil then
    return nil
  end
  if M.timeout and appElement.setTimeout then
    appElement:setTimeout(M.timeout)
  end
  return attr(appElement, "AXMenuBar")
end

local function readItems(menu, depth)
  local items = {}
  for index, element in ipairs(children(menu)) do
    local submenu = submenuOf(element)
    local item = {
      title = attr(element, "AXTitle") or "",
      mark = attr(element, "AXMenuItemMarkChar") or "",
      cmdChar = attr(element, "AXMenuItemCmdChar") or "",
      enabled = attr(element, "AXEnabled") ~= false,
      hasSubmenu = submenu ~= nil,
    }
    if submenu ~= nil and depth > 0 then
      item.children = readItems(submenu, depth - 1)
    end
    items[index] = item
  end
  return items
end

--- Lists an app's top-level menus as `{ title, index }`, or nil if the menu bar is unreadable
--- (usually missing Accessibility permission, or an app with no menu bar).
function M.topMenus(app)
  local bar = menuBar(app)
  if bar == nil then
    return nil
  end
  local menus = {}
  for index, element in ipairs(children(bar)) do
    menus[index] = { title = attr(element, "AXTitle") or "", index = index }
  end
  return menus
end

--- Reads the items of the top-level menu at `index`, descending `depth` submenu levels.
--- Returns nil if that menu no longer exists.
function M.readMenu(app, index, depth)
  local bar = menuBar(app)
  local top = bar and children(bar)[index]
  local menu = top and submenuOf(top)
  if menu == nil then
    return nil
  end
  return readItems(menu, depth or 0)
end

--- Presses the menu item at `path`: child indices from the menu bar down to the item.
---
--- `expectedTitle` guards against menus changing between listing and pressing (a window
--- closing shifts every later index): if the item at the final index has another title, the
--- same menu level is searched for `expectedTitle` instead.
---
--- Returns true, or false and a reason.
function M.press(app, path, expectedTitle)
  local bar = menuBar(app)
  if bar == nil then
    return false, "the menu bar is unavailable"
  end

  local element = children(bar)[path[1]]
  for depth = 2, #path do
    local menu = element and submenuOf(element)
    if menu == nil then
      return false, "that menu no longer exists"
    end
    local items = children(menu)
    element = items[path[depth]]
    if depth == #path and expectedTitle ~= nil and attr(element, "AXTitle") ~= expectedTitle then
      element = nil
      for _, candidate in ipairs(items) do
        if attr(candidate, "AXTitle") == expectedTitle then
          element = candidate
          break
        end
      end
    end
  end

  if element == nil then
    return false, "the menu item is gone"
  end
  local result, err = element:performAction("AXPress")
  if not result then
    return false, err or "the app rejected the press"
  end
  return true
end

return M
