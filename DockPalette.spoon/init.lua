--- === DockPalette ===
---
--- Obsidian-style palette for macOS app windows. Pick an app, then jump to any of its windows,
--- on other desktops or minimised too.
---
--- Windows and commands come from each app's own menu bar via the Accessibility API. An app's
--- Window menu lists every window it owns, whichever Space it is on, which Accessibility
--- window lists do not.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "DockPalette"
obj.version = "0.1.0"
obj.author = "Sam Lindeyer"
obj.homepage = "https://github.com/sourgecko2/dock-palette"
obj.license = "MIT - https://opensource.org/licenses/MIT"

local SPOON_DIR = hs.spoons.scriptPath()

local function lib(name)
  return dofile(SPOON_DIR .. "lib/" .. name .. ".lua")
end

local fuzzy = lib("fuzzy")
local parse = lib("menu_parse")
local rowsFor = lib("choices")
local MRU = lib("mru")
local serialize = lib("serialize")
local axMenu = lib("ax_menu")
local dock = lib("dock")

local SUPER = { "cmd", "alt", "ctrl", "shift" }

-- hs.chooser fades its panel out asynchronously after a row is picked; when that panel
-- resigns key, macOS hands focus back to whatever app was frontmost before the panel took
-- it. If that lands after our action runs, it undoes it. Set above 0 to make our follow-up
-- action wait for the panel's close + refocus to settle first, so it runs last and sticks.
local CHOOSER_CLOSE_SETTLE = 0

-- Extra headroom (in rows) added on top of the visible choice count, so the native row-height
-- rounding doesn't clip the last row or force a scrollbar to appear when the list just fits.
local ROW_PADDING = 1

-- How far down the screen's usable frame the chooser's top edge sits, as a fraction of its
-- height. Passed explicitly to hs.chooser:show() so the panel anchors there regardless of how
-- many rows are visible, instead of hs.chooser's default of re-centering the panel around its
-- current height (which shifts the whole box up and down as the row count changes).
local ANCHOR_TOP_FRACTION = 0.1

--- DockPalette.defaultHotkeys
--- Variable
--- Suggested binding on the ⌃⌥⇧⌘ layer: `switch` = Super+O.
obj.defaultHotkeys = {
  switch = { SUPER, "o" },
}

--- DockPalette.windowMenuTitles
--- Variable
--- Titles of the menu that lists an app's windows. Default `{ "Window" }`.
obj.windowMenuTitles = parse.DEFAULTS.windowMenuTitles

--- DockPalette.bringAllToFrontTitles
--- Variable
--- Titles of the Window-menu item after which AppKit lists windows. Default `{ "Bring All to Front" }`.
obj.bringAllToFrontTitles = parse.DEFAULTS.bringAllToFrontTitles

--- DockPalette.windowMenuExcludeTitles
--- Variable
--- Window-menu items after "Bring All to Front" that are commands, not windows: macOS's Window
--- Sets adds "Arrange in Front" and "Remove Window from Set" there, and apps with tabbed
--- windows (e.g. Outlook) can add tab-management commands like "Show Previous Tab" or "Merge
--- All Windows" in the same run. Run `:dumpMenus()` to see what an app reports. Default is the
--- set above plus "Cycle Through Windows", "Show Previous Tab", "Show Next Tab", "Move Tab to
--- New Window", "Merge All Windows" and "Show Progress Window".
obj.windowMenuExcludeTitles = parse.DEFAULTS.windowMenuExcludeTitles

--- DockPalette.minimisedMarks
--- Variable
--- Menu mark characters that flag a minimised window. Run `:dumpMenus()` to see what an app reports.
obj.minimisedMarks = parse.DEFAULTS.minimisedMarks

--- DockPalette.currentMarks
--- Variable
--- Menu mark characters that flag the app's current window. Default `{ "✓", "✔" }`.
obj.currentMarks = parse.DEFAULTS.currentMarks

