# Architecture: MacWipePlus 清潔模式

## 概述

MacWipePlus 是 macOS 13+ 原生選單列 App，使用 SwiftUI 建立設定與清潔畫面，使用 AppKit 管理跨 Space 的全螢幕覆蓋視窗，使用 Quartz Event Tap 在清潔模式期間攔截可攔截的鍵盤、滑鼠與觸控板事件。輸入攔截器只保留 `Esc` 的按下/放開事件供 3 秒解鎖狀態機使用，其餘事件直接丟棄；退出、倒數結束、App 被終止或系統重開機時都必須停止 event tap 並關閉覆蓋視窗。

清潔模式的核心狀態集中在一個明確的狀態機，不讓 View、Event Tap callback 或 Timer 各自維護狀態。偏好透過 `UserDefaults` 保存最後有效的時間與快捷鍵設定；所有使用者輸入先經過純函式驗證，再寫入偏好。未授予 Accessibility 時仍使用全螢幕 overlay 捕捉一般輸入；授權後才加上 session-level Event Tap。

## Files to Create / Modify

### 新建

| File | Purpose |
|------|---------|
| `MacWipePlus/MacWipePlusApp.swift` | App 入口、MenuBarExtra 與生命週期組裝 |
| `MacWipePlus/App/AppCoordinator.swift` | 組合設定、清潔模式、權限與快捷鍵服務；不渲染 UI |
| `MacWipePlus/App/AppState.swift` | App 層級狀態與清潔模式狀態機 |
| `MacWipePlus/Features/CleaningMode/CleaningModeView.swift` | 黑色清潔畫面、底部提醒與倒數顯示 |
| `MacWipePlus/Features/CleaningMode/CleaningModeWindowController.swift` | 為每個 NSScreen 建立與銷毀全螢幕覆蓋視窗 |
| `MacWipePlus/Features/CleaningMode/CleaningModeService.swift` | 啟動/退出清潔模式的業務流程與安全收尾 |
| `MacWipePlus/Features/CleaningMode/CleaningModeState.swift` | 清潔模式狀態、剩餘時間與退出進度模型 |
| `MacWipePlus/Features/Settings/SettingsView.swift` | 時間、快捷鍵與權限設定 UI |
| `MacWipePlus/Features/Settings/SettingsViewModel.swift` | 設定表單狀態、驗證與保存流程 |
| `MacWipePlus/Domain/CleaningDuration.swift` | 快捷時間、自訂秒數與不自動退出的型別/驗證 |
| `MacWipePlus/Infrastructure/Input/EventTapInputBlocker.swift` | 建立、啟用、停用 Quartz Event Tap |
| `MacWipePlus/Infrastructure/Input/EscapeHoldTracker.swift` | 追蹤 `Esc` 長按 3 秒並發出解鎖事件 |
| `MacWipePlus/Infrastructure/Input/GlobalHotKeyService.swift` | 註冊、取消與驗證全域啟動快捷鍵；預設為 Control-Option-Command-M |
| `MacWipePlus/Infrastructure/Permissions/AccessibilityPermissionService.swift` | 檢查 Accessibility 信任狀態與開啟系統設定 |
| `MacWipePlus/Infrastructure/Preferences/PreferencesStore.swift` | 保存與載入最後有效設定 |
| `MacWipePlus/Resources/Localizable.xcstrings` | 英文與繁體中文字串資源 |
| `MacWipePlusTests/Domain/CleaningDurationTests.swift` | 時間驗證與格式化單元測試 |
| `MacWipePlusTests/Features/CleaningModeStateTests.swift` | 清潔模式狀態轉移與 Esc 解鎖單元測試 |
| `MacWipePlusTests/Infrastructure/EscapeHoldTrackerTests.swift` | 長按邊界與取消行為單元測試 |
| `MacWipePlusTests/Infrastructure/PreferencesStoreTests.swift` | 偏好保存、讀取與無效資料回退測試 |
| `MacWipePlusTests/Features/SettingsViewModelTests.swift` | 表單驗證與保存契約測試 |
| `MacWipePlusUITests/CleaningModeUITests.swift` | 清潔畫面、倒數、語系與退出提示 UI 測試 |

### 修改

| File | Change |
|------|--------|
| `MacWipePlus.xcodeproj/project.pbxproj` | 建立 macOS App target、測試 target、權限說明與最低系統版本 |
| `MacWipePlus/Info.plist` | 設定 `LSUIElement`，避免 Dock 顯示一般 App 圖示；加入 Accessibility 使用說明 |
| `MacWipePlus/MacWipePlus.entitlements` | 依發布方式配置必要 entitlement；不以 entitlement 取代使用者授予的 Accessibility 權限 |

