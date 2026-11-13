<img src="./.github/logo.png" width="80" />

# TinyHand

[![Latest release](https://img.shields.io/github/v/release/nilbuild/tinyhand?display_name=tag&sort=semver&cacheSeconds=3600)](https://github.com/nilbuild/tinyhand/releases/latest)
[![Platform: macOS | Windows](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey)](https://tinyhand.app)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

A tiny hand on a stick that points at things on your Mac screen.

<img src="./.github/banner.jpg" alt="TinyHand: a tiny hand for your Mac" />

[![Download for macOS](https://img.shields.io/badge/Download_for_macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/nilbuild/tinyhand/releases/latest/download/TinyHand.dmg)
[![Visit website](https://img.shields.io/badge/Visit_website-ffffff?style=for-the-badge&logo=safari&logoColor=black)](https://tinyhand.app)

macOS 13 or later, Apple Silicon and Intel.

## Install

Open `TinyHand.dmg`, drag TinyHand to Applications and allow **Accessibility** when asked. It needs that to turn your clicks into taps. TinyHand updates itself.

## Use

| | |
|---|---|
| Click the menu bar icon, or **⌃⌥H** | Turn the pointer on or off |
| Right-click the menu bar icon | Menu and Settings |
| Click | Tap (nothing underneath gets clicked) |
| Hold and drag | Draw on the screen |
| Draw a rough shape | It snaps into a clean line, arrow, circle, box, triangle, diamond, star or heart (turn it off in Settings, Drawing) |
| Draw a small V at the end of a line | The line becomes an arrow |
| Hold **⌘** while drawing | Add an arrowhead to the end of the line |
| **⌃⌥X** | Clear the drawing |
| **Esc** | Clear everything and turn the pointer off |

While the pointer is on, a small toolbar at the bottom of the screen lets you pick one of
36 hands or a laser dot, mute the tap sound, or exit.

## Automation

Launchers like Raycast or Alfred, and shell scripts, can control TinyHand with
`tinyhand://` links. Use `open -g` so TinyHand doesn't take focus:

```sh
open -g tinyhand://toggle
```

| Link | Action |
|---|---|
| `tinyhand://on`, `tinyhand://off`, `tinyhand://toggle` | Turn the pointer on, off, or flip it |
| `tinyhand://clear` | Clear the drawing |
| `tinyhand://style/<id>` | Switch to a hand (or `laser`) and turn the pointer on |
| `tinyhand://sound/on`, `/off`, `/toggle` | Tap sound for the current pointer |

While TinyHand runs, it keeps its current state in
`~/Library/Application Support/TinyHand/state.json`: whether the pointer is on, the
selected style, whether sound is on, and every style with its `id`, name and type
(`hand`, `custom` or `laser`). The file is removed when TinyHand quits. It also
records the app's `pid`, so a file left behind by a crash can be detected.

If TinyHand isn't running, opening any link launches it and then runs the command.

## Windows

TinyHand also runs on Windows 10 and 11 (x64): the same hands, drawing, shape snapping, tap sounds and
Settings, from the tray instead of the menu bar. Build it with `make -C windows` (mingw-w64) and see
[windows/README.md](windows/README.md) for details.

## License

MIT. See [LICENSE](LICENSE).
