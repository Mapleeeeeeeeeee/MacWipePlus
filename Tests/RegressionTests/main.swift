import Foundation
import MacWipePlusCore

struct RegressionFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw RegressionFailure(description: message) }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    guard actual == expected else {
        throw RegressionFailure(description: "\(message): expected \(expected), got \(actual)")
    }
}

func testHoldingEscExitsAfterThreeSecondsWithoutKeyUp() throws {
    var machine = EscapeHoldStateMachine()
    try expectEqual(machine.keyDown(at: 100), .progress(0), "first Esc keyDown starts progress")
    try expectEqual(machine.keyDown(at: 101), .progress(0), "auto-repeat keyDown does not reset progress")
    try expect(machine.tick(at: 102.9) != .exit, "Esc must not exit before three seconds")
    try expectEqual(machine.tick(at: 103), .exit, "Esc exits at three seconds while still held")
    try expect(!machine.isHolding, "state resets after exit")
}

func testReleasingEscBeforeThreeSecondsCancelsExit() throws {
    var machine = EscapeHoldStateMachine()
    _ = machine.keyDown(at: 100)
    _ = machine.tick(at: 101)
    try expectEqual(machine.keyUp(), .cancelled, "early Esc release cancels the hold")
    try expectEqual(machine.tick(at: 104), .idle, "cancelled hold cannot exit later")
}

func testEmergencyExitImmediatelyResetsState() throws {
    var machine = EscapeHoldStateMachine()
    _ = machine.keyDown(at: 100)
    try expectEqual(machine.emergencyExit(), .exit, "emergency exit exits immediately")
    try expect(!machine.isHolding, "emergency exit resets hold state")
}

func testLanguagePreferenceDefaultsAndPersistsSupportedValues() throws {
    let suiteName = "MacWipePlusRegressionTests.LanguagePreference"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw RegressionFailure(description: "could not create isolated UserDefaults suite")
    }

    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let initialStore = LanguagePreferenceStore(defaults: defaults)
    try expectEqual(initialStore.language, .english, "missing language preference falls back to English")

    initialStore.language = .traditionalChinese
    try expectEqual(
        LanguagePreferenceStore(defaults: defaults).language,
        .traditionalChinese,
        "Traditional Chinese preference persists across store creation"
    )

    initialStore.language = .english
    try expectEqual(
        LanguagePreferenceStore(defaults: defaults).language,
        .english,
        "English preference persists across store creation"
    )

    defaults.set("unsupported", forKey: LanguagePreferenceStore.key)
    try expectEqual(
        LanguagePreferenceStore(defaults: defaults).language,
        .english,
        "unknown language preference falls back to English"
    )
}

let tests: [(String, () throws -> Void)] = [
    ("holding Esc exits after three seconds without keyUp", testHoldingEscExitsAfterThreeSecondsWithoutKeyUp),
    ("releasing Esc before three seconds cancels exit", testReleasingEscBeforeThreeSecondsCancelsExit),
    ("emergency exit immediately resets state", testEmergencyExitImmediatelyResetsState),
    ("language preference defaults and persists supported values", testLanguagePreferenceDefaultsAndPersistsSupportedValues)
]

do {
    for (name, test) in tests {
        try test()
        print("PASS: \(name)")
    }
    print("All MacWipePlus regression tests passed.")
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}
