import AppKit
import SwiftUI
import Combine
import SystemCore

@main enum STIXSystemApplication {
    @MainActor static func main() {
        if DiagnosticCommands.runIfRequested() { return }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

private final class MonitorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

@MainActor private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusSubscription: AnyCancellable?
    private var item: NSStatusItem?
    private var panel: MonitorPanel?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private lazy var model = MonitorModel()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.item = item
        item.autosaveName = "STIXSystem"
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "waveform.path", accessibilityDescription: "STIX System")
            button.setAccessibilityLabel("STIX System")
            button.toolTip = "STIX System — мониторинг Mac"
            button.target = self; button.action = #selector(toggle)
        }
        statusSubscription = model.$snapshot.combineLatest(model.$hardware, model.preferences.$menuMetric)
            .sink { [weak self] snapshot, hardware, metric in
                self?.updateStatus(metric: metric, snapshot: snapshot, hardware: hardware)
            }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let panel = self?.panel, !panel.frame.contains(NSEvent.mouseLocation) else { return }
                panel.orderOut(nil)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window !== self.panel, event.window !== self.item?.button?.window { self.panel?.orderOut(nil) }
            return event
        }
        show()
        model.preferences.prepare()
    }
    private func updateStatus(metric: MenuMetric, snapshot: SystemSnapshot?, hardware: ThermalReading?) {
        guard let item, let button = item.button else { return }
        if let text = metric.text(cpu: snapshot?.cpu, gpu: snapshot?.gpu, temperature: hardware?.temperature) {
            item.length = NSStatusItem.variableLength
            button.image = nil; button.imagePosition = .noImage
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.title = text
        } else {
            item.length = NSStatusItem.squareLength
            button.title = ""; button.imagePosition = .imageOnly
            button.image = NSImage(systemSymbolName: "waveform.path", accessibilityDescription: "STIX System")
        }
        button.toolTip = "STIX System — \(metric.title)"
        button.setAccessibilityLabel("STIX System — \(button.title.isEmpty ? "мониторинг Mac" : button.title)")
    }
    @objc private func toggle() { if panel?.isVisible == true { panel?.orderOut(nil) } else { show() } }
    private func show() {
        let anchor = item?.button.flatMap { button in button.window?.convertToScreen(button.convert(button.bounds, to: nil)) }
        let screen = NSScreen.screens.first { screen in anchor.map { screen.frame.contains($0.center) } ?? false } ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let maximumFrame = PanelPlacement.frame(content: CGSize(width: 382, height: screen.visibleFrame.height), screen: screen.frame,
                                         visible: screen.visibleFrame, safeTop: screen.safeAreaInsets.top, anchorX: anchor?.midX)
        let frame = PanelPlacement.frame(content: CGSize(width: 382, height: 740), screen: screen.frame,
                                         visible: screen.visibleFrame, safeTop: screen.safeAreaInsets.top, anchorX: anchor?.midX)
        if panel == nil {
            let panel = MonitorPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "STIX System"
            panel.isFloatingPanel = true; panel.level = .floating
            panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = true
            panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            panel.delegate = self
            self.panel = panel
        }
        guard let panel else { return }
        // A bounded scroll container makes even a short secondary display usable.
        panel.contentViewController = NSHostingController(rootView:
            PanelContents(model: model, maximumHeight: maximumFrame.height) { [weak panel] height in
                let fitted = PanelPlacement.frame(content: CGSize(width: 382, height: height), screen: screen.frame,
                    visible: screen.visibleFrame, safeTop: screen.safeAreaInsets.top, anchorX: anchor?.midX)
                panel?.setFrame(fitted, display: true)
            })
        panel.setFrame(frame, display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
private extension CGRect { var center: CGPoint { CGPoint(x: midX, y: midY) } }
