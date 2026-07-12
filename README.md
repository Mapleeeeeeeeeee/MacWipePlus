# MacWipePlus

[繁體中文](README.zh-TW.md)

<p align="center">
  <img src="Resources/MacWipePlus-icon-source.png" width="128" alt="MacWipePlus app icon">
</p>

[![CI](https://github.com/Mapleeeeeeeeeee/MacWipePlus/actions/workflows/ci.yml/badge.svg)](https://github.com/Mapleeeeeeeeeee/MacWipePlus/actions/workflows/ci.yml)

Free, local macOS cleaning mode for macOS 13+.

## Quick start

1. Download the latest [`MacWipePlus.dmg`](https://github.com/Mapleeeeeeeeeee/MacWipePlus/releases/latest).
2. Open the DMG and drag `MacWipePlus.app` to Applications.
3. Because development builds are not signed or notarized yet, right-click the app, choose **Open**, then choose **Open** again.
4. Grant Accessibility permission in **System Settings → Privacy & Security → Accessibility**.
5. Launch MacWipePlus from Applications and use the menu bar icon to start cleaning mode.

## Features

- Blocks keyboard, trackpad, mouse clicks, and Fn-row system events while cleaning mode is active.
- Black fullscreen overlay with countdown and saved duration preferences.
- Hold `Esc` for 3 seconds to exit.
- Emergency exit: `Control-Option-Esc`.
- Custom duration range: 10–3,600 seconds.
- No keyboard, pointer, or screen data is recorded, stored, or transmitted.

## Controls

- Menu bar: choose 15 seconds, 30 seconds, 1/2/5/10 minutes, custom seconds, or never auto-exit.
- Default global shortcut: `Control-Option-Command-M`.
- Custom shortcut: choose **Set Shortcut…** from the menu bar item.
- Exit: hold `Esc` for 3 seconds; the overlay shows the remaining hold time.
- Emergency exit: `Control-Option-Esc`. `Control-Option-Command-Esc` is also supported.

## Build from source

```sh
swift build
./scripts/build-app.sh
```

The app bundle is written to `.build/MacWipePlus.app`.

To create a local DMG:

```sh
./scripts/package-dmg.sh
```

## Development

- `main` is the stable branch.
- `dev` produces development DMG and ZIP artifacts through GitHub Actions.
- Tags matching `v*` create a GitHub Release with DMG and ZIP assets.

## License

Apache License 2.0. See [LICENSE](LICENSE).
