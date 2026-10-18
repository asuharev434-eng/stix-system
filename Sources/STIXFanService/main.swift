import Foundation
import Security
import IOKit.pwr_mgt
import SMCBridge
import SystemCore
import OSLog

private let logger = Logger(subsystem: FanServiceIdentity.label, category: "service")
private let queue = DispatchQueue(label: "ru.stix.system.fan-hardware", qos: .userInitiated)
private let journal = URL(fileURLWithPath: "/var/run/ru.stix.system.fans.active")
private let controller = FanController(hardware: SMC(), recoveryNeeded: FileManager.default.fileExists(atPath: journal.path),
    markActive: {
        try Data("manual\n".utf8).write(to: journal, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: journal.path)
    }, markInactive: {
        if FileManager.default.fileExists(atPath: journal.path) { try FileManager.default.removeItem(at: journal) }
    })

private final class Session: NSObject, FanServiceProtocol {
    let id = UUID().uuidString
    func ping(reply: @escaping (String) -> Void) { reply("3") }
    private func perform(_ reply: @escaping (String?) -> Void, _ work: @escaping () throws -> Void) {
        queue.async {
            do { try work(); reply(nil) }
            catch { logger.error("Fan operation: \(error.localizedDescription, privacy: .public)"); reply(error.localizedDescription) }
        }
    }
    func manual(fanID: Int, fraction: Double, reply: @escaping (String?) -> Void) {
        perform(reply) {
            guard (-1..<10).contains(fanID) else { throw HardwareError.invalid("Некорректный вентилятор") }
            try controller.manual(fraction: fraction, owner: self.id, fanID: fanID == -1 ? nil : fanID)
            logger.notice("Manual fan=\(fanID), intensity=\(fraction), session=\(self.id, privacy: .public)")
        }
    }
    func manualRPM(fanID: Int, rpm: Double, reply: @escaping (String?) -> Void) {
        perform(reply) {
            guard (-1..<10).contains(fanID) else { throw HardwareError.invalid("Некорректный вентилятор") }
            try controller.manualRPM(rpm: rpm, owner: self.id, fanID: fanID == -1 ? nil : fanID)
            logger.notice("Manual fan=\(fanID), rpm=\(rpm)")
        }
    }
    func renew(reply: @escaping (String?) -> Void) { perform(reply) { try controller.renew(owner: self.id) } }
    func automatic(fanID: Int, reply: @escaping (String?) -> Void) {
        perform(reply) {
            guard (-1..<10).contains(fanID) else { throw HardwareError.invalid("Некорректный вентилятор") }
            if fanID == -1 { try controller.restore() }
            else { try controller.automatic(fanID: fanID, owner: self.id) }
            logger.notice("Automatic fan=\(fanID), session=\(self.id, privacy: .public)")
        }
    }
}

private final class Listener: NSObject, NSXPCListenerDelegate {
    private let requirement: String
    private let appOwner: uid_t
    init(app: URL) throws {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else {
            throw HardwareError.invalid("Invalid containing application signature")
        }
        var signing: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &signing) == errSecSuccess,
              let info = signing as? [String: Any], let identifier = info[kSecCodeInfoIdentifier as String] as? String,
              identifier == FanServiceIdentity.appIdentifier,
              let hash = info[kSecCodeInfoUnique as String] as? Data else { throw HardwareError.invalid("Invalid application identity") }
        // Pin the exact installed app build, including ad-hoc builds. The OS applies this
        // requirement to every incoming XPC message using the sender's audit identity.
        requirement = "identifier \"\(identifier)\" and cdhash H\"\(hash.map { String(format: "%02x", $0) }.joined())\""
        let attrs = try FileManager.default.attributesOfItem(atPath: app.path)
        guard let owner = attrs[.ownerAccountID] as? NSNumber else { throw HardwareError.invalid("Missing app owner") }
        appOwner = owner.uint32Value
        super.init()
    }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == appOwner, appOwner != 0 else { return false }
        connection.setCodeSigningRequirement(requirement)
        let session = Session()
        connection.exportedInterface = NSXPCInterface(with: FanServiceProtocol.self)
        connection.exportedObject = session
        connection.invalidationHandler = {
            queue.async {
                do { try controller.release(owner: session.id); logger.notice("Client disconnected; recovery checked") }
                catch { logger.fault("Disconnect recovery failed: \(error.localizedDescription, privacy: .public)") }
            }
        }
        connection.interruptionHandler = connection.invalidationHandler
        connection.resume()
        return true
    }
}

// Sleep notifications arrive before suspension; acknowledge only after restoring Auto.
private var powerConnection: io_connect_t = 0
private var powerPort: IONotificationPortRef?
private var powerNotifier: io_object_t = 0
private let powerCallback: IOServiceInterestCallback = { _, _, message, argument in
    if message == stix_power_will_sleep_message() {
        queue.sync {
            do { try controller.restore() }
            catch { logger.fault("Sleep recovery: \(error.localizedDescription, privacy: .public)") }
        }
        IOAllowPowerChange(powerConnection, Int(bitPattern: argument))
    } else if message == stix_power_can_sleep_message() {
        IOAllowPowerChange(powerConnection, Int(bitPattern: argument))
    }
}

guard geteuid() == 0 else {
    fputs("STIXFanService must be launched by the system service manager.\n", stderr)
    exit(1)
}
var executablePath = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
guard proc_pidpath(getpid(), &executablePath, UInt32(executablePath.count)) > 0 else {
    logger.fault("Cannot resolve service executable path"); exit(1)
}
let appURL = URL(fileURLWithPath: String(cString: executablePath)).resolvingSymlinksInPath()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
do {
    let delegate = try Listener(app: appURL)
    let listener = NSXPCListener(machServiceName: FanServiceIdentity.label)
    listener.delegate = delegate
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: 1)
    timer.setEventHandler {
        do {
            let wasActive = controller.active
            try controller.tick()
            if wasActive && !controller.active { logger.notice("Safety timer/thermal state restored automatic mode") }
        }
        catch { logger.fault("Automatic recovery retry: \(error.localizedDescription, privacy: .public)") }
    }
    timer.resume()
    signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN)
    let termination = DispatchSource.makeSignalSource(signal: SIGTERM, queue: queue)
    termination.setEventHandler {
        do { try controller.restore(); exit(0) }
        catch { logger.fault("Termination recovery failed: \(error.localizedDescription, privacy: .public)"); exit(1) }
    }
    termination.resume()
    powerConnection = IORegisterForSystemPower(nil, &powerPort, powerCallback, &powerNotifier)
    guard powerConnection != 0, let powerPort else { throw HardwareError.invalid("Cannot register sleep safety handler") }
    CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(powerPort).takeUnretainedValue(), .defaultMode)
    listener.resume()
    logger.notice("Fan service started")
    withExtendedLifetime((delegate, listener, timer, termination)) { CFRunLoopRun() }
} catch {
    logger.fault("Service startup: \(error.localizedDescription, privacy: .public)")
    exit(1)
}
