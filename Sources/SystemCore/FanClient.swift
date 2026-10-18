import Foundation
import Security

@MainActor public final class FanClient {
    private var connection: NSXPCConnection?
    public init() {}
    private func proxy(errorHandler: @escaping (String) -> Void) -> FanServiceProtocol? {
        if connection == nil {
            let connection = NSXPCConnection(machServiceName: FanServiceIdentity.label, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: FanServiceProtocol.self)
            // The helper is bundled and signed independently. Pin its exact code hash.
            let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/HelperTools/STIXFanService")
            var code: SecStaticCode?; var signing: CFDictionary?
            guard SecStaticCodeCreateWithPath(helper as CFURL, [], &code) == errSecSuccess, let code,
                  SecStaticCodeCheckValidity(code, [], nil) == errSecSuccess,
                  SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &signing) == errSecSuccess,
                  let info = signing as? [String: Any], let hash = info[kSecCodeInfoUnique as String] as? Data else {
                errorHandler("Подпись сервиса вентиляторов недействительна"); return nil
            }
            connection.setCodeSigningRequirement("cdhash H\"\(hash.map { String(format: "%02x", $0) }.joined())\"")
            connection.invalidationHandler = { [weak self] in Task { @MainActor in self?.connection = nil } }
            connection.interruptionHandler = { [weak self] in Task { @MainActor in self?.connection?.invalidate(); self?.connection = nil } }
            connection.resume(); self.connection = connection
        }
        return connection?.remoteObjectProxyWithErrorHandler { error in errorHandler(error.localizedDescription) } as? FanServiceProtocol
    }
    public func ping(_ completion: @escaping (String?) -> Void) {
        proxy(errorHandler: completion)?.ping { version in completion(version == "3" ? nil : "Несовместимая версия сервиса") }
    }
    public func manual(fanID: Int? = nil, fraction: Double, completion: @escaping (String?) -> Void) {
        proxy(errorHandler: completion)?.manual(fanID: fanID ?? -1, fraction: fraction, reply: completion)
    }
    public func manualRPM(fanID: Int? = nil, rpm: Double, completion: @escaping (String?) -> Void) {
        proxy(errorHandler: completion)?.manualRPM(fanID: fanID ?? -1, rpm: rpm, reply: completion)
    }
    public func renew(_ completion: @escaping (String?) -> Void) { proxy(errorHandler: completion)?.renew(reply: completion) }
    public func automatic(fanID: Int? = nil, _ completion: @escaping (String?) -> Void) { proxy(errorHandler: completion)?.automatic(fanID: fanID ?? -1, reply: completion) }
    public func disconnect() { connection?.invalidate(); connection = nil }
}