## Responsibility Map

| 元件 | 層級 | 負責 | 不碰 |
|------|------|------|------|
| `MacWipePlusApp` | App composition | 建立依賴與 SwiftUI scene | 清潔模式業務邏輯、輸入攔截細節 |
| `AppCoordinator` | Application | 組合服務、轉送啟動與退出事件 | View layout、Quartz callback 細節 |
| `CleaningModeService` | Feature service | 驗證前置條件、依序開啟視窗/攔截/計時，保證退出清理 | UI rendering、偏好表單驗證 |
| `CleaningModeState` | Domain state | 定義 idle、starting、active、exiting、failed 狀態與轉移 | AppKit window、系統 I/O |
| `CleaningModeView` | View | 顯示黑色背景、底部提示、剩餘時間與退出進度，並在 fallback 模式吞掉 overlay 內的一般輸入 | 讀寫 UserDefaults、建立 event tap |
| `CleaningModeWindowController` | Platform adapter | 建立每螢幕 borderless full-screen NSWindow、設定 window level/collection behavior | 輸入攔截、倒數計時、偏好保存 |
| `EventTapInputBlocker` | Platform adapter | 在有 Accessibility 權限時攔截可攔截輸入、只轉送 Esc 狀態給 tracker、停止時釋放 tap | overlay fallback、解鎖業務規則、UI、保存設定 |
| `EscapeHoldTracker` | Domain adapter | 以 key down/up 與時鐘計算 3 秒長按、處理取消與重置 | 直接關閉視窗、操作 event tap |
| `GlobalHotKeyService` | Platform adapter | 註冊/取消全域啟動快捷鍵並發出啟動事件 | 決定使用哪個清潔時間、清潔畫面 |
| `AccessibilityPermissionService` | Platform adapter | 檢查權限、提供前往系統設定的動作 | 自行授予或繞過系統權限 |
| `SettingsViewModel` | ViewModel | 表單狀態、輸入驗證、保存有效設定、權限提示狀態 | 建立視窗、攔截輸入 |
| `PreferencesStore` | Persistence | UserDefaults 編解碼、版本化 key 與預設值 | UI 驗證、清潔模式狀態轉移 |
| `CleaningDuration` | Domain | 定義 preset/custom/never、邊界驗證與顯示文字 | UserDefaults、SwiftUI、Timer |

## Interface Design

```swift
enum CleaningDuration: Equatable, Codable {
    case seconds(Int)
    case never

    static let defaultValue: CleaningDuration = .seconds(120)
    static let presets: [CleaningDuration] = [
        .seconds(15), .seconds(30), .seconds(60),
        .seconds(120), .seconds(300), .seconds(600)
    ]

    var seconds: Int? { get }
    func validate() -> ValidationResult
}

enum CleaningModeState: Equatable {
    case idle
    case starting
    case active(remainingSeconds: Int?)
    case exiting(reason: ExitReason)
    case failed(CleaningModeError)
}

protocol CleaningModeServicing {
    func start(using duration: CleaningDuration) async
    func exit(reason: ExitReason)
}

protocol InputBlocking {
    func start(onEscapeEvent: @escaping (EscapeEvent) -> Void) throws
    func stop()
}

protocol HoldingEscapeTracking {
    func handle(_ event: EscapeEvent) -> EscapeHoldState
    func reset()
}

protocol PreferencesStoring {
    var lastDuration: CleaningDuration { get set }
    var globalHotKey: GlobalHotKey { get set }
}
```

實作注意事項：

- `CGEventTapCreate` 使用 session 層級的 active filter；Apple 文件指出，非 root 程序要接收 key up/down 事件必須取得 Accessibility 信任，因此只有在 `AXIsProcessTrusted()` 為真時啟用 Event Tap。
- Event Tap callback 只執行常數時間的事件分類與回傳，不在 callback 內觸碰 SwiftUI 或執行阻塞 I/O。`Esc` 事件以值型別轉交主執行緒的 `EscapeHoldTracker`。
- `Esc` 的 key down/up 事件保留給解鎖追蹤器；其他鍵盤 key down/up、modifier、滑鼠按鍵、滾輪、gesture 與 pointing 事件回傳 `nil` 以丟棄。電源鍵、Touch ID 與其他不會進入可攔截 event tap 的硬體事件不宣稱可阻擋。
- Event Tap 被系統停用時，服務必須監聽 tap disabled 狀態並嘗試重新啟用；重新啟用失敗時立即退出清潔模式，不能繼續顯示假鎖定狀態。
- `CleaningModeWindowController` 使用 AppKit `NSWindow`，而不是只依賴 SwiftUI `fullScreenCover`，以便設定 `.screenSaver` window level、跨 Space 顯示與無邊框尺寸。
- 每個顯示器建立一個覆蓋視窗；顯示器變更、睡眠、喚醒或解析度改變時重新同步視窗集合。
- `MenuBarExtra` 適合持續提供選單列入口；App 設為 `LSUIElement`，不在 Dock 顯示一般 App 入口。

