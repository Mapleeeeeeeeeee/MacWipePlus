import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import MacWipePlusCore

@main
final class MacWipePlusApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var cleaner: CleaningModeController!
    private let preferences = PreferencesStore()
    private let languagePreferences = LanguagePreferenceStore()
    private var globalHotKeyService: GlobalHotKeyService!

    static func main() {
        let application = NSApplication.shared
        let delegate = MacWipePlusApp()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        cleaner = CleaningModeController(preferences: preferences)
        globalHotKeyService = GlobalHotKeyService(
            onPress: { [weak self] in
                self?.cleaner.start(using: self?.preferences.lastDuration ?? .seconds(120))
            },
            onEmergency: { [weak self] in
                self?.cleaner.stop(reason: .emergency)
            }
        )
        installGlobalHotKey()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "MacWipePlus")
        statusItem.menu = makeMenu()
        if CommandLine.arguments.contains("--qa-autostart") {
            DispatchQueue.main.async { [weak self] in
                self?.cleaner.start(using: self?.qaDuration ?? .seconds(10))
            }
        }
    }

    private var qaDuration: CleaningDuration? {
        guard let index = CommandLine.arguments.firstIndex(of: "--qa-duration"),
              index + 1 < CommandLine.arguments.count,
              let seconds = Int(CommandLine.arguments[index + 1]) else { return nil }
        return CleaningDuration(seconds: seconds)
    }

    func applicationWillTerminate(_ notification: Notification) {
        globalHotKeyService.unregister()
        cleaner.stop(reason: .applicationQuit)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let start = makeMenuItem(title: AppCopy.startCleaning, action: #selector(startCleaning), imageName: "play.circle")
        start.target = self
        menu.addItem(start)

        let durationMenu = NSMenu(title: AppCopy.duration)
        for duration in CleaningDuration.presets {
            let item = makeMenuItem(title: duration.displayName, action: #selector(selectDuration(_:)), imageName: "clock")
            item.target = self
            item.representedObject = duration
            item.state = preferences.lastDuration == duration ? .on : .off
            durationMenu.addItem(item)
        }
        let never = makeMenuItem(title: CleaningDuration.never.displayName, action: #selector(selectDuration(_:)), imageName: "infinity")
        never.target = self
        never.representedObject = CleaningDuration.never
        never.state = preferences.lastDuration == .never ? .on : .off
        durationMenu.addItem(never)
        let custom = makeMenuItem(title: AppCopy.customSeconds, action: #selector(selectCustomDuration), imageName: "slider.horizontal.3")
        custom.target = self
        durationMenu.addItem(custom)
        let durationItem = makeMenuItem(title: AppCopy.duration, action: nil, imageName: "timer")
        durationItem.submenu = durationMenu
        menu.addItem(durationItem)

        let languageMenu = NSMenu(title: AppCopy.languageMenu)
        let selectedLanguage = languagePreferences.language
        for language in AppLanguage.allCases {
            let item = makeMenuItem(title: AppCopy.languageOption(language), action: #selector(selectLanguage(_:)), imageName: "globe")
            item.target = self
            item.representedObject = language
            item.state = selectedLanguage == language ? .on : .off
            languageMenu.addItem(item)
        }
        let languageItem = makeMenuItem(title: AppCopy.languageMenu, action: nil, imageName: "globe")
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        let shortcut = makeMenuItem(title: AppCopy.setShortcut, action: #selector(selectShortcut), imageName: "keyboard")
        shortcut.target = self
        menu.addItem(shortcut)
        menu.addItem(.separator())

        let quit = makeMenuItem(title: AppCopy.quit, action: #selector(quit), keyEquivalent: "q", imageName: "power")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func makeMenuItem(title: String, action: Selector?, keyEquivalent: String = "", imageName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.image = NSImage(systemSymbolName: imageName, accessibilityDescription: title)
        return item
    }

    @objc private func startCleaning() {
        cleaner.start(using: preferences.lastDuration)
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? CleaningDuration else { return }
        preferences.lastDuration = duration
        statusItem.menu = makeMenu()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let language = sender.representedObject as? AppLanguage else { return }
        guard languagePreferences.language != language else { return }
        languagePreferences.language = language
        statusItem.menu = makeMenu()
        cleaner.refresh()
    }

    @objc private func selectCustomDuration() {
        let alert = NSAlert()
        alert.messageText = AppCopy.customDurationTitle
        alert.informativeText = AppCopy.customDurationHint
        let input = NSTextField(string: preferences.lastDuration.seconds.map(String.init) ?? "120")
        input.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        alert.accessoryView = input
        alert.addButton(withTitle: AppCopy.save)
        alert.addButton(withTitle: AppCopy.cancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let value = Int(input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let duration = CleaningDuration(seconds: value) else {
            let error = NSAlert()
            error.messageText = AppCopy.invalidDuration
            error.informativeText = AppCopy.customDurationHint
            error.runModal()
            return
        }
        preferences.lastDuration = duration
        statusItem.menu = makeMenu()
    }

    @objc private func selectShortcut() {
        let alert = NSAlert()
        alert.messageText = AppCopy.shortcutTitle
        alert.informativeText = "\(AppCopy.shortcutHint)\n\n\(preferences.globalHotKey.displayName)"
        alert.addButton(withTitle: AppCopy.cancel)
        var captured: GlobalHotKey?
        let previous = preferences.globalHotKey
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62]
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                NSApp.abortModal()
                return nil
            }
            guard !modifierKeyCodes.contains(event.keyCode) else { return nil }
            let modifiers = event.modifierFlags.intersection([.control, .option, .command, .shift])
            guard !modifiers.isEmpty else { return nil }
            captured = GlobalHotKey(keyCode: event.keyCode, modifiers: modifiers)
            NSApp.stopModal(withCode: .alertFirstButtonReturn)
            return nil
        }
        alert.runModal()
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let captured {
            preferences.globalHotKey = captured
            if installGlobalHotKey() {
                statusItem.menu = makeMenu()
            } else {
                preferences.globalHotKey = previous
                _ = installGlobalHotKey()
            }
        }
    }

    @objc private func quit() {
        globalHotKeyService.unregister()
        cleaner.stop(reason: .applicationQuit)
        NSApp.terminate(nil)
    }

    @discardableResult
    private func installGlobalHotKey() -> Bool {
        let hotKey = preferences.globalHotKey
        do {
            try globalHotKeyService.register(keyCode: UInt32(hotKey.keyCode), modifiers: hotKey.carbonModifiers)
            return true
        } catch {
            NSLog("MacWipePlus could not register global shortcut %@: %@", hotKey.displayName, String(describing: error))
            return false
        }
    }
}

enum AppCopy {
    private static let languagePreferences = LanguagePreferenceStore()

    static var isTraditionalChinese: Bool {
        languagePreferences.language == .traditionalChinese
    }

    static var languageMenu: String { isTraditionalChinese ? "語言" : "Language" }
    static func languageOption(_ language: AppLanguage) -> String {
        switch language {
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        }
    }

    static var startCleaning: String { isTraditionalChinese ? "開始清潔模式" : "Start Cleaning Mode" }
    static var duration: String { isTraditionalChinese ? "清潔時間" : "Duration" }
    static var customSeconds: String { isTraditionalChinese ? "自訂秒數…" : "Custom seconds…" }
    static var setShortcut: String { isTraditionalChinese ? "設定快捷鍵…" : "Set Shortcut…" }
    static var quit: String { isTraditionalChinese ? "結束 MacWipePlus" : "Quit MacWipePlus" }
    static var customDurationTitle: String { isTraditionalChinese ? "自訂清潔時間" : "Custom cleaning duration" }
    static var customDurationHint: String { isTraditionalChinese ? "請輸入 10 到 3,600 秒的整數。" : "Enter a whole number from 10 to 3,600 seconds." }
    static var invalidDuration: String { isTraditionalChinese ? "無效的清潔時間" : "Invalid duration" }
    static var shortcutTitle: String { isTraditionalChinese ? "設定快捷鍵" : "Set shortcut" }
    static var shortcutHint: String { isTraditionalChinese ? "請按下含 Control、Option、Command 或 Shift 的快捷鍵；按 Esc 取消。" : "Press a shortcut containing Control, Option, Command, or Shift. Press Esc to cancel." }
    static var emergencyShortcutHint: String { isTraditionalChinese ? "緊急退出：⌃⌥Esc" : "Emergency: ⌃⌥Esc" }
    static var accessibilityTitle: String { isTraditionalChinese ? "需要輔助使用權限" : "Accessibility permission required" }
    static var accessibilityHint: String { isTraditionalChinese ? "請到系統設定 → 隱私權與安全性 → 輔助使用，允許 MacWipePlus 後再試一次。" : "Allow MacWipePlus in System Settings → Privacy & Security → Accessibility, then try again." }
    static var openSettings: String { isTraditionalChinese ? "開啟系統設定" : "Open System Settings" }
    static var save: String { isTraditionalChinese ? "儲存" : "Save" }
    static var cancel: String { isTraditionalChinese ? "取消" : "Cancel" }
}

struct PreferencesStore {
    private let defaults: UserDefaults
    private let durationKey = "lastDurationSeconds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastDuration: CleaningDuration {
        get {
            guard let value = defaults.object(forKey: durationKey) as? Int else { return .seconds(120) }
            if value == 0 { return .never }
            return CleaningDuration(seconds: value) ?? .seconds(120)
        }
        nonmutating set {
            defaults.set(newValue.seconds ?? 0, forKey: durationKey)
        }
    }

    var globalHotKey: GlobalHotKey {
        get {
            let keyCode = UInt16(defaults.object(forKey: "globalHotKeyCode") as? Int ?? 46)
            let defaultModifiers = NSEvent.ModifierFlags.control.union(.option).union(.command).rawValue
            let rawModifiers = defaults.object(forKey: "globalHotKeyModifiers") as? UInt ?? defaultModifiers
            return GlobalHotKey(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: rawModifiers))
        }
        nonmutating set {
            defaults.set(Int(newValue.keyCode), forKey: "globalHotKeyCode")
            defaults.set(newValue.modifiers.rawValue, forKey: "globalHotKeyModifiers")
        }
    }
}

struct GlobalHotKey: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayName: String {
        let modifierText = [
            (modifiers.contains(.control), "Control"),
            (modifiers.contains(.option), "Option"),
            (modifiers.contains(.shift), "Shift"),
            (modifiers.contains(.command), "Command")
        ].compactMap { $0.0 ? $0.1 : nil }.joined(separator: "-")
        let keyNames: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
            34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M", 49: "Space", 36: "Return", 48: "Tab"
        ]
        let key = keyNames[keyCode] ?? "Key \(keyCode)"
        return "\(modifierText)-\(key)"
    }
}

enum CleaningDuration: Equatable {
    case seconds(Int)
    case never

    static let presets: [CleaningDuration] = [.seconds(15), .seconds(30), .seconds(60), .seconds(120), .seconds(300), .seconds(600)]

    init?(seconds: Int?) {
        guard let seconds else { self = .never; return }
        guard (10...3_600).contains(seconds) else { return nil }
        self = .seconds(seconds)
    }

    var seconds: Int? {
        if case let .seconds(value) = self { return value }
        return nil
    }

    var displayName: String {
        switch self {
        case .never: return AppCopy.isTraditionalChinese ? "不自動退出" : "Never"
        case let .seconds(value):
            if value.isMultiple(of: 60) { return "\(value / 60) \(AppCopy.isTraditionalChinese ? "分鐘" : "min")" }
            return "\(value) \(AppCopy.isTraditionalChinese ? "秒" : "sec")"
        }
    }
}

enum ExitReason {
    case timerCompleted
    case escapeHeld
    case emergency
    case applicationQuit
    case failed
}

final class CleaningModeController {
    private let preferences: PreferencesStore
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var remainingSeconds: Int?
    private var inputBlocker: EventTapInputBlocker?
    private var escapeProgressTimer: Timer?
    private var escapeState = EscapeHoldStateMachine()
    private var waitingForEscapeRelease = false
    private var localInputMonitor: Any?
    private var globalEmergencyMonitor: Any?

    init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    func start(using duration: CleaningDuration) {
        guard windows.isEmpty, !waitingForEscapeRelease else { return }
        NSLog("MacWipePlus start requested: %@", duration.displayName)
        remainingSeconds = duration.seconds
        if AXIsProcessTrusted() {
            inputBlocker = EventTapInputBlocker(
                onEscape: { [weak self] event in self?.handle(event: event) },
                onEmergency: { [weak self] in self?.stop(reason: .emergency) }
            )
            do {
                try inputBlocker?.start()
                NSLog("MacWipePlus event tap started")
            } catch {
                NSLog("MacWipePlus event tap unavailable; using overlay input capture: %@", String(describing: error))
                inputBlocker = nil
            }
        }
        // Install global capture before presenting the overlay so startup input
        // cannot leak into the app that was focused before cleaning mode.
        installLocalInputMonitor()
        installGlobalEmergencyMonitor()
        presentWindows()
        startTimer(for: duration)
    }

    func stop(reason: ExitReason) {
        timer?.invalidate()
        timer = nil
        escapeProgressTimer?.invalidate()
        escapeProgressTimer = nil
        _ = escapeState.keyUp()
        let preserveEscapeCapture = reason == .escapeHeld
        if !preserveEscapeCapture {
            if let localInputMonitor { NSEvent.removeMonitor(localInputMonitor) }
            localInputMonitor = nil
            if let globalEmergencyMonitor { NSEvent.removeMonitor(globalEmergencyMonitor) }
            globalEmergencyMonitor = nil
            inputBlocker?.stop()
            inputBlocker = nil
            waitingForEscapeRelease = false
        } else {
            // Keep swallowing key-repeat until the physical Esc key is released;
            // otherwise the next app receives repeated Esc presses and may beep.
            waitingForEscapeRelease = true
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        remainingSeconds = nil
    }

    private func presentWindows() {
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.contentView = CleaningView(
                getRemaining: { [weak self] in self?.remainingSeconds },
                getEscapeProgress: { [weak self] in
                    guard let self else { return 0 }
                    return self.escapeState.progress * EscapeHoldStateMachine.holdDuration
                },
                onEscape: { [weak self] event in self?.handle(event: event) }
            )
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            if let view = window.contentView { window.makeFirstResponder(view) }
            windows.append(window)
        }
    }

    private func startTimer(for duration: CleaningDuration) {
        guard duration.seconds != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, let remaining = self.remainingSeconds else { return }
            if remaining <= 1 {
                timer.invalidate()
                self.stop(reason: .timerCompleted)
            } else {
                self.remainingSeconds = remaining - 1
                self.windows.forEach {
                    ($0.contentView as? CleaningView)?.refresh()
                    $0.displayIfNeeded()
                }
            }
        }
    }

    private func handle(event: EscapeEvent) {
        switch event {
        case .down:
            let wasHolding = escapeState.isHolding
            _ = escapeState.keyDown(at: ProcessInfo.processInfo.systemUptime)
            guard !wasHolding else { return }
            guard escapeProgressTimer == nil else { return }
            refreshWindows()
            escapeProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self else { return }
                let action = self.escapeState.tick(at: ProcessInfo.processInfo.systemUptime)
                self.refreshWindows()
                if action == .exit {
                    timer.invalidate()
                    self.stop(reason: .escapeHeld)
                }
            }
        case .up:
            _ = escapeState.keyUp()
            escapeProgressTimer?.invalidate()
            escapeProgressTimer = nil
            refreshWindows()
            if waitingForEscapeRelease {
                waitingForEscapeRelease = false
                inputBlocker?.stop()
                inputBlocker = nil
                if let localInputMonitor { NSEvent.removeMonitor(localInputMonitor) }
                localInputMonitor = nil
                if let globalEmergencyMonitor { NSEvent.removeMonitor(globalEmergencyMonitor) }
                globalEmergencyMonitor = nil
            }
        case .emergency:
            _ = escapeState.emergencyExit()
            stop(reason: .emergency)
        }
    }

    private func refreshWindows() {
        windows.forEach {
            ($0.contentView as? CleaningView)?.refresh()
            $0.displayIfNeeded()
        }
    }

    func refresh() {
        refreshWindows()
    }

    private func installLocalInputMonitor() {
        localInputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            let hasEmergencyModifiers = event.modifierFlags.contains([.command, .option])
                || event.modifierFlags.contains([.control, .option])
            if event.keyCode == 53 && hasEmergencyModifiers {
                self.handle(event: .emergency)
                return nil
            }
            if event.keyCode == 53 {
                self.handle(event: event.type == .keyDown ? .down : .up)
            }
            return nil
        }
    }

    private func installGlobalEmergencyMonitor() {
        globalEmergencyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            let hasEmergencyModifiers = event.modifierFlags.contains([.command, .option])
                || event.modifierFlags.contains([.control, .option])
            guard hasEmergencyModifiers else { return }
            self?.stop(reason: .emergency)
        }
    }
}

