import AppKit
import ServiceManagement
import UserNotifications
import SystemCore

@MainActor enum DiagnosticCommands {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        if args.contains("--service-status") {
            print(SMAppService.daemon(plistName: FanServiceIdentity.plistName).status.rawValue)
            return true
        }
        let preferences = args.contains("--preferences-status")
        let notificationTest = args.contains("--notification-smoke-test")
        let rpmTest = args.contains("--fan-rpm-test")
        let unregister = args.contains("--unregister-fan-service")
        let register = args.contains("--register-fan-service")
        let smoke = args.contains("--fan-smoke-test")
        let lease = args.contains("--fan-lease-test")
        let individual = args.contains("--fan-individual-test")
        guard unregister || register || smoke || lease || individual || preferences || notificationTest || rpmTest else { return false }
        Task {
            try? await Task.sleep(for: .seconds(45))
            fputs("Diagnostic command timed out; any manual lease will expire automatically.\n", stderr)
            exit(1)
        }
        Task { @MainActor in
            do {
                if preferences {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    print("Login item status: \(SMAppService.mainApp.status.rawValue)")
                    print("Notifications authorization: \(settings.authorizationStatus.rawValue)")
                    print("Alerts enabled: \(UserDefaults.standard.object(forKey: "healthAlerts") as? Bool ?? true)")
                    exit(0)
                }
                if notificationTest { try await HealthNotifications().test(); print("PASS notification submitted"); exit(0) }
                let service = SMAppService.daemon(plistName: FanServiceIdentity.plistName)
                if unregister {
                    if service.status == .enabled {
                        let client = FanClient()
                        let error: String? = await withCheckedContinuation { continuation in client.automatic { continuation.resume(returning: $0) } }
                        client.disconnect()
                        if let error { throw HardwareError.invalid("Cannot safely unregister: \(error)") }
                    }
                    try await service.unregister(); print("Unregistered"); exit(0)
                }
                if register {
                    try service.register()
                    print("Service status: \(service.status.rawValue)")
                    if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                    exit(0)
                }
                let client = FanClient()
                defer { client.disconnect() }
                let pingError: String? = await withCheckedContinuation { continuation in client.ping { continuation.resume(returning: $0) } }
                if let pingError { throw HardwareError.invalid(pingError) }
                if rpmTest {
                    let smc = SMC()
                    let fans = smc.snapshot().fans
                    guard !fans.isEmpty else { throw HardwareError.unavailable }
                    for fan in fans {
                        let error: String? = await withCheckedContinuation { continuation in
                            client.manualRPM(fanID: fan.id, rpm: fan.maximum) { continuation.resume(returning: $0) }
                        }
                        if let error { throw HardwareError.invalid(error) }
                    }
                    let state = smc.snapshot()
                    guard state.fans.allSatisfy({ $0.manual == true && abs(($0.target ?? 0) - $0.maximum) < 5 }) else { throw HardwareError.invalid("RPM read-back failed") }
                    print("Exact RPM targets: \(state.fans.map { Int($0.target ?? 0) })")
                    try await Task.sleep(for: .seconds(3))
                    let error: String? = await withCheckedContinuation { continuation in client.automatic { continuation.resume(returning: $0) } }
                    if let error { throw HardwareError.invalid(error) }
                    guard smc.snapshot().fans.allSatisfy({ $0.manual == false }), smc.read("Ftst") == 0 else { throw HardwareError.invalid("Auto after RPM failed") }
                    print("PASS exact RPM and automatic recovery"); exit(0)
                }
                if individual {
                    try await testIndividual(client: client)
                    print("PASS independent fans, partial Auto, renewable lease and full Auto")
                    exit(0)
                }
                let error: String? = await withCheckedContinuation { continuation in
                    client.manual(fraction: 0.65) { continuation.resume(returning: $0) }
                }
                if let error { throw HardwareError.invalid(error) }
                let smc = SMC()
                let before = smc.snapshot()
                print("Manual acknowledged: \(before.fans.map { "fan\($0.id)=\(Int($0.target ?? -1)), manual=\($0.manual == true)" }.joined(separator: ", "))")
                guard before.fans.count > 0, before.fans.allSatisfy({ $0.manual == true }) else {
                    client.disconnect(); throw HardwareError.invalid("Manual read-back failed")
                }
                try await Task.sleep(for: .seconds(lease ? 15 : 6))
                let running = smc.snapshot()
                print("Physical RPM: \(running.fans.map { "fan\($0.id)=\(Int($0.current))" }.joined(separator: ", "))")
                if !lease {
                    let error: String? = await withCheckedContinuation { continuation in client.automatic { continuation.resume(returning: $0) } }
                    if let error { throw HardwareError.invalid(error) }
                }
                let after = smc.snapshot()
                print("After \(lease ? "lease expiry" : "Auto"): \(after.fans.map { "fan\($0.id)=\(Int($0.current)), manual=\($0.manual == true)" }.joined(separator: ", ")), Ftst=\(smc.read("Ftst") ?? -1)")
                guard after.fans.count == before.fans.count, after.fans.allSatisfy({ $0.manual == false }), (smc.read("Ftst") ?? 0) == 0 else {
                    client.disconnect(); throw HardwareError.invalid("Automatic read-back failed")
                }
                print("PASS"); exit(0)
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
        }
        RunLoop.main.run()
        return true
    }
    private static func set(_ client: FanClient, id: Int, level: Double) async throws {
        let error: String? = await withCheckedContinuation { continuation in
            client.manual(fanID: id, fraction: level) { continuation.resume(returning: $0) }
        }
        if let error { throw HardwareError.invalid(error) }
    }
    private static func auto(_ client: FanClient, id: Int) async throws {
        let error: String? = await withCheckedContinuation { continuation in
            client.automatic(fanID: id) { continuation.resume(returning: $0) }
        }
        if let error { throw HardwareError.invalid(error) }
    }
    private static func testIndividual(client: FanClient) async throws {
        let smc = SMC()
        guard smc.snapshot().fans.count == 2 else { throw HardwareError.invalid("This diagnostic expects two fans") }
        try await set(client, id: 0, level: 0.5)
        var state = smc.snapshot()
        guard state.fans[0].manual == true, state.fans[1].manual == false else { throw HardwareError.invalid("Fan 0 isolation failed") }
        print("Fan 0 manual, fan 1 Auto: confirmed")
        try await Task.sleep(for: .seconds(4))
        try await set(client, id: 1, level: 0.8)
        state = smc.snapshot()
        guard state.fans.allSatisfy({ $0.manual == true }) else { throw HardwareError.invalid("Separate target application failed") }
        print("Separate targets: \(state.fans.map { Int($0.target ?? -1) })")
        try await auto(client, id: 0)
        state = smc.snapshot()
        guard state.fans[0].manual == false, state.fans[1].manual == true else { throw HardwareError.invalid("Partial Auto reset the other fan") }
        print("Fan 0 Auto, fan 1 still manual: confirmed")
        for _ in 0..<8 {
            try await Task.sleep(for: .seconds(2))
            let error: String? = await withCheckedContinuation { continuation in client.renew { continuation.resume(returning: $0) } }
            if let error { throw HardwareError.invalid(error) }
        }
        guard smc.snapshot().fans[1].manual == true else { throw HardwareError.invalid("Renewed manual session reverted unexpectedly") }
        print("Manual held for 16 seconds with renewal: confirmed")
        try await auto(client, id: 1)
        state = smc.snapshot()
        guard state.fans.allSatisfy({ $0.manual == false }), (smc.read("Ftst") ?? 0) == 0 else { throw HardwareError.invalid("Full Auto after last fan failed") }
    }

}
