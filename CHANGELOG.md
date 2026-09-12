# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Switcher would sometimes focus the picked window for a moment, then snap back to whatever
  app was frontmost before the palette opened. Cause: `hs.chooser`'s own close-panel animation
  hands focus back to the previously-frontmost app shortly after selection, which could land
  after `app:activate()` ran and undo it. Fixed with `CHOOSER_CLOSE_SETTLE`, a tunable delay
  before acting so our activate() runs after the chooser's own refocus and sticks. (An earlier
  attempt at this fix dropped `app:activate()` as supposedly redundant with the window-menu
  press — it isn't: without it, a background app's window never comes forward at all.)
- The heuristic that lists windows after "Bring All to Front" could pick up tab-management
  commands some apps add in that same run (e.g. Outlook's "Show Previous Tab", "Merge All
  Windows") and show them as if they were windows. Added them to the default
  `windowMenuExcludeTitles`.

## [0.1.0] - 2026-09-11

### Added

- Switcher palette: pick an app, then one of its windows (including other desktops and
  minimised windows), a new-window command, or "Show Dock menu".
- New-window palette, including submenu variants such as Safari's per-profile windows.
- Dock menu picker that opens an app's real right-click menu for keyboard navigation.
- Per-app hotkeys (`bindAppHotkeys`) that skip the app step.
- Fuzzy filtering (fzy-style scoring) and most-recently-used app ordering.
- `dumpMenus()` for inspecting an app's menus and capturing test fixtures.
- Unit and controller tests against fake Hammerspoon and Accessibility APIs, luacheck, StyLua
  and GitHub Actions CI.
