# 語言偏好設定

## 背景與問題

目前 App 依 macOS 首選語言自動在繁體中文與英文之間切換。這會讓使用者在中文系統上首次啟動時看到中文，與產品希望「英文為預設語言、中文由使用者選擇」的行為不一致。

## 使用者角色

一般 MacWipePlus 使用者：希望首次啟動看到英文，並可在需要時切換成繁體中文。

## 需求情境

- 使用者首次啟動 App 時，看到英文選單與清潔模式提示。
- 使用者從選單列開啟語言設定，選擇繁體中文後，選單與清潔模式文字使用繁體中文。
- 使用者重新啟動 App 後，保留上次選擇的語言。
- 使用者選擇 English 後，所有支援的 App 文字回到英文。

## 設計意圖

- 英文是偏好不存在或值無效時的固定 fallback，避免系統語言意外改變產品初始體驗。
- 語言設定放在現有 menu bar 選單中，延續 App 的既有操作入口。
- 使用 `UserDefaults` 保存語言偏好，與現有 duration 和 shortcut 偏好一致。

## User Journey

### Journey 1：首次啟動 — 使用英文

前置條件：尚未保存語言偏好。

1. 使用者啟動 App → menu bar 選單顯示英文。
2. 使用者開始清潔模式 → 全螢幕提示顯示英文。

### Journey 2：切換繁體中文 — 立即套用並保存

前置條件：App 正在執行。

1. 使用者開啟 menu bar 選單 → 看見 Language 選單。
2. 使用者選擇 Traditional Chinese → 語言選項顯示選取狀態，主選單立即改為繁體中文。
3. 使用者開始清潔模式 → 清潔模式提示顯示繁體中文。
4. 使用者重新啟動 App → menu bar 選單仍顯示繁體中文。

### Journey 3：切回英文

前置條件：目前語言為繁體中文。

1. 使用者開啟 menu bar 選單 → 看見「語言」選單。
2. 使用者選擇 English → 主選單立即改為英文，English 顯示選取狀態。

## 替代流程

- 語言偏好值缺失、無法辨識或不是支援語言時，使用英文。
- macOS 系統語言改變不會覆蓋使用者已保存的 App 語言偏好。

## 錯誤情境

### 系統錯誤

- `UserDefaults` 無法讀取時，App 仍使用英文記憶體內預設值。

### 使用者誤操作

- 語言選單只提供支援的兩個選項，不提供無效值輸入。

## Out of Scope

- 不新增簡體中文或其他語言。
- 不將 README 或 macOS 權限說明改成可切換的 bundle localization。
- 不提供獨立設定視窗。

## 整合點

- `NSMenu`：新增語言子選單與選取狀態。
- `UserDefaults`：保存 App 語言偏好。
- `AppCopy`、`CleaningDuration`、`CleaningView`：改用保存的 App 語言，而不是 macOS 語言。

## Acceptance Criteria

- Given App 沒有語言偏好 / When 啟動 App / Then 所有主要選單文字與清潔提示使用英文。
- Given App 沒有語言偏好且 macOS 使用繁體中文 / When 啟動 App / Then App 仍使用英文。
- Given App 正在使用英文 / When 使用者選擇繁體中文 / Then 語言偏好保存、選單立即切換為繁體中文、後續清潔提示使用繁體中文。
- Given App 已保存繁體中文 / When 重新啟動 App / Then 選單與清潔提示仍使用繁體中文。
- Given App 正在使用繁體中文 / When 使用者選擇 English / Then 選單立即切換為英文並保存偏好。
- Given 語言偏好值缺失或無效 / When App 讀取偏好 / Then 使用英文。

## 開放問題

無。
