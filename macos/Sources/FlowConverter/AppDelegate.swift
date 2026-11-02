import Foundation
import AppKit
import SwiftUI

// MARK: - Welcome Window Controller & View

public final class WelcomeWindowController: NSWindowController {
    public var onDismiss: (() -> Void)?

    public init(onOpenWheel: @escaping (ConversionFanMode) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Flow Converter"
        window.titlebarAppearsTransparent = true
        window.center()
        super.init(window: window)

        let rootView = WelcomeView(
            onOpenWheel: onOpenWheel,
            onDismiss: { [weak self] in
                UserDefaults.standard.set(true, forKey: "hasSeenWelcomeV2")
                self?.close()
                self?.onDismiss?()
            }
        )
        window.contentView = NSHostingView(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct WelcomeView: View {
    var onOpenWheel: (ConversionFanMode) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 8)
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 52))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 0.0, green: 0.898, blue: 1.0), .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text("Welcome to Flow Converter")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("Drag any file in Finder and tap a modifier key to summon the radial wheel, or launch any wheel directly from the menu bar.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 10) {
                shortcutRow(key: "⌥ Option while dragging", title: "Conversion Wheel", subtitle: "46 image, audio, video, document, spreadsheet & archive formats") {
                    onOpenWheel(.conversions)
                }
                shortcutRow(key: "⌘ Command while dragging", title: "File Tools Wheel", subtitle: "27 tools: Compress, Metadata, Adjust, Annotate, Frame, Trim, PDF, QR") {
                    onOpenWheel(.fileTools)
                }
                shortcutRow(key: "⌃ Control while dragging", title: "Quick Actions Wheel", subtitle: "Float Shelf, AirDrop, Copy, Move, Copy Path & Open Terminal") {
                    onOpenWheel(.fileActions)
                }
            }
            .padding(.horizontal, 28)

            HStack(spacing: 12) {
                Button("Allow Home Folder Access…") {
                    FolderAccessStore.shared.requestFolderAccess()
                }
                .buttonStyle(.bordered)

                Button("Get Started") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.898, blue: 1.0))
            }
            .padding(.top, 6)
            Spacer()
        }
        .padding(20)
        .frame(width: 540, height: 420)
    }

    private func shortcutRow(key: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    Text(key)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.2))
                        .cornerRadius(4)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Try") {
                action()
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Menu Bar Controller

