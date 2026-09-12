-- Paste into ~/.hammerspoon/init.lua after running scripts/install.sh, then reload Hammerspoon.

hs.loadSpoon("DockPalette")

local super = { "cmd", "alt", "ctrl", "shift" }

spoon.DockPalette:bindHotkeys({
  switch = { super, "o" }, -- app → its windows
})

spoon.DockPalette:start()