final class CleaningView: NSView {
    private static let escapeHoldDuration: TimeInterval = 3
    private let getRemaining: () -> Int?
    private let getEscapeProgress: () -> TimeInterval
    private let onEscape: (EscapeEvent) -> Void
    private let label = NSTextField(labelWithString: "")

    init(getRemaining: @escaping () -> Int?, getEscapeProgress: @escaping () -> TimeInterval, onEscape: @escaping (EscapeEvent) -> Void) {
        self.getRemaining = getRemaining
        self.getEscapeProgress = getEscapeProgress
        self.onEscape = onEscape
        super.init(frame: .zero)
        wantsLayer = true
        label.textColor = .white
        label.font = .systemFont(ofSize: 12)
        label.alignment = .center
        addSubview(label)
        updateText()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape(event.modifierFlags.contains([.command, .option]) ? .emergency : .down)
        }
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 53 { onEscape(.up) }
    }

    override func flagsChanged(with event: NSEvent) { retainFocus() }
    override func mouseDown(with event: NSEvent) { retainFocus() }
    override func mouseUp(with event: NSEvent) { retainFocus() }
    override func rightMouseDown(with event: NSEvent) { retainFocus() }
    override func rightMouseUp(with event: NSEvent) { retainFocus() }
    override func otherMouseDown(with event: NSEvent) { retainFocus() }
    override func otherMouseUp(with event: NSEvent) { retainFocus() }
    override func scrollWheel(with event: NSEvent) { retainFocus() }

    private func retainFocus() {
        guard let window else { return }
        if !window.isKeyWindow { window.makeKeyAndOrderFront(nil) }
        if window.firstResponder !== self { window.makeFirstResponder(self) }
    }

    override func layout() {
        super.layout()
        label.frame = NSRect(x: 20, y: 24, width: bounds.width - 40, height: 22)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateText()
    }

    func refresh() {
        updateText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let elapsed = getEscapeProgress()
        guard elapsed > 0 else { return }

        let progress = min(1, max(0, elapsed / Self.escapeHoldDuration))
        let secondsLeft = max(1, Int(ceil(Self.escapeHoldDuration - elapsed)))
        let chipRect = NSRect(x: bounds.midX - 98, y: 72, width: 196, height: 56)
        let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: 16, yRadius: 16)
        NSColor(white: 0.09, alpha: 0.96).setFill()
        chipPath.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        chipPath.lineWidth = 1
        chipPath.stroke()

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let ringCenter = CGPoint(x: chipRect.minX + 30, y: chipRect.midY)
        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(3)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.14).cgColor)
        context.addArc(center: ringCenter, radius: 17, startAngle: .pi / 2, endAngle: .pi / 2 - (.pi * 2), clockwise: true)
        context.strokePath()
        context.setStrokeColor(NSColor.controlAccentColor.cgColor)
        context.addArc(center: ringCenter, radius: 17, startAngle: .pi / 2, endAngle: .pi / 2 - (.pi * 2 * progress), clockwise: true)
        context.strokePath()
        context.restoreGState()

        let title = AppCopy.isTraditionalChinese ? "長按 Esc" : "Hold Esc"
        let detail = AppCopy.isTraditionalChinese ? "\(secondsLeft) 秒" : "\(secondsLeft) seconds"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.5)
        ]
        NSAttributedString(string: title, attributes: titleAttributes)
            .draw(at: CGPoint(x: chipRect.minX + 57, y: chipRect.midY + 1))
        NSAttributedString(string: detail, attributes: detailAttributes)
            .draw(at: CGPoint(x: chipRect.minX + 57, y: chipRect.midY - 17))
    }

    private func updateText() {
        let progress = getEscapeProgress()
        if progress > 0 {
            let secondsLeft = max(1, Int(ceil(3 - progress)))
            label.stringValue = AppCopy.isTraditionalChinese
                ? "請繼續按住 Esc · \(secondsLeft) 秒後退出 · \(AppCopy.emergencyShortcutHint)"
                : "Keep holding Esc · exits in \(secondsLeft)s · \(AppCopy.emergencyShortcutHint)"
            return
        }
        if let remaining = getRemaining() {
            label.stringValue = AppCopy.isTraditionalChinese
                ? "清潔模式 · 剩餘 \(remaining) 秒 · 長按 Esc 3 秒退出 · \(AppCopy.emergencyShortcutHint)"
                : "Cleaning mode · \(remaining)s remaining · Hold Esc for 3 seconds to exit · \(AppCopy.emergencyShortcutHint)"
        } else {
            label.stringValue = AppCopy.isTraditionalChinese
                ? "清潔模式 · 不自動退出 · 長按 Esc 3 秒退出 · \(AppCopy.emergencyShortcutHint)"
                : "Cleaning mode · No automatic exit · Hold Esc for 3 seconds to exit · \(AppCopy.emergencyShortcutHint)"
        }
    }
}