## Data Flow

### Journey 1：選單列啟動

選單列 `MenuBarExtra` → `AppCoordinator.startRequested(duration)` → `CleaningModeWindowController.presentOnAllScreens()` → 若 `AXIsProcessTrusted()` 則啟用 `EventTapInputBlocker`，否則使用 overlay input capture → `CleaningModeState.active` → `CleaningModeView` 顯示底部提示與倒數 → `CleaningModeService.exit(.timerCompleted)` → 停止倒數 → 停止 Event Tap（若有）→ 關閉所有覆蓋視窗 → `CleaningModeState.idle`。

### Journey 2：全域快捷鍵啟動與 Esc 退出

`GlobalHotKeyService` 收到預設或自訂快捷鍵 → `AppCoordinator` 讀取 `PreferencesStore.lastDuration` → 依 Journey 1 啟動 → Event Tap 保留 `Esc` key down/up → `EscapeHoldTracker` 更新 0–3 秒進度 → 3 秒完成 → `CleaningModeService.exit(.escapeHeld)` → 依固定順序停止 timer、停止輸入攔截、關閉覆蓋、恢復 idle。

### Journey 3：自訂時間與保存

`SettingsView` 輸入 → `SettingsViewModel` 將字串解析成正整數 → `CleaningDuration.validate()` → 驗證成功後寫入 `PreferencesStore` → 下次選單列啟動或快捷鍵啟動讀取同一有效值；驗證失敗則只更新表單錯誤，不寫入偏好。

### 異常退出

Timer 完成、權限失效、event tap 建立失敗、tap 無法重新啟用或 App lifecycle 結束 → `CleaningModeService.exit(reason)` 執行 idempotent cleanup → 停止 timer → 停止 event tap → 關閉 overlay windows → 清除 transient state。重複呼叫 cleanup 必須安全且不留下 event tap 或 overlay window。

## Build Sequence

### Phase 1 — 專案骨架（additive）

- 建立 Xcode macOS App target、測試 target、SwiftUI/原生 AppKit 混用設定。
- 建立 `CleaningDuration`、`CleaningModeState`、偏好 key 與本地化資源。
- 先完成純記憶體 domain tests。

### Phase 2 — 設定與選單列（additive）

- 實作 `PreferencesStore`、`SettingsViewModel`、設定 UI 與 `MenuBarExtra`。
- 加入時間 preset、自訂秒數、不自動退出與上次設定保存。
- 完成設定單元測試與基本 UI 測試。

### Phase 3 — 清潔畫面（additive）

- 實作多螢幕 `NSWindow` controller、黑色畫面、底部提醒、倒數顯示與雙語文字。
- 使用 fake clock 測試倒數與狀態轉移。

### Phase 4 — 輸入攔截與安全退出（additive）

- 實作 Accessibility 權限檢查、Quartz Event Tap、Esc hold tracker 與 idempotent cleanup。
- 先用可注入的 input source 測試事件分類，再在真機執行手動安全測試。

### Phase 5 — 全域快捷鍵與整合（additive）

- 實作 global hot key service。
- 將選單列、快捷鍵、設定、倒數、Event Tap 與 overlay 串成完整 journey。
- 建立可直接開啟的本機 `.app` build 產物。

### Phase 6 — 發布硬化（additive）

- 補充權限說明、錯誤提示與 crash-safe cleanup。
- 驗證 Intel/Apple Silicon build；若要分發給其他 Mac，再處理 Developer ID signing/notarization。

## Infra Reuse

本專案是獨立 macOS App，不沿用 `/Users/maple/Desktop/nccu-toolkit` 的 Next.js、FSD 或 pnpm 基礎設施。

- SwiftUI `MenuBarExtra`：用於持續顯示選單列入口；Apple 文件說明其用途是讓 App 即使未 active 仍可提供常用功能。
- AppKit `NSWindow`：用於跨螢幕、跨 Space 的清潔覆蓋視窗。
- Core Graphics `CGEventTapCreate` / `CGEvent.tapEnable`：用於建立與啟停 active event filter。
- ApplicationServices `AXIsProcessTrusted`：用於檢查 Accessibility 權限。
- `UserDefaults` / `@AppStorage`：只保存本機偏好，不保存輸入內容或螢幕內容。
- Swift String Catalog：提供英文與繁體中文本地化。

