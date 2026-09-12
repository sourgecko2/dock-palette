# DockPalette

Command palette for opening macOS windows, regardless of status or location.

![DockPalette demo](https://raw.githubusercontent.com/sourgecko2/dock-palette/media/demo.gif)

Most Mac window switchers are paid, closed-source menu-bar apps. DockPalette does the same job, but it's free and open source.

- **Free and hackable.** No license fee, and since it's just Lua, you can read exactly what it does or bend it to your workflow.
- **Two-stage fuzzy palette.** Press the hotkey (SUPER + O by default), fuzzy-pick an app, then fuzzy-pick one of its windows, without leaving your keyboard. No more scanning a flat list of every window on your Mac.
- **Fits into an existing [Hammerspoon](https://www.hammerspoon.org) setup.** If you're already scripting hotkeys, spaces, or window layout in Hammerspoon, DockPalette is just another Spoon, not a separate app competing for Accessibility permissions and menu-bar space.

## Quick start

You need macOS 26 or later and Hammerspoon 1.1 or later, with Accessibility access granted to Hammerspoon in System Settings.

```sh
git clone https://github.com/sourgecko2/dock-palette.git ~/Developer/dock-palette
~/Developer/dock-palette/scripts/install.sh
```

```sh
git remote add origin https://github.com/sourgecko2/dock-palette.git
```

Copy [`examples/init.lua`](examples/init.lua) into `~/.hammerspoon/init.lua`, then choose **Reload Config** from the Hammerspoon menu. The install script symlinks the Spoon.

## Updating

a `git pull` followed by a config reload of Hammerspoon is all an update needs.

## Usage

| Hotkey (example) | First palette | Second palette |
| --- | --- | --- |
| Super+O (`switch`) | Running apps | That app's windows |

Type to filter both palettes fuzzily. Return picks a row and Esc closes the palette. Apps are listed most recently used first.

To skip the app step for apps you use constantly, bind app hotkeys:

```lua
spoon.DockPalette:bindAppHotkeys({ ["com.apple.Safari"] = { { "cmd", "alt", "ctrl", "shift" }, "s" } })
```

## Licence

[MIT](LICENSE)
