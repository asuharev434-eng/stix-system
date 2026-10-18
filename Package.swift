// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "STIXSystem", platforms: [.macOS(.v14)],
    products: [.executable(name: "STIXSystem", targets: ["STIXSystem"]), .executable(name: "STIXFanService", targets: ["STIXFanService"]), .executable(name: "stix-diagnostics", targets: ["Diagnostics"])],
    targets: [
        .target(name: "SMCBridge", publicHeadersPath: "include", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "SystemCore", dependencies: ["SMCBridge"], linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("Security")]),
        .executableTarget(name: "STIXSystem", dependencies: ["SystemCore"], linkerSettings: [.linkedFramework("ServiceManagement")]),
        .executableTarget(name: "STIXFanService", dependencies: ["SystemCore"]),
        .executableTarget(name: "Diagnostics", dependencies: ["SystemCore"]),
        .testTarget(name: "SystemCoreTests", dependencies: ["SystemCore"])
    ], swiftLanguageModes: [.v5]
)