## Test Strategy

架構階段只定義開發者測試；使用者視角的完整 QA、權限探索與真機安全測試由 QA 階段獨立驗證。

### Unit Test 邊界

| 目標 | 測試行為 |
|------|---------|
| `CleaningDuration` | preset、10 秒與 3,600 秒邊界、自訂秒數、`never` 的編解碼、格式化與無效輸入 |
| `CleaningModeState` | idle → starting → active → exiting/failed 的合法與非法轉移 |
| `EscapeHoldTracker` | 低於 3 秒不退出、按住時顯示 3/2/1 倒數、剛好 3 秒退出、放開後重置、重複 keyDown 不重設進度 |
| `SettingsViewModel` | 有效輸入保存、無效輸入顯示錯誤且不覆蓋舊值 |
| `PreferencesStore` | 空白偏好回傳預設 120 秒、有效偏好 round-trip、未知版本安全回退 |
| `EventTapInputBlocker` | Esc keyDown/keyUp 轉交、其他鍵盤/滑鼠/滾輪/gesture/pointing 事件回傳 nil、不可攔截硬體事件不作保證、stop 後不再攔截、tap failure 轉成錯誤 |
| `CleaningModeService` | 各種退出原因都只執行一次完整 cleanup |
| `GlobalHotKeyService` | 預設快捷鍵為 Control-Option-Command-M、自訂快捷鍵可註冊、衝突時拒絕新值並保留舊值 |
| Emergency shortcut | Control-Option-Esc 直接退出清潔模式，也接受 Control-Option-Command-Esc；Option-Command-Esc 保留給 macOS Force Quit |

### Integration Test 邊界

| Journey 步驟 | Test Chain |
|-------------|-----------|
| 選單列啟動 → 清潔 → 自動退出 | fake menu action → service start → fake input blocker active → fake clock expires → blocker stopped → overlay dismissed |
| 快捷鍵啟動 → Esc 退出 | global hot key event → load last duration → service active → Esc down/up events → 3-second tracker completion → service cleanup |
| 自訂時間 → 下次沿用 | settings input → validation → preferences write → new coordinator start → same duration passed to service |
| 權限失效 → fallback | permission unavailable or tap failure → overlay input capture remains active → timer/Esc still exits safely |
| 事件分類 → 安全收尾 | Esc down/up → tracker progress → 3 seconds complete → stop timer → stop event tap → dismiss overlays → idle; repeated exit remains safe |

### Mock 決策

| 項目 | Mock / Real | 原因 |
|------|------------|------|
| `UserDefaults` | Mock suite | 測試不可污染使用者真實偏好 |
| Clock/timer | Fake | 精確測試 3 秒 Esc 與任意倒數，不等待真實時間 |
| Event Tap | Fake adapter for UT/IT | 測試事件分類與 cleanup；真實 tap 留給 macOS 真機 QA |
| `NSWindow` | Fake controller for service tests | 避免測試依賴螢幕與 Space；視窗佈局由 UI test/真機驗證 |
| Accessibility permission | Mock in developer tests, Real in QA | 系統授權不可在自動測試中可靠控制 |
| Global hot key | Fake event source in IT | 驗證因果鏈，不依賴測試機目前快捷鍵狀態 |

### Coverage 要求

- `CleaningDuration`、`EscapeHoldTracker`、`CleaningModeState` 與 `CleaningModeService` 核心邏輯至少 90%。
- 整體開發者測試至少 80%。
- 真實 Event Tap、權限、全螢幕多顯示器、睡眠/喚醒與強制結束不以 coverage 取代，必須由 QA 在真機驗證。

## 開放問題

- 預設全域快捷鍵為 `Control-Option-Command-M`，並允許使用者自訂；衝突時拒絕新值並保留上一個有效設定。
- 自訂秒數限制為 10–3,600 秒；0、負數、小數、空值與超過 3,600 秒皆拒絕；不自動退出使用獨立的 `.never` 設定表示。
- 若只在自己的 Mac 使用，可使用未簽章本機 build；若要交付其他人，需要 Apple Developer ID signing/notarization，這是發布流程而非 App 核心功能。
- 電源鍵、Touch ID 與部分硬體級事件不保證能被一般 App 攔截，UI 與說明不得宣稱「所有輸入」都能被阻擋。
