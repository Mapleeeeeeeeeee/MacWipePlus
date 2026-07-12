# 語言偏好設定架構

## Files to Create / Modify

### Create

- `Sources/MacWipePlusCore/LanguagePreference.swift`：定義支援的語言與 `UserDefaults` 儲存契約。

### Modify

- `Sources/MacWipePlus/MacWipePlusApp.swift`：語言選單、語言選擇 action、`AppCopy` 的語言來源，以及清潔模式即時刷新。
- `Tests/RegressionTests/main.swift`：驗證英文預設、繁中 round-trip 與無效值 fallback。

## Responsibility Map

| 元件 | 層級 | 負責 | 不負責 |
|---|---|---|---|
| `AppLanguage` | Core model | 表達支援語言與穩定 raw value | UI 選單排版 |
| `LanguagePreferenceStore` | Core persistence | 從 `UserDefaults` 讀寫語言；缺失或無效值回英文 | 根據 macOS locale 自動判斷 |
| `AppCopy` | App presentation copy | 依目前 App 語言產生介面文字 | 保存偏好或提供選單 action |
| `MacWipePlusApp` | App controller | 建立語言子選單、保存選擇、刷新 menu/cleaning windows | 重新定義語言格式 |

## Interface Design

```swift
public enum AppLanguage: String, CaseIterable, Equatable {
    case english = "en"
    case traditionalChinese = "zh-Hant-TW"
}

public struct LanguagePreferenceStore {
    public static let key = "appLanguage"
    public init(defaults: UserDefaults = .standard)
    public var language: AppLanguage { get nonmutating set }
}
```

`LanguagePreferenceStore.language` 對缺失、未知或無效 raw value 回傳 `.english`；setter 只接受 `AppLanguage`，因此 UI 不會產生無效值。

## Data Flow

1. App 啟動或建立 menu → `LanguagePreferenceStore().language` → 缺省為 `.english`。
2. `AppCopy` 和清潔模式提示讀取相同 store → 產生目前語言文字。
3. 使用者在 Language 子選單選擇語言 → `LanguagePreferenceStore().language = selected`。
4. Controller 重建 status menu 並刷新清潔視窗 → 新語言立即可見。
5. 下次啟動再次從 `UserDefaults` 讀取保存值。

## Build Sequence

### Phase 1：語言 domain/persistence（additive）

- 新增 `AppLanguage` 與 `LanguagePreferenceStore`。
- 加入 core regression tests。

### Phase 2：App menu integration（additive）

- 將 `AppCopy` 語言來源改為 store。
- 新增 Language 子選單與選擇 action。
- 讓清潔模式可在偏好變更後刷新文字。

### Phase 3：驗證（non-breaking）

- 執行 build、regression tests、語言偏好 journey。
- 確認無程式碼仍依賴 `Locale.preferredLanguages`。

## Infra Reuse

- 沿用既有 `UserDefaults` 偏好儲存方式。
- 沿用 `NSMenuItem.state` 表示目前選項。
- 沿用 `statusItem.menu = makeMenu()` 立即重建選單的既有模式。

## Test Strategy

### Unit / regression

- 無偏好時回傳英文。
- 儲存繁中後重新建立 store 仍回傳繁中。
- 儲存英文後重新建立 store 回傳英文。
- 無效 raw value fallback 為英文。

### Integration

- 語言選擇透過同一個 `UserDefaults` key 流入 `AppCopy`，menu 與清潔提示使用一致語言。
- AppKit menu 與 cleaning overlay 的同步更新由 QA journey 手動驗證；現有 regression runner 不建立 NSApplication 或視窗，因此不在 core regression test 中 mock UI。

### Mock 決策

- 不 mock `UserDefaults` API；使用具名隔離 suite，測試完成後移除 persistent domain。
- 不測試 macOS system locale，因功能不再依賴它。
