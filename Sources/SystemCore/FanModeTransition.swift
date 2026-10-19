import Foundation

// Firmware handoff is asynchronous: an acknowledged unlock is not an unlocked mode.
enum FanModeTransition {
    static func perform(attempts: Int, write: () throws -> Void, confirmed: () -> Bool, wait: () -> Void) throws {
        var lastError: Error?
        for _ in 0..<max(0, attempts) {
            do { try write(); lastError = nil }
            catch { lastError = error }
            if lastError == nil && confirmed() { return }
            wait()
        }
        throw lastError ?? HardwareError.invalid("SMC не подтвердил ручной режим")
    }
}
