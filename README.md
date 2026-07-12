# MacWipePlus

[![CI](https://github.com/Mapleeeeeeeeeee/MacWipePlus/actions/workflows/ci.yml/badge.svg)](https://github.com/Mapleeeeeeeeeee/MacWipePlus/actions/workflows/ci.yml)

Free, local macOS cleaning mode for macOS 13+.

免費、本機運作的 macOS 清潔模式，支援 macOS 13 以上。

## Features / 功能

- Blocks keyboard, trackpad, mouse clicks, and Fn-row system events while cleaning mode is active.
- 清潔模式期間攔截鍵盤、觸控板、滑鼠點擊與 Fn 列系統事件。
- Black fullscreen overlay with countdown and saved duration preferences.
- 黑色全螢幕遮罩、倒數計時與儲存的時間偏好。
- Hold `Esc` for 3 seconds to exit.
- 長按 `Esc` 3 秒退出。
- Emergency exit: `Control-Option-Esc`.
- 緊急退出：`Control-Option-Esc`。

## Build / 建置

This project builds with the Swift toolchain:

本專案使用 Swift toolchain 建置：

```sh
swift build
./scripts/build-app.sh
```

The app bundle is written to `.build/MacWipePlus.app`.

App bundle 會輸出到 `.build/MacWipePlus.app`。

## First launch / 第一次啟動

MacWipePlus needs Accessibility permission while cleaning mode is active so it can block input before it reaches other apps. Add the app in:

MacWipePlus 需要「輔助使用」權限，才能在清潔模式期間攔截輸入，避免送到其他 App。請到：

System Settings → Privacy & Security → Accessibility

系統設定 → 隱私權與安全性 → 輔助使用

The app does not record, store, or transmit keyboard, pointer, or screen data.

本 App 不會記錄、儲存或傳送鍵盤、指標或螢幕資料。

## macOS security warning / macOS 安全性警告

Development builds are not signed or notarized with an Apple Developer certificate. macOS may show a warning that the app cannot be opened or is from an unidentified developer.

開發版本目前沒有使用 Apple Developer 憑證簽署或 notarize，macOS 可能會顯示「無法開啟」或「未識別開發者」警告。

To open the app:

開啟方式：

1. Right-click `MacWipePlus.app` / 對 `MacWipePlus.app` 按右鍵
2. Choose **Open** / 選擇「打開」
3. Choose **Open** again in the confirmation dialog / 在確認視窗再次選擇「打開」

This is normally required only once per downloaded build.

通常每個下載版本只需要完成一次。

## Controls / 控制方式

- Menu bar: start cleaning mode and choose 15 seconds, 30 seconds, 1/2/5/10 minutes, custom seconds, or never auto-exit.
- 選單列：啟動清潔模式，選擇 15 秒、30 秒、1/2/5/10 分鐘、自訂秒數或不自動退出。
- Default global shortcut: `Control-Option-Command-M`.
- 預設全域快捷鍵：`Control-Option-Command-M`。
- Custom shortcut: choose `Set Shortcut…` from the menu bar item.
- 可從選單列選擇「設定快捷鍵⋯」。
- Exit: hold `Esc` for 3 seconds; the overlay shows the remaining hold time.
- 退出：長按 `Esc` 3 秒；遮罩會顯示剩餘時間。
- Emergency exit: `Control-Option-Esc`. `Control-Option-Command-Esc` is also supported.
- 緊急退出：`Control-Option-Esc`，也支援 `Control-Option-Command-Esc`。
- Custom duration range: 10–3,600 seconds.
- 自訂時間範圍：10–3,600 秒。

## License / 授權

License will be added before the first public GitHub release.

正式公開 GitHub Release 前會補上授權條款。
