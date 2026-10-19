import AppKit
import Combine
import OSLog
import ServiceManagement
import SwiftUI
import SystemCore

private actor MetricsWorker {
    private let sampler = MetricsSampler()
    private let smc = SMC()
    func sample() -> (SystemSnapshot, ThermalReading) { (sampler.sample(), smc.snapshot()) }
}

@MainActor final class MonitorModel: ObservableObject {
    let preferences = AppPreferences()
    @Published var fanRPMs: [Int: Double] = [:]
    @Published var commonRPM: Double?
    @Published var snapshot: SystemSnapshot?
    @Published var hardware: ThermalReading?
    @Published var cpuHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var serviceReady = false
    @Published var needsApproval = false
    @Published var manualFanIDs: Set<Int> = []
    @Published var syncFans = false
    @Published var fanIntensities: [Int: Double] = [:]
    var manual: Bool { !manualFanIDs.isEmpty }
    @Published var intensity = 0.45
    @Published var busy = false
    @Published var message: String?
    private let worker = MetricsWorker()
    private let client = FanClient()
    private let logger = Logger(subsystem: FanServiceIdentity.appIdentifier, category: "monitor")
    private var timer: AnyCancellable?
    private var sampling = false
    private var tick = 0
    private var notification: NSObjectProtocol?
    private var operationID = UUID()
    private var renewing = false
    private var service: SMAppService { SMAppService.daemon(plistName: FanServiceIdentity.plistName) }
    init() {
        sample()
        refreshService()
        timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            self.sample(); self.tick += 1
            if self.manual && !self.busy && !self.renewing {
                self.renewing = true
                self.client.renew { [weak self] error in
                    Task { @MainActor in
                        guard let self else { return }
                        self.renewing = false
                        if let error { self.manualFanIDs = []; self.message = error; self.logger.error("Lease: \(error, privacy: .public)") }
                    }
                }
            }
            if self.tick % 5 == 0 && !self.busy { self.refreshService() }
        }
        notification = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.automatic() }
        }
    }
    private func sample() {
        guard !sampling else { return }
        sampling = true
        Task { [weak self, worker] in
            let (snapshot, hardware) = await worker.sample()
            guard let self else { return }
            self.snapshot = snapshot; self.hardware = hardware; self.sampling = false
            self.preferences.notifications.evaluate(snapshot, hardware: hardware)
            if let cpu = snapshot.cpu { self.cpuHistory.append(cpu); self.cpuHistory = Array(self.cpuHistory.suffix(30)) }
            if let gpu = snapshot.gpu { self.gpuHistory.append(gpu); self.gpuHistory = Array(self.gpuHistory.suffix(30)) }
            else { self.gpuHistory = [] }
        }
    }
    func refreshService() {
        preferences.refresh()
        let status = service.status
        needsApproval = status == .requiresApproval
        guard status == .enabled else { serviceReady = false; return }
        client.ping { [weak self] error in
            Task { @MainActor in self?.serviceReady = error == nil }
        }
    }
    func enableService() {
        do {
            if service.status == .notRegistered || service.status == .notFound { try service.register() }
            needsApproval = service.status == .requiresApproval
            if needsApproval { SMAppService.openSystemSettingsLoginItems() }
            refreshService()
            message = needsApproval ? "Разреши STIX System в фоновых объектах macOS" : nil
        } catch {
            message = "Не удалось включить управление: \(error.localizedDescription)"
            logger.error("Service registration: \(error.localizedDescription, privacy: .public)")
        }
    }
    func applyManual(id: Int? = nil) {
        guard serviceReady, !busy else { return }
        if let reason = manualBlockReason { message = reason; return }
        startOperation()
        let operation = operationID
        let completion: (String?) -> Void = { [weak self] error in
            Task { @MainActor in
                guard let self, self.operationID == operation else { return }
                self.busy = false; self.message = error
                if error == nil {
                    if let id { self.manualFanIDs.insert(id) }
                    else { self.manualFanIDs = Set(self.hardware?.fans.map(\.id) ?? []) }
                }
                self.sample()
            }
        }
        if preferences.rpmUnits { client.manualRPM(fanID: id, rpm: selectedRPM(id), completion: completion) }
        else { client.manual(fanID: id, fraction: id.flatMap { fanIntensities[$0] } ?? intensity, completion: completion) }
    }

    func automatic(id: Int? = nil) {
        guard serviceReady, !busy else { return }
        startOperation()
        let operation = operationID
        client.automatic(fanID: id) { [weak self] error in
            Task { @MainActor in
                guard let self, self.operationID == operation else { return }
                self.busy = false; self.message = error
                if error == nil { if let id { self.manualFanIDs.remove(id) } else { self.manualFanIDs = [] } }
                self.sample()
            }
        }
    }
    private func startOperation() {
        busy = true; message = nil; operationID = UUID()
        let operation = operationID
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, self.busy, self.operationID == operation else { return }
            self.client.disconnect(); self.busy = false; self.manualFanIDs = []
            self.message = "Сервис не ответил. Ручная сессия будет сброшена автоматически."
        }
    }
    func setRPMUnits(_ enabled: Bool) {
        guard enabled != preferences.rpmUnits else { return }
        let ids = (hardware?.fans ?? []).map(\.id)
        if enabled {
            commonRPM = nil
            for id in ids { fanRPMs[id] = nil }
            commonRPM = selectedRPM(nil)
            for id in ids { fanRPMs[id] = selectedRPM(id) }
        } else {
            func fraction(_ rpm: Double, _ range: ClosedRange<Double>) -> Double {
                range.upperBound > range.lowerBound ? (rpm - range.lowerBound) / (range.upperBound - range.lowerBound) : 1
            }
            intensity = fraction(selectedRPM(nil), rpmBounds(nil))
            for id in ids { fanIntensities[id] = fraction(selectedRPM(id), rpmBounds(id)) }
        }
        preferences.rpmUnits = enabled
    }
    func rpmBounds(_ id: Int?) -> ClosedRange<Double> {
        let fans = (hardware?.fans ?? []).filter { id == nil || $0.id == id }
        let lower = 0.0
        let upper = max(lower, fans.map(\.maximum).min() ?? 1)
        return lower...upper
    }
    func selectedRPM(_ id: Int?) -> Double {
        let range = rpmBounds(id)
        let selected = id.flatMap { fanRPMs[$0] } ?? (id == nil ? commonRPM : nil)
        let fraction = id.flatMap { fanIntensities[$0] } ?? intensity
        return min(range.upperBound, max(range.lowerBound, selected ?? (range.lowerBound + fraction * (range.upperBound - range.lowerBound)))).rounded()
    }
    func setSync(_ enabled: Bool) {
        syncFans = enabled
        // Toggling Sync only changes the editing controls. Applying is explicit.
        if !enabled { for fan in hardware?.fans ?? [] { fanIntensities[fan.id] = intensity } }
    }
    func quit() {
        // Disconnect triggers immediate server-side reset; lease is the fallback.
        client.disconnect()
        NSApplication.shared.terminate(nil)
    }
    var manualBlockReason: String? { FanPolicy.blockReason(hardware, thermalState: snapshot?.thermalState ?? 0) }
    var thermalTitle: String {
        if let hardware, FanPolicy.overheated(hardware, thermalState: 0) { return "Высокая температура" }
        if let temperature = hardware?.temperature, temperature >= 90 { return "Температура повышена" }
        switch snapshot?.thermalState {
        case 0: return "Нагрев в норме"
        case 1: return "Повышенный нагрев"
        case 2: return "Ограничение macOS"
        case 3: return "Ограничение macOS"
        default: return "Проверяю состояние"
        }
    }
    var thermalColor: Color {
        if let hardware, FanPolicy.overheated(hardware, thermalState: snapshot?.thermalState ?? 0) { return .red }
        if let temperature = hardware?.temperature, temperature >= 90 { return .orange }
        switch snapshot?.thermalState { case 0: return .green; case 1: return .orange; case 2, 3: return .red; default: return .secondary }
    }
}
