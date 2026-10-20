# MenuBarPet

A small pixel-art pet that lives in your macOS menu bar. It walks along the bar, follows your cursor, chases balls, and barks when something needs your attention.

## Features

- **Pet care:** feed your pet, throw a ball, rename it, and watch its mood over time.
- **Skins:** several pets to choose from, including dogs (blue, black, akita), a wolf, Kirby, and Yoshi.
- **Visitors:** call a visitor to wander by.
- **Follow cursor:** the pet can trail your mouse.
- **Break reminders:** gentle walk reminders after long active stretches, with a one hour snooze.
- **Mac reactions:** the pet reacts to things happening on your Mac, such as plugging in power.
- **Calendar reminders:** the pet barks shortly before a meeting starts (asks for calendar access).
- **Quiet mode:** silence the pet manually, or let it follow macOS Focus when readable (needs Full Disk Access).
- **Launch at login** and a choice of walking in front of or behind the menu bar text.

## Requirements

- macOS 14 or later
- Swift 5.9 toolchain (Xcode or Command Line Tools)

## Build and run

```sh
./build.sh
open build/MenuBarPet.app
```

The script builds a release binary, assembles `build/MenuBarPet.app` with the sprites and an `Info.plist`, and ad-hoc signs it. The app runs as a menu bar agent with no Dock icon.

Click the menu bar icon for the popover, or right-click for the full menu.

## URL scheme

Other tools can trigger the pet through the `menubarpet://` scheme:

| URL | Effect |
| --- | --- |
| `menubarpet://done` or `menubarpet://bark` | Pet barks "Woof! Done" and cheers |
| `menubarpet://walk` | Pet asks for a walk |

For example, use it from a Claude Code hook so the pet barks when a task finishes:

```sh
open -g menubarpet://done
```

## Project layout

```
Sources/MenuBarPet/   App code (main, Dog, Pet, Reactions, PopoverView, StripWindow, Sprites)
Resources/sprites/    PNG frames per skin, visitors, and props
tools/                Python scripts that generate or slice the sprites
build.sh              Builds and packages the .app bundle
```

## Regenerating sprites

The scripts in `tools/` need Python 3 with `pillow`. The slicing scripts also need `numpy` and `scipy`.

```sh
python3 tools/make_sprites.py <vscode-pets/media/dog> Resources/sprites
python3 tools/make_kirby.py Resources/sprites
python3 tools/make_visitors.py Resources/sprites
python3 tools/slice_yoshi.py yoshi.png Resources/sprites
python3 tools/slice_wolf.py <sheet.jpeg> Resources/sprites
```

## Credits and licensing

This project is for personal use only. Several sprites are derived from third-party artwork and **must not be redistributed**:

- Dog sprites are derived from [vscode-pets](https://github.com/tonybaloney/vscode-pets) by Anthony Shaw (CC BY-ND 4.0). The license forbids distributing modified versions.
- Wolf frames are sliced from a fan-made sheet of Mojang's Minecraft wolf artwork.
- Kirby sprites are original pixel art drawn in the style of Nintendo and HAL's Kirby.
- Yoshi frames are sliced from the "DS Yoshi Sprites Recolor" sheet by llynog (Nintendo artwork).

See `Resources/sprites/CREDITS.txt` for details.
