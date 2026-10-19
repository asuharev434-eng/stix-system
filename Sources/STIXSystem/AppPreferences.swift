import AppKit
import Combine
import ServiceManagement
import UserNotifications
import SystemCore

@MainActor final class AppPreferences: ObservableObject {
    @Published var menuMetric = MenuMetric(rawValue: UserDefaults.standard.string(forKey: "menuMetric") ?? "icon") ?? .icon {
        didSet { UserDefaults.standard.set(menuMetric.rawValue, forKey: "menuMetric") }
    }
    @Published var processSort = ProcessSort(rawValue: UserDefaults.standard.string(forKey: "processSort") ?? "memory") ?? .memory {
        didSet { UserDefaults.standard.set(processSort.rawValue, forKey: "processSort") }
    }
    @Published var rpmUnits = UserDefaults.standard.bool(forKey: "rpmUnits") {
        didSet { UserDefaults.standard.set(rpmUnits, forKey: "rpmUnits") }
    }
    @Published var launchAtLogin = false
    @Published var alertsEnabled = UserDefaults.standard.object(forKey: "healthAlerts") as? Bool ?? true
    @Published var notice: String?
    let notifications = HealthNotifications()
    func refresh() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        Task { await notifications.refreshAuthorization() }
    }
    func prepare() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if !UserDefaults.standard.bool(forKey: "preferencesV2Initialized") {
            setLogin(true)
            UserDefaults.standard.set(true, forKey: "preferencesV2Initialized")
        }
        if alertsEnabled { setAlerts(true) }
    }
    func setLogin(_ enabled: Bool) {
        Task { @MainActor in
            do {
                if enabled { if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() } }
                else { try await SMAppService.mainApp.unregister() }
                launchAtLogin = SMAppService.mainApp.status == .enabled
                if SMAppService.mainApp.status == .requiresApproval { notice = "Разреши автозапуск STIX System в настройках macOS" }
            } catch { notice = "Автозапуск: \(error.localizedDescription)" }
        }
    }
    func setAlerts(_ enabled: Bool) {
        alertsEnabled = enabled; UserDefaults.standard.set(enabled, forKey: "healthAlerts")
        notifications.enabled = enabled
        if enabled {
            Task { @MainActor in
                do {
                    let allowed = try await notifications.authorize()
                    if !allowed { notice = "Разреши уведомления STIX System в настройках macOS" }
                    else { notice = nil }
                } catch { notice = "Уведомления: \(error.localizedDescription)" }
            }
        }
    }
}

@MainActor final class HealthNotifications: NSObject, UNUserNotificationCenterDelegate {
    var enabled = false
    private var policy = AlertPolicy()
    private var pending: Set<HealthAlert> = []
    private var allowed = false
    private let center = UNUserNotificationCenter.current()
    override init() { super.init(); center.delegate = self }
    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
    func authorize() async throws -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            allowed = try await center.requestAuthorization(options: [.alert, .sound])
        } else { allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional }
        return allowed
    }
    func evaluate(_ snapshot: SystemSnapshot, hardware: ThermalReading) {
        guard enabled, allowed else { policy = AlertPolicy(); return }
        var active: Set<HealthAlert> = []
        let hot = hardware.temperatures.filter { $0.id == "cpu" || $0.id == "gpu" }.compactMap(\.celsius).max() ?? 0
        if snapshot.thermalState >= 2 || hot >= 95 { active.insert(.heat) }
        if (snapshot.memory?.pressure ?? 0) >= 4 { active.insert(.memory) }
        if let disk = snapshot.disk, disk.free < max(5 * 1024 * 1024 * 1024, disk.total / 50) { active.insert(.disk) }
        let now = ProcessInfo.processInfo.systemUptime
        for kind in policy.evaluate(active: active, now: now) where !pending.contains(kind) {
            pending.insert(kind)
            Task { @MainActor in
                defer { pending.remove(kind) }
                let content = UNMutableNotificationContent()
                content.title = kind.title
                switch kind {
                case .heat: content.body = "Высокая температура держится больше минуты. Проверь нагрузку и охлаждение Mac."
                case .memory: content.body = "Критическое давление памяти держится больше минуты. Проверь процессы по RAM."
                case .disk: content.body = "Свободного места мало уже две минуты. Освободи место на внутреннем диске."
                }
                do {
                    try await center.add(UNNotificationRequest(identifier: "health-\(kind.rawValue)", content: content, trigger: nil))
                    policy.delivered(kind, now: ProcessInfo.processInfo.systemUptime)
                } catch { NSLog("STIX notification delivery failed: %@", error.localizedDescription) }
            }
        }
    }
    func test() async throws {
        guard try await authorize() else { throw HardwareError.invalid("Уведомления запрещены в macOS") }
        let content = UNMutableNotificationContent()
        content.title = "STIX System"
        content.body = "Проверка уведомлений. О длительных проблемах приложение сообщит здесь."
        let identifier = "notification-test-" + UUID().uuidString
        content.threadIdentifier = "stix-diagnostics"
        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(300))
            if await center.deliveredNotifications().contains(where: { $0.request.identifier == identifier }) { return }
        }
        throw HardwareError.invalid("macOS приняла уведомление, но доставка в Центр уведомлений не подтверждена")
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
