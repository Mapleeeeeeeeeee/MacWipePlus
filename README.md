# MacWipePlus

Free, local macOS cleaning mode for macOS 13+.

## Build

This project currently builds with the Swift toolchain:

```sh
swift build
./scripts/build-app.sh
```

The app bundle is written to `.build/MacWipePlus.app`.

## First launch

MacWipePlus needs Accessibility permission while cleaning mode is active so it can block input before it reaches other apps. Add the app in:

System Settings → Privacy & Security → Accessibility

The app does not record, store, or transmit keyboard, pointer, or screen data.

## Controls

- Menu bar: start cleaning mode and choose 15 seconds, 30 seconds, 1/2/5/10 minutes, custom seconds, or never auto-exit.
- Default global shortcut: `Control-Option-Command-M`.
- Custom shortcut: choose `Set Shortcut…` from the menu bar item.
- Exit: hold `Esc` for 3 seconds; the overlay shows the remaining hold time.
- Emergency exit: press `Control-Option-Command-Esc`. `Option-Command-Esc` remains the macOS Force Quit shortcut and is not reliable for app-level interception.
- Custom duration range: 10–3,600 seconds.