enum EscapeEvent { case down, up, emergency }

final class EventTapInputBlocker {
    private static let systemDefinedEventType = CGEventType(rawValue: 14)!
    private var tap: CFMachPort?
    private let onEscape: (EscapeEvent) -> Void
    private let onEmergency: () -> Void
    private var commandDown = false
    private var optionDown = false
    private var controlDown = false

    init(onEscape: @escaping (EscapeEvent) -> Void, onEmergency: @escaping () -> Void) {
        self.onEscape = onEscape
        self.onEmergency = onEmergency
    }

    func start() throws {
        let eventTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, Self.systemDefinedEventType, .leftMouseDown, .leftMouseUp, .scrollWheel, .otherMouseDown, .otherMouseUp]
        let mask = eventTypes.reduce(CGEventMask(0)) { partialResult, eventType in
            partialResult | (CGEventMask(1) << CGEventMask(eventType.rawValue))
        }
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: eventTapCallback, userInfo: context)
        guard let tap else { throw NSError(domain: "MacWipePlus.EventTap", code: 1) }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        tap = nil
        commandDown = false
        optionDown = false
        controlDown = false
    }

    fileprivate func handle(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout, let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return nil
        }
        if type == Self.systemDefinedEventType {
            // Brightness, volume, media, and Fn-row hardware keys arrive here;
            // dropping them prevents system-level actions during cleaning mode.
            return nil
        }
        if type == .flagsChanged {
            commandDown = event.flags.contains(.maskCommand)
            optionDown = event.flags.contains(.maskAlternate)
            controlDown = event.flags.contains(.maskControl)
            return Unmanaged.passUnretained(event)
        }
        if event.type == .keyDown || event.type == .keyUp {
            commandDown = event.flags.contains(.maskCommand) || commandDown
            optionDown = event.flags.contains(.maskAlternate) || optionDown
            controlDown = event.flags.contains(.maskControl) || controlDown
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let hasReservedEmergencyModifiers = event.flags.contains([.maskCommand, .maskAlternate]) || (commandDown && optionDown)
            let hasFallbackEmergencyModifiers = event.flags.contains([.maskCommand, .maskAlternate, .maskControl]) || (commandDown && optionDown && controlDown)
            let hasSimpleEmergencyModifiers = event.flags.contains([.maskControl, .maskAlternate]) || (controlDown && optionDown)
            if keyCode == 53 && (hasReservedEmergencyModifiers || hasFallbackEmergencyModifiers || hasSimpleEmergencyModifiers) {
                DispatchQueue.main.async { [onEmergency] in onEmergency() }
                return nil
            }
            if keyCode == 53 {
                let escapeEvent: EscapeEvent = event.type == .keyDown ? .down : .up
                DispatchQueue.main.async { [onEscape] in onEscape(escapeEvent) }
            }
        }
        return nil
    }
}

private func eventTapCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<EventTapInputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
    return blocker.handle(event, type: type)
}
