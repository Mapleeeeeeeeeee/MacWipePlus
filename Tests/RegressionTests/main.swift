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

let tests: [(String, () throws -> Void)] = [
    ("holding Esc exits after three seconds without keyUp", testHoldingEscExitsAfterThreeSecondsWithoutKeyUp),
    ("releasing Esc before three seconds cancels exit", testReleasingEscBeforeThreeSecondsCancelsExit),
    ("emergency exit immediately resets state", testEmergencyExitImmediatelyResetsState)
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
