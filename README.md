# DockPalette

Command palette for opening macOS windows, regardless of status or location.
Built as a [Hammerspoon](https://www.hammerspoon.org) Spoon.
Press a hotkey (SUPER + O by default) and fuzzy-pick an app. You can then jump to any of its windows, even ones on another desktop or minimised, all from the keyboard.

## Quick start

You need macOS 26 or later and Hammerspoon 1.1 or later, with Accessibility access granted to Hammerspoon in System Settings.

```sh
git clone https://github.com/sourgecko2/dock-palette.git ~/Developer/dock-palette
~/Developer/dock-palette/scripts/install.sh
```git remote add origin https://github.com/sourgecko2/dock-palette.git

Copy [`examples/init.lua`](examples/init.lua) into `~/.hammerspoon/init.lua`, then choose **Reload Config** from the Hammerspoon menu. The install script symlinks the Spoon.
```

## Updating

```sh
a `git pull` followed by a reload is all an update needs.
```

## Usage

| Hotkey (example) | First palette | Second palette |
| --- | --- | --- |
| Super+O (`switch`) | Running apps | That app's windows |

Type to filter both palettes fuzzily. Return picks a row and Esc closes the palette. Apps are listed most recently used first.

To skip the app step for apps you use constantly, bind app hotkeys:

```lua
spoon.DockPalette:bindAppHotkeys({ ["com.apple.Safari"] = { { "cmd", "alt", "ctrl", "shift" }, "s" } })
```

## Development

```sh
brew install luarocks stylua && luarocks install luacheck
bash scripts/check.sh    # luacheck, stylua --check (same as CI)
```

## Licence

[MIT](LICENSE)
