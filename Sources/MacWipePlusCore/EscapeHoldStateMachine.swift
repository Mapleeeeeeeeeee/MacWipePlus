import Foundation

public enum EscapeHoldAction: Equatable {
    case idle
    case progress(Double)
    case cancelled
    case exit
}

public struct EscapeHoldStateMachine {
    public static let holdDuration: TimeInterval = 3

    public private(set) var isHolding = false
    public private(set) var progress: Double = 0

    private var startedAt: TimeInterval?

    public init() {}

    public mutating func keyDown(at timestamp: TimeInterval) -> EscapeHoldAction {
        guard !isHolding else { return .progress(progress) }
        isHolding = true
        startedAt = timestamp
        progress = 0
        return .progress(progress)
    }

    public mutating func tick(at timestamp: TimeInterval) -> EscapeHoldAction {
        guard let startedAt, isHolding else { return .idle }
        progress = min(1, max(0, (timestamp - startedAt) / Self.holdDuration))
        if progress >= 1 {
            reset()
            return .exit
        }
        return .progress(progress)
    }

    public mutating func keyUp() -> EscapeHoldAction {
        guard isHolding else { return .idle }
        reset()
        return .cancelled
    }

    public mutating func emergencyExit() -> EscapeHoldAction {
        reset()
        return .exit
    }

    private mutating func reset() {
        isHolding = false
        startedAt = nil
        progress = 0
    }
}