--- DockPalette.excludedBundleIDs
--- Variable
--- Bundle IDs to leave out of the app list. Default `{}`.
obj.excludedBundleIDs = {}

--- DockPalette.orderByDockPosition
--- Variable
--- Order apps that aren't recently used by their left-to-right position in the Dock, instead
--- of alphabetically. Recently used apps still come first either way. Default `false`.
obj.orderByDockPosition = false

--- DockPalette.chooserRows
--- Variable
--- Maximum number of rows each palette shows; it shrinks to fit when there are fewer choices.
--- Default `12`.
obj.chooserRows = 12

--- DockPalette.chooserWidth
--- Variable
--- Palette width as a percentage of the screen. Default `40`.
obj.chooserWidth = 40

--- DockPalette:init()
--- Method
--- Called by hs.loadSpoon(). Sets up internal state; does not bind anything.
function obj:init()
  self.logger = hs.logger.new(self.name)
  self._mru = MRU.new()
  self._icons = {}
  self._apps = {}
  self._choosers = {}
  self._appHotkeys = {}
  return self
end

function obj:_config()
  return parse.withDefaults({
    windowMenuTitles = self.windowMenuTitles,
    bringAllToFrontTitles = self.bringAllToFrontTitles,
    windowMenuExcludeTitles = self.windowMenuExcludeTitles,
    minimisedMarks = self.minimisedMarks,
    currentMarks = self.currentMarks,
  })
end

function obj:_fail(message)
  self.logger.w(message)
  hs.alert.show(message)
  return nil
end

