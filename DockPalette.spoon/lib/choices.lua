--- Builds hs.chooser rows from plain app and menu data.
---
--- hs.chooser round-trips rows through Objective-C, so rows carry only strings and numbers.
--- The matching actions (menu paths to press) are returned in a separate table keyed by
--- each row's `id`, and stay on the Lua side. Pure Lua; no `hs.*`.

local M = {}

local function statusFor(app)
  if app.frontmost then
    return "Frontmost"
  elseif app.hidden then
    return "Hidden"
  end
  return nil
end

--- Orders running apps for the first palette step.
---
--- `apps` is a list of `{ name, bundleID, pid, hidden, frontmost }`. `recency(pid)` returns
--- a rank (1 = most recent) or nil. Ranked apps come first; the rest follow by `dockRank(name)`
--- (1 = leftmost, or nil if the app isn't in the Dock) when given, then alphabetically.
function M.apps(apps, recency, dockRank)
  local entries = {}
  for i, app in ipairs(apps) do
    entries[i] = {
      app = app,
      rank = recency and recency(app.pid),
      dockRank = dockRank and dockRank(app.name),
      order = i,
    }
  end

  table.sort(entries, function(a, b)
    if a.rank and b.rank then
      if a.rank ~= b.rank then
        return a.rank < b.rank
      end
    elseif a.rank or b.rank then
      return a.rank ~= nil
    elseif a.dockRank and b.dockRank then
      if a.dockRank ~= b.dockRank then
        return a.dockRank < b.dockRank
      end
    elseif a.dockRank or b.dockRank then
      return a.dockRank ~= nil
    else
      local nameA, nameB = (a.app.name or ""):lower(), (b.app.name or ""):lower()
      if nameA ~= nameB then
        return nameA < nameB
      end
    end
    return a.order < b.order
  end)

  local rows = {}
  for i, entry in ipairs(entries) do
    local app = entry.app
    rows[i] = {
      text = app.name,
      subText = statusFor(app),
      id = "app:" .. tostring(app.pid),
      pid = app.pid,
      bundleID = app.bundleID,
    }
  end
  return rows
end

--- Builds the second step of the switcher for one app: just its windows.
---
--- `windows` and `heuristic` come from `menu_parse.windowItems`. `opts` takes `windowMenuIndex`
--- (menu bar index of the Window menu). Returns rows and an actions table keyed by row id.
function M.appItems(appName, windows, opts)
  opts = opts or {}
  local rows, actions = {}, {}
  local function push(row, action)
    rows[#rows + 1] = row
    actions[row.id] = action
  end

  if #windows == 0 then
    push({
      text = "No window - make a new one?",
      subText = "Sends ⌘N to " .. appName,
      id = "notice",
    }, { kind = "newWindow" })
  end

  for i, window in ipairs(windows) do
    local subText
    if window.minimised then
      subText = "Minimised window"
    elseif window.current then
      subText = "Current window"
    else
      subText = "Window"
    end
    if opts.heuristic then
      subText = subText .. " (guessed from menu layout)"
    end
    push({
      text = window.title,
      subText = subText,
      id = "window:" .. i,
    }, {
      kind = "window",
      title = window.title,
      path = { opts.windowMenuIndex, window.index },
    })
  end

  return rows, actions
end

return M