public final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let taskStore: ConversionTaskStore
    private var settingsWindowController: SettingsWindowController?
    private var welcomeWindowController: WelcomeWindowController?

    public var onSummonWheel: ((ConversionFanMode) -> Void)?
    public var onNewFloatShelf: (() -> Void)?

    public init(taskStore: ConversionTaskStore) {
        self.taskStore = taskStore
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        rebuildMenu()

        taskStore.onChange = { [weak self] in
            self?.configureButton()
            self?.rebuildMenu()
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        if !taskStore.activeTasks.isEmpty {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Flow Converter is working")
        } else if let customIcon = Bundle.main.image(forResource: NSImage.Name("MenuBarIcon")) {
            let resized = NSImage(size: NSSize(width: 18, height: 18))
            resized.lockFocus()
            customIcon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            resized.unlockFocus()
            resized.isTemplate = true
            button.image = resized
        } else {
            button.image = NSImage(systemSymbolName: "circle.hexagongrid.fill", accessibilityDescription: "Flow Converter is ready")
        }
    }

    public func rebuildMenu() {
        let menu = NSMenu()

        let statusTitle = taskStore.activeTasks.isEmpty
            ? "Flow Converter is ready"
            : "Flow Converter is working (\(taskStore.activeTasks.count) active)…"
        let statusHeader = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusHeader.isEnabled = false
        menu.addItem(statusHeader)

        for task in taskStore.activeTasks {
            let item = NSMenuItem(title: "  • \(task.sourceName) → \(task.targetTitle)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let convItem = NSMenuItem(title: "Summon Conversion Wheel (⌥)…", action: #selector(openConversionWheel), keyEquivalent: "c")
        convItem.target = self
        menu.addItem(convItem)

        let toolsItem = NSMenuItem(title: "Summon File Tools Wheel (⌘)…", action: #selector(openToolsWheel), keyEquivalent: "t")
        toolsItem.target = self
        menu.addItem(toolsItem)

        let actionsItem = NSMenuItem(title: "Summon Quick Actions Wheel (⌃)…", action: #selector(openActionsWheel), keyEquivalent: "a")
        actionsItem.target = self
        menu.addItem(actionsItem)

        let floatItem = NSMenuItem(title: "New Float Shelf…", action: #selector(openNewFloat), keyEquivalent: "f")
        floatItem.target = self
        menu.addItem(floatItem)

        menu.addItem(.separator())

        let welcomeItem = NSMenuItem(title: "Getting Started…", action: #selector(openWelcome), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Flow Converter", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc public func openConversionWheel() {
        onSummonWheel?(.conversions)
    }

    @objc public func openToolsWheel() {
        onSummonWheel?(.fileTools)
    }

    @objc public func openActionsWheel() {
        onSummonWheel?(.fileActions)
    }

    @objc public func openNewFloat() {
        onNewFloatShelf?()
    }

    @objc public func openWelcome() {
        if welcomeWindowController == nil {
            welcomeWindowController = WelcomeWindowController(onOpenWheel: { [weak self] mode in
                self?.onSummonWheel?(mode)
            })
            welcomeWindowController?.onDismiss = { [weak self] in
                self?.welcomeWindowController = nil
            }
        }
        welcomeWindowController?.show()
    }

    @objc public func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
            settingsWindowController?.onDismiss = { [weak self] in
                self?.settingsWindowController = nil
            }
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - AppDelegate & Entry Point

@main
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let taskStore = ConversionTaskStore()
    private var overlayController: ConversionOverlayController!
    private var dragGestureMonitor: DragGestureMonitor!
    private var menuBarController: MenuBarController!
    private var floatingFileControllers: [FloatingFileWindowController] = []
    private var fileToolOptionsControllers: [FileToolOptionsWindowController] = []
    private var qrCodeResultsControllers: [QRCodeResultsWindowController] = []
    private var airDropSharingControllers: [AirDropSharingController] = []

    public static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure only a single instance of FlowConverter runs at a time
        let currentPID = ProcessInfo.processInfo.processIdentifier
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != currentPID {
            if app.bundleIdentifier == "io.flowconverter.app" || app.bundleIdentifier == "io.flowconverter.app" || app.localizedName == "FlowConverter" {
                app.terminate()
            }
        }

        overlayController = ConversionOverlayController()
        overlayController.onDrop = { [weak self] urls, action in
            self?.handleDrop(urls: urls, action: action)
        }

        dragGestureMonitor = DragGestureMonitor(overlayController: overlayController)
        dragGestureMonitor.start()

        menuBarController = MenuBarController(taskStore: taskStore)
        menuBarController.onSummonWheel = { [weak self] mode in
            guard let self = self else { return }
            let centerPoint: NSPoint = {
                if let screen = NSScreen.main {
                    return NSPoint(x: screen.frame.midX, y: screen.frame.midY)
                }
                return NSEvent.mouseLocation
            }()
            self.overlayController.present(at: centerPoint, urls: [], mode: mode)
        }

        menuBarController.onNewFloatShelf = { [weak self] in
            let panel = NSOpenPanel()
            panel.title = "Choose files to Float"
            panel.canChooseFiles = true
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = true
            if panel.runModal() == .OK, !panel.urls.isEmpty {
                self?.presentFloatShelf(urls: panel.urls)
            }
        }

        if !UserDefaults.standard.bool(forKey: "hasSeenWelcomeV2") {
            menuBarController.openWelcome()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            menuBarController.openSettings()
        }
        return true
    }

    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func handleDrop(urls: [URL], action: ConversionFanAction) {
        guard !urls.isEmpty else { return }

        switch action {
        case .convert(let targetFormat):
            UniversalConverter.shared.convertBatch(urls: urls, to: targetFormat, taskStore: taskStore)

        case .convert3MFPrinter(let printer):
            var opts = FileToolOptions()
            opts.target3MFPrinterID = printer.id
            ToolExecutionEngine.shared.execute(tool: .convert3MF, urls: urls, options: opts, taskStore: taskStore)

        case .fileTool(let tool):
            if tool == .readQRCode {
                let qrWC = QRCodeResultsWindowController(urls: urls)
                qrCodeResultsControllers.append(qrWC)
                qrWC.show()
            } else if tool == .muteVideo || tool == .extractArchive || tool == .createArchive || tool == .splitPDF || tool == .mergePDF || tool == .createPDF {
                ToolExecutionEngine.shared.execute(tool: tool, urls: urls, options: FileToolOptions(), taskStore: taskStore)
            } else {
                let toolWC = FileToolOptionsWindowController(urls: urls, tool: tool, taskStore: taskStore)
                fileToolOptionsControllers.append(toolWC)
                toolWC.onDismiss = { [weak self, weak toolWC] in
                    self?.fileToolOptionsControllers.removeAll { $0 === toolWC }
                }
                toolWC.show()
            }

        case .float:
            presentFloatShelf(urls: urls)

        case .airDrop:
            let ctrl = AirDropSharingController(urls: urls)
            airDropSharingControllers.append(ctrl)
            ctrl.onFinish = { [weak self, weak ctrl] in
                self?.airDropSharingControllers.removeAll { $0 === ctrl }
            }
            ctrl.start()

        case .copy:
            FileClipboardController.shared.copyFiles(urls)

        case .copyPath:
            FileClipboardController.shared.copyPaths(urls)

        case .move:
            FileMoveAction.shared.moveFiles(urls)

        case .openTerminal:
            TerminalFileAction.shared.openTerminal(for: urls)
        }
    }

    private func presentFloatShelf(urls: [URL]) {
        let behavior = FlowConverterSettingsModel.shared.floatWheelBehavior
        if behavior == .addToExisting, let existing = floatingFileControllers.last {
            existing.model.addURLs(urls)
            existing.show()
            return
        }
        let wc = FloatingFileWindowController(urls: urls)
        floatingFileControllers.append(wc)
        wc.onDismiss = { [weak self, weak wc] in
            self?.floatingFileControllers.removeAll { $0 === wc }
        }
        wc.show()
    }
}
