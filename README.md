# Dotfiles

Personal macOS configuration files for keyboard shortcuts, window management,
clipboard history, Dock badge indicators, and automatic Tailscale exit-node
switching. Most of the automation is provided by
[Hammerspoon](https://www.hammerspoon.org/), a macOS app that runs Lua
configuration files.

## Contents

- `hammerspoon/init.lua` — Hammerspoon automation and keyboard shortcuts
- `hammerspoon/local.example.lua` — template for machine-specific settings
- `hammerspoon/local.lua` — private machine-specific settings (ignored by Git)

## Requirements

- [Hammerspoon](https://www.hammerspoon.org/)
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) for mapping Caps Lock
  to the Hyper key
- [Tailscale](https://tailscale.com/) for the network-based exit-node automation

The **Hyper key** means pressing Command + Option + Control + Shift together.
Karabiner-Elements can map Caps Lock to this combination, making the shortcuts
much easier to type.

## Installation

1. Install the applications listed above.

2. Clone this repository (replace `YOUR_USERNAME` with your GitHub username if
   you've forked it):

   ```
   git clone git@github.com:YOUR_USERNAME/dotfiles.git ~/dotfiles
   ```

3. Create Hammerspoon's configuration directory if it doesn't already exist:

   ```
   mkdir -p ~/.hammerspoon
   ```

4. Link the repository's `init.lua` to the location where Hammerspoon expects its
   main configuration:

   ```
   ln -s ~/dotfiles/hammerspoon/init.lua ~/.hammerspoon/init.lua
   ```

   Finder shows this link as an alias. Edit the file in the repository (or
   through the link), and don't replace the link with a copy, or the repository
   will stop tracking your changes.

5. Create your private, machine-specific configuration from the example:

   ```
   cp ~/dotfiles/hammerspoon/local.example.lua ~/.hammerspoon/local.lua
   ```

6. Edit `~/.hammerspoon/local.lua` as described in the next section.

7. Open Hammerspoon and select **Reload Config** from its menu-bar icon.

To pick up changes made on another Mac, run `git pull` in `~/dotfiles` and
reload the config.

## Configuring `local.lua`

`local.lua` contains settings that may be different for each Mac and may reveal
private network information. It lives at `~/.hammerspoon/local.lua` and is not
stored in the repository.

The file must return a Lua table with two settings:

```lua
return {
    trustedNetworks = {
        ["Home Wi-Fi"] = true,
        ["Office Wi-Fi"] = true,
    },

    tailscaleExitNode = "100.64.0.10",
}
```

Replace the example values as follows:

- `Home Wi-Fi` and `Office Wi-Fi` are Wi-Fi network names (SSIDs) that you
  trust. Use the names exactly as they appear in the macOS Wi-Fi menu. Add one
  `["network name"] = true,` line for each trusted network. It's fine to keep
  only one line.
- `100.64.0.10` is the Tailscale IP address of the device configured as your
  exit node. You can find it in the Tailscale app or by running
  `tailscale status` in Terminal.

On a trusted network, the automation disables the Tailscale exit node. On any
other named Wi-Fi network, it enables the configured exit node. If Hammerspoon
can't read the current network name, it doesn't enable the exit node.

Keep the quotation marks, commas, braces, and the final `return` structure as
shown. After making a change, choose **Reload Config** from the Hammerspoon
menu. If the configuration doesn't load, select **Console** from that menu to
see the Lua error and its line number.

## Hammerspoon shortcuts

### Applications

Press the shortcut again while its application is frontmost to hide it.

| Shortcut  | Application        |
| --------- | ------------------ |
| Hyper + C | Calendar           |
| Hyper + F | Finder             |
| Hyper + G | Google Chrome      |
| Hyper + M | Messages           |
| Hyper + O | Obsidian           |
| Hyper + R | Reminders          |
| Hyper + S | Safari             |
| Hyper + T | Terminal           |
| Hyper + X | Visual Studio Code |

### Window management

| Shortcut        | Action                                              |
| --------------- | --------------------------------------------------- |
| Hyper + H/J/K/L | Left/bottom/top/right half                          |
| Hyper + Y/U/B/N | Top-left/top-right/bottom-left/bottom-right quarter |
| Hyper + Return  | Toggle maximize and restore                         |
| Hyper + , / .   | Move to previous/next display                       |

### Utilities

| Shortcut  | Action                                                      |
| --------- | ----------------------------------------------------------- |
| Hyper + P | Toggle sleep prevention; a coffee icon appears while active |
| Hyper + V | Open searchable, in-memory clipboard history                |

## Menu-bar status item

One shared menu-bar item shows the coffee icon and the nonzero Dock badge
counts for Messages, Reminders, and Things. Click it to toggle caffeine or open
an app that has a badge. The item disappears when there is nothing to show.

Clipboard history isn't written to disk and is cleared when Hammerspoon exits
or reloads.

### Adding another badge

The monitored apps are listed in the `dockBadgeApps` table in `init.lua`. To
mirror another app's Dock badge, add one entry:

```lua
{name = "Things", dockName = "Things", launchName = "Things3", icon = "☑️"},
```

- `name` — label used in the dropdown menu
- `dockName` — the app's label in the Dock (hover over its icon to check)
- `launchName` — the name `hs.application.launchOrFocus` expects, which can
  differ from the Dock label
- `icon` — what appears in the menu bar next to the count

Entries appear in the menu bar and dropdown in the order listed. Badges only
appear if the app's own badge setting is turned on (in Things, enable the badge
count under Settings → General).

## Permissions

Some features require enabling Hammerspoon under **System Settings → Privacy &
Security**:

- Accessibility for window, keyboard, Dock-badge, and paste actions
- Automation for reading the Dock through System Events
- Location Services for identifying the current Wi-Fi network

These permissions are granted per Mac, so repeat them on each machine.