-- Caps the chooser's visible row count to however many choices there are, plus a little
-- padding, so the panel never shows a bunch of trailing empty rows but also doesn't clip the
-- last one. Never exceeds the configured chooserRows.
function obj:_rowsFor(choices)
  return math.max(1, math.min(#choices + ROW_PADDING, self.chooserRows))
end

-- The screen point the chooser's top-left corner should sit at, fixed regardless of the
-- current row count. Falls back to hs.chooser's own centering if the screen is unavailable.
function obj:_anchorPoint()
  local screen = hs.screen.mainScreen()
  local frame = screen and screen:frame()
  if frame == nil then
    return nil
  end
  local width = frame.w * (self.chooserWidth / 100)
  return {
    x = frame.x + (frame.w - width) / 2,
    y = frame.y + frame.h * ANCHOR_TOP_FRACTION,
  }
end

-- One reusable chooser per palette step. Filtering is ours (fuzzy), not hs.chooser's
-- substring match: with a queryChangedCallback set, hs.chooser leaves filtering to Lua.
function obj:_chooser(step)
  local state = self._choosers[step]
  if state then
    return state
  end

  state = { rows = {}, onChoice = nil }
  state.chooser = hs.chooser.new(function(row)
    local onChoice = state.onChoice
    state.onChoice = nil
    if row and onChoice then
      hs.timer.doAfter(CHOOSER_CLOSE_SETTLE, function()
        onChoice(row)
      end)
    end
  end)
  state.chooser:width(self.chooserWidth)
  state.chooser:invalidCallback(function() end)
  state.chooser:queryChangedCallback(function(query)
    local choices = fuzzy.rank(query, state.rows)
    state.chooser:rows(self:_rowsFor(choices))
    state.chooser:choices(choices)
  end)

  self._choosers[step] = state
  return state
end

function obj:_present(step, rows, placeholder, onChoice)
  local state = self:_chooser(step)
  state.rows = rows
  state.onChoice = onChoice
  state.chooser:placeholderText(placeholder)
  state.chooser:query("")
  state.chooser:rows(self:_rowsFor(rows))
  state.chooser:choices(rows)
  state.chooser:show(self:_anchorPoint())
end

function obj:_attachIcons(rows)
  for _, row in ipairs(rows) do
    local bundleID = row.bundleID
    if bundleID then
      if self._icons[bundleID] == nil then
        self._icons[bundleID] = hs.image.imageFromAppBundle(bundleID) or false
      end
      row.image = self._icons[bundleID] or nil
    end
  end
  return rows
end

function obj:_runningApps()
  local excluded = {}
  for _, bundleID in ipairs(self.excludedBundleIDs) do
    excluded[bundleID] = true
  end
  local front = hs.application.frontmostApplication()
  local frontPid = front and front:pid()

  local apps = {}
  self._apps = {}
  for _, app in ipairs(hs.application.runningApplications()) do
    local bundleID = app:bundleID()
    if app:kind() == 1 and not (bundleID and excluded[bundleID]) then
      local pid = app:pid()
      self._apps[pid] = app
      apps[#apps + 1] = {
        name = app:name() or bundleID or tostring(pid),
        bundleID = bundleID,
        pid = pid,
        hidden = app:isHidden(),
        frontmost = pid == frontPid,
      }
    end
  end
  return apps
end

-- Reads the Dock's item order and returns a function mapping an app name to its position
-- (1 = leftmost), or nil if the order couldn't be read. Names are matched exactly, as System
-- Events reports them, which is normally the app's display name.
function obj:_dockRank()
  local names, err = dock.order()
  if names == nil then
    self.logger.w("Couldn't read the Dock's order: " .. tostring(err))
    return nil
  end
  local ranks = {}
  for i, name in ipairs(names) do
    if ranks[name] == nil then
      ranks[name] = i
    end
  end
  return function(name)
    return name and ranks[name]
  end
end

function obj:_pickApp(placeholder, onApp)
  local apps = self:_runningApps()
  local dockRank = self.orderByDockPosition and self:_dockRank() or nil
  local rows = rowsFor.apps(apps, function(pid)
    return self._mru:rank(pid)
  end, dockRank)
  self:_attachIcons(rows)
  self:_present("apps", rows, placeholder, function(row)
    local app = self._apps[row.pid]
    if app == nil or not app:isRunning() then
      return self:_fail("That app is no longer running")
    end
    onApp(app)
  end)
end

-- Reads just the Window menu, one level deep.
function obj:_snapshot(app)
  local tops = axMenu.topMenus(app)
  if tops == nil then
    return nil,
      ("Couldn’t read %s’s menu bar. Check Hammerspoon has Accessibility access."):format(
        app:name() or "the app"
      )
  end

  local windowMenuIndex = parse.findMenu(tops, self:_config().windowMenuTitles)
  local snapshot = {}
  if windowMenuIndex then
    snapshot.windowMenu = {
      title = tops[windowMenuIndex].title,
      index = windowMenuIndex,
      items = axMenu.readMenu(app, windowMenuIndex, 0) or {},
    }
  end
  return snapshot
end

function obj:_run(app, action)
  if action == nil or action.kind == "none" then
    return
  end

  if action.kind == "newWindow" then
    hs.eventtap.keyStroke({ "cmd" }, "n", 0, app)
    if app:isHidden() then
      app:unhide()
    end
    app:activate()
    return
  end

  -- AXPress selects the window internally (makes it the app's key window) but doesn't
  -- reliably raise the app or switch Spaces on its own when the app isn't already frontmost —
  -- that needs an explicit activate(). By the time we get here, CHOOSER_CLOSE_SETTLE has
  -- already let the chooser's close animation (and macOS's own refocus of the previously
  -- frontmost app) finish, so this activate() runs last and is the one that sticks.
  local ok, reason = axMenu.press(app, action.path, action.title)
  if not ok then
    return self:_fail(("Couldn’t select “%s”: %s"):format(action.title or "?", reason))
  end
  if app:isHidden() then
    app:unhide()
  end
  app:activate()
end

function obj:_showAppItems(app)
  local snapshot, err = self:_snapshot(app)
  if snapshot == nil then
    return self:_fail(err)
  end
  local config = self:_config()
  local windowMenu = snapshot.windowMenu
  local windows, heuristic = parse.windowItems(windowMenu and windowMenu.items or {}, config)
  local rows, actions = rowsFor.appItems(app:name(), windows, {
    windowMenuIndex = windowMenu and windowMenu.index,
    heuristic = heuristic,
  })
  self:_present("items", rows, app:name() .. " — windows", function(row)
    self:_run(app, actions[row.id])
  end)
end

--- DockPalette:showSwitcher()
--- Method
--- Opens the app palette, then the chosen app's windows.
function obj:showSwitcher()
  self:_pickApp("Switch to a window of…", function(app)
    self:_showAppItems(app)
  end)
end

--- DockPalette:showApp(hint)
--- Method
--- Skips the app palette and opens one running app's windows palette directly.
---
--- Parameters:
---  * hint - a bundle ID, app name or pid, as accepted by `hs.application.get()`
function obj:showApp(hint)
  local app = hs.application.get(hint)
  if app == nil then
    return self:_fail(("%s isn’t running"):format(tostring(hint)))
  end
  self:_showAppItems(app)
end

--- DockPalette:dumpMenus(target) -> string
--- Method
--- Prints a snapshot of an app's Window menu to the Hammerspoon Console, and returns it.
---
--- Parameters:
---  * target - an app name, bundle ID, pid, or hs.application object
function obj:dumpMenus(target)
  local app = target
  if type(target) ~= "userdata" then
    app = hs.application.get(target)
  end
  if app == nil then
    return self:_fail("No running app matches " .. tostring(target))
  end
  local snapshot, err = self:_snapshot(app)
  if snapshot == nil then
    return self:_fail(err)
  end
  local text = "return "
    .. serialize.serialize({
      app = app:name(),
      bundleID = app:bundleID(),
      menuBar = axMenu.topMenus(app),
      windowMenu = snapshot.windowMenu,
    })
  print(text)
  return text
end

--- DockPalette:bindHotkeys(mapping)
--- Method
--- Binds hotkeys. Supported actions: `switch`.
---
--- Parameters:
---  * mapping - e.g. `{ switch = {{"cmd","alt","ctrl","shift"}, "o"} }`, or `spoon.DockPalette.defaultHotkeys`
function obj:bindHotkeys(mapping)
  hs.spoons.bindHotkeysToSpec({
    switch = function()
      self:showSwitcher()
    end,
  }, mapping)
  return self
end

--- DockPalette:bindAppHotkeys(mapping)
--- Method
--- Binds hotkeys that open one app's windows palette directly, skipping the app step.
--- Calling it again replaces the previous app hotkeys.
---
--- Parameters:
---  * mapping - e.g. `{ ["com.apple.Safari"] = {{"cmd","alt","ctrl","shift"}, "s"} }`; keys are
---    anything `hs.application.get()` accepts
function obj:bindAppHotkeys(mapping)
  for _, hotkey in pairs(self._appHotkeys) do
    hotkey:delete()
  end
  self._appHotkeys = {}
  for hint, spec in pairs(mapping or {}) do
    self._appHotkeys[hint] = hs.hotkey.bindSpec(spec, function()
      self:showApp(hint)
    end)
  end
  return self
end

--- DockPalette:start()
--- Method
--- Starts tracking app activation so the app palette lists recently used apps first.
function obj:start()
  self:stop()
  local front = hs.application.frontmostApplication()
  if front then
    self._mru:touch(front:pid())
  end
  self._watcher = hs.application.watcher.new(function(_, event, app)
    if app == nil then
      return
    end
    local ok, pid = pcall(app.pid, app)
    if not ok then
      return
    end
    if event == hs.application.watcher.activated then
      self._mru:touch(pid)
    elseif event == hs.application.watcher.terminated then
      self._mru:remove(pid)
    end
  end)
  self._watcher:start()
  return self
end

--- DockPalette:stop()
--- Method
--- Stops tracking app activation. Hotkeys stay bound.
function obj:stop()
  if self._watcher then
    self._watcher:stop()
    self._watcher = nil
  end
  return self
end

return obj
