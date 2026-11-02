import Foundation
import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Unlock Store (Always Unlocked — No RevenueCat Paywall)

public final class UnlockStore: ObservableObject {
    public static let shared = UnlockStore()
    @Published public var isUnlocked: Bool = true
    @Published public var usedCount: Int = 0
    @Published public var reservedCount: Int = 0

    public init() {}

    public func canPerformOperation(itemCount: Int = 1) -> Bool {
        return true
    }

    public func recordUsage(count: Int = 1) {
        usedCount += count
    }
}

// MARK: - Login Item Controller

public enum LoginItemState: Equatable {
    case off
    case on
    case needsApproval
    case unavailable
}

public final class LoginItemController: ObservableObject {
    public static let shared = LoginItemController()
    @Published public var state: LoginItemState = .off
    @Published public var error: String?

    public init() {
        refresh()
    }

    public func refresh() {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                state = .on
            case .requiresApproval:
                state = .needsApproval
            case .notRegistered, .notFound:
                state = .off
            @unknown default:
                state = .unavailable
            }
        }
    }

    public func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                error = nil
            } catch {
                self.error = "Couldn’t update launch at login. You can try again, or set it up later in System Settings."
            }
            refresh()
        }
    }
}

// MARK: - Folder Access Store

public final class FolderAccessStore: ObservableObject {
    public static let shared = FolderAccessStore()
    @Published public var folders: [URL] = []
    private let defaultsKey = "folderAccessBookmarks"

    public init() {
        loadBookmarks()
    }

    public func loadBookmarks() {
        guard let datas = UserDefaults.standard.array(forKey: defaultsKey) as? [Data] else { return }
        var resolved: [URL] = []
        for data in datas {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
                _ = url.startAccessingSecurityScopedResource()
                resolved.append(url)
            }
        }
        folders = resolved
    }

    public func requestFolderAccess() {
        let panel = NSOpenPanel()
        panel.title = "Allow Folder Access"
        panel.message = "Flow Converter saves results beside the originals. Choose a parent folder, such as your home folder, to cover every folder inside it."
        panel.prompt = "Allow Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if panel.runModal() == .OK, let url = panel.url {
            addFolder(url)
        }
    }

    public func addFolder(_ url: URL) {
        if !folders.contains(url) {
            folders.append(url)
            saveBookmarks()
        }
    }

    public func removeFolder(_ url: URL) {
        folders.removeAll { $0 == url }
        saveBookmarks()
    }

    private func saveBookmarks() {
        let datas = folders.compactMap { url -> Data? in
            try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(datas, forKey: defaultsKey)
    }
}

// MARK: - Settings Model

public final class FlowConverterSettingsModel: ObservableObject {
    public static let shared = FlowConverterSettingsModel()
    @Published public var selectedSettingsTab: String = "general"

    @Published public var conversionFanTheme: ConversionFanTheme {
        didSet {
            UserDefaults.standard.set(conversionFanTheme.rawValue, forKey: "conversionFanTheme")
            NotificationCenter.default.post(name: Notification.Name("io.flowconverter.conversionFanThemeDidChange"), object: nil)
        }
    }

    @Published public var soundsAndHapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsAndHapticsEnabled, forKey: "soundsAndHapticsEnabled") }
    }

    @Published public var floatWheelBehavior: FloatWheelBehavior {
        didSet { UserDefaults.standard.set(floatWheelBehavior.rawValue, forKey: "floatWheelBehavior") }
    }

    @Published public var selectedDefaultFormat: ConversionFormat = .png {
        didSet { loadDefaultOptions(for: selectedDefaultFormat) }
    }

    @Published public var defaultOptions: ConversionOptions = ConversionOptions() {
        didSet { saveDefaultOptions(for: selectedDefaultFormat) }
    }

    @Published public var imageCompressionOptions: ImageCompressionOptions = ImageCompressionOptions() {
        didSet {
            UserDefaults.standard.set(imageCompressionOptions.strength.rawValue, forKey: "defaultImageCompressionStrength")
            UserDefaults.standard.set(imageCompressionOptions.size.rawValue, forKey: "defaultImageCompressionSize")
        }
    }

    @Published public var videoCompressionOptions: VideoCompressionOptions = VideoCompressionOptions() {
        didSet {
            UserDefaults.standard.set(videoCompressionOptions.strength.rawValue, forKey: "defaultVideoCompressionStrength")
        }
    }

    // Drag Modifier Masks (Option = 524288, Command = 1048576, Control = 262144, Shift = 131072)
    @Published public var conversionDragModifierMask: UInt {
        didSet { UserDefaults.standard.set(Int(conversionDragModifierMask), forKey: "conversionWheelDragModifierMask") }
    }

    @Published public var toolsDragModifierMask: UInt {
        didSet { UserDefaults.standard.set(Int(toolsDragModifierMask), forKey: "toolsWheelDragModifierMask") }
    }

    @Published public var actionsDragModifierMask: UInt {
        didSet { UserDefaults.standard.set(Int(actionsDragModifierMask), forKey: "actionsWheelDragModifierMask") }
    }

    @Published public var terminalApplication: String {
        didSet { UserDefaults.standard.set(terminalApplication, forKey: "fileActionsTerminalApplication") }
    }

    @Published public var printers3D: [Printer3DModel] = [] {
        didSet { savePrinters3D() }
    }

    // Form fields for adding a new 3D printer (avoids @State macro in sandbox)
    @Published public var newPrinterBrand: String = "Anycubic"
    @Published public var selectedPresetModelID: String = "anycubic-kobra-x"
    @Published public var newPrinterName: String = "Anycubic Kobra X"
    @Published public var newPrinterShortName: String = "Kobra X"
    @Published public var newPrinterBedWidth: String = "260"
    @Published public var newPrinterBedDepth: String = "260"
    @Published public var newPrinterBedHeight: String = "260"
    @Published public var newPrinterNozzle: Double = 0.4
    @Published public var newPrinterFlavor: String = "klipper"

    public var wheelPrinters3D: [Printer3DModel] {
        let enabled = printers3D.filter { $0.showInWheel }
        return enabled.isEmpty ? Array(printers3D.prefix(6)) : enabled
    }

    public init() {
        let defaults = UserDefaults.standard
        let themeRaw = defaults.string(forKey: "conversionFanTheme") ?? ConversionFanTheme.glass.rawValue
        self.conversionFanTheme = ConversionFanTheme(rawValue: themeRaw) ?? .glass

        if defaults.object(forKey: "soundsAndHapticsEnabled") == nil {
            self.soundsAndHapticsEnabled = true
        } else {
            self.soundsAndHapticsEnabled = defaults.bool(forKey: "soundsAndHapticsEnabled")
        }

        let floatRaw = defaults.string(forKey: "floatWheelBehavior") ?? FloatWheelBehavior.addToExisting.rawValue
        self.floatWheelBehavior = FloatWheelBehavior(rawValue: floatRaw) ?? .addToExisting

        let convMask = defaults.integer(forKey: "conversionWheelDragModifierMask")
        self.conversionDragModifierMask = convMask != 0 ? UInt(convMask) : NSEvent.ModifierFlags.option.rawValue

        let toolsMask = defaults.integer(forKey: "toolsWheelDragModifierMask")
        self.toolsDragModifierMask = toolsMask != 0 ? UInt(toolsMask) : NSEvent.ModifierFlags.command.rawValue

        let actMask = defaults.integer(forKey: "actionsWheelDragModifierMask")
        self.actionsDragModifierMask = actMask != 0 ? UInt(actMask) : NSEvent.ModifierFlags.control.rawValue

        self.terminalApplication = defaults.string(forKey: "fileActionsTerminalApplication") ?? "com.apple.Terminal"

        if let str = defaults.string(forKey: "defaultImageCompressionStrength"),
           let val = ImageCompressionStrength(rawValue: str) {
            self.imageCompressionOptions.strength = val
        }
        if let str = defaults.string(forKey: "defaultImageCompressionSize"),
           let val = ImageCompressionSize(rawValue: str) {
            self.imageCompressionOptions.size = val
        }
        if let str = defaults.string(forKey: "defaultVideoCompressionStrength"),
           let val = VideoCompressionStrength(rawValue: str) {
            self.videoCompressionOptions.strength = val
        }

        if let data = defaults.data(forKey: "configuredPrinters3DV2"),
           let decoded = try? JSONDecoder().decode([Printer3DModel].self, from: data),
           !decoded.isEmpty {
            self.printers3D = decoded
        } else {
            self.printers3D = Printer3DModel.defaultCatalog
        }

        loadDefaultOptions(for: selectedDefaultFormat)
    }

    private func savePrinters3D() {
        if let data = try? JSONEncoder().encode(printers3D) {
            UserDefaults.standard.set(data, forKey: "configuredPrinters3DV2")
        }
    }

    public func selectManufacturer(_ brand: String) {
        newPrinterBrand = brand
        let models = Printer3DModel.models(forBrand: brand)
        if let first = models.first {
            selectedPresetModelID = first.id
            applyPresetModel(first)
        } else {
            selectedPresetModelID = "custom"
            newPrinterName = ""
            newPrinterShortName = ""
        }
    }

    public func selectPresetModel(id: String) {
        selectedPresetModelID = id
        if id == "custom" {
            newPrinterName = ""
            newPrinterShortName = ""
            return
        }
        if let preset = Printer3DModel.allPresetModels.first(where: { $0.id == id }) {
            applyPresetModel(preset)
        }
    }

    public func applyPresetModel(_ preset: Printer3DModel) {
        newPrinterBrand = preset.brand
        newPrinterName = preset.name
        newPrinterShortName = preset.shortWheelName
        newPrinterBedWidth = "\(preset.bedWidthMM)"
        newPrinterBedDepth = "\(preset.bedDepthMM)"
        newPrinterBedHeight = "\(preset.bedHeightMM)"
        newPrinterNozzle = preset.nozzleDiameterMM
        newPrinterFlavor = preset.gcodeFlavor
    }

    public func addCustomPrinter3D() {
        let trimmedName = newPrinterName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let trimmedBrand = newPrinterBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Custom"
            : newPrinterBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        let short = newPrinterShortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? String(trimmedName.prefix(12))
            : newPrinterShortName.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = max(50, Int(newPrinterBedWidth) ?? 256)
        let d = max(50, Int(newPrinterBedDepth) ?? 256)
        let h = max(50, Int(newPrinterBedHeight) ?? 256)

        if let existingIdx = printers3D.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            printers3D[existingIdx].bedWidthMM = w
            printers3D[existingIdx].bedDepthMM = d
            printers3D[existingIdx].bedHeightMM = h
            printers3D[existingIdx].nozzleDiameterMM = newPrinterNozzle
            printers3D[existingIdx].gcodeFlavor = newPrinterFlavor
            printers3D[existingIdx].shortWheelName = short
            printers3D[existingIdx].showInWheel = true
            let item = printers3D.remove(at: existingIdx)
            printers3D.insert(item, at: 0)
            return
        }

        let printer = Printer3DModel(
            id: selectedPresetModelID != "custom" ? selectedPresetModelID : UUID().uuidString,
            brand: trimmedBrand,
            name: trimmedName,
            shortWheelName: short,
            bedWidthMM: w,
            bedDepthMM: d,
            bedHeightMM: h,
            nozzleDiameterMM: newPrinterNozzle,
            gcodeFlavor: newPrinterFlavor,
            showInWheel: true,
            isCustom: true
        )
        printers3D.insert(printer, at: 0)
    }

    public func removePrinter3D(id: String) {
        printers3D.removeAll { $0.id == id }
    }

    public func resetPrinters3DToDefaults() {
        printers3D = Printer3DModel.defaultCatalog
    }

    public func options(for format: ConversionFormat) -> ConversionOptions {
        let key = "conversionProfile.\(format.rawValue)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ConversionOptions.self, from: data) {
            return decoded
        }
        return ConversionOptions()
    }

    private func loadDefaultOptions(for format: ConversionFormat) {
        defaultOptions = options(for: format)
    }

    private func saveDefaultOptions(for format: ConversionFormat) {
        let key = "conversionProfile.\(format.rawValue)"
        if let data = try? JSONEncoder().encode(defaultOptions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    public func restoreDefaults() {
        defaultOptions = ConversionOptions()
        saveDefaultOptions(for: selectedDefaultFormat)
    }
}

// MARK: - Settings Window Controller & SwiftUI View

public final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    public var onDismiss: (() -> Void)?
    private let model = FlowConverterSettingsModel.shared

    public init() {
        let view = FlowConverterSettingsView(model: model)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flow Converter Settings"
        window.contentViewController = hosting
        window.center()
        window.setFrameAutosaveName("FlowConverterColumnSettingsWindow")
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func windowWillClose(_ notification: Notification) {
        onDismiss?()
    }
}

public struct FlowConverterSettingsView: View {
    @ObservedObject var model: FlowConverterSettingsModel
    @ObservedObject var loginController = LoginItemController.shared
    @ObservedObject var folderStore = FolderAccessStore.shared

    public init(model: FlowConverterSettingsModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedSettingsTab) {
                Label("General", systemImage: "gearshape").tag("general")
                Label("3D Printers (.3MF)", systemImage: "printer.fill").tag("printers3d")
                Label("Wheel Shortcuts", systemImage: "circle.hexagongrid").tag("shortcuts")
                Label("Conversion Defaults", systemImage: "arrow.triangle.2.circlepath").tag("conversions")
                Label("Compression", systemImage: "arrow.down.right.and.arrow.up.left").tag("compression")
                Label("Folders", systemImage: "folder").tag("folders")
                Label("Format Matrix", systemImage: "square.grid.3x3").tag("matrix")
            }
            .listStyle(.sidebar)
            .frame(minWidth: 195)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch model.selectedSettingsTab {
                    case "general":
                        generalSection
                    case "printers3d":
                        printers3DSection
                    case "shortcuts":
                        shortcutsSection
                    case "conversions":
                        conversionDefaultsSection
                    case "compression":
                        compressionSection
                    case "folders":
                        foldersSection
                    case "matrix":
                        formatMatrixSection
                    default:
                        generalSection
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("General Settings").font(.title2.bold())

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Full version unlocked").font(.headline)
                            Text("Unlimited conversions, batch drops, and all 27 media & document tools enabled.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(8)
            }

            Form {
                Picker("Conversion Wheel Theme:", selection: $model.conversionFanTheme) {
                    ForEach(ConversionFanTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }

                Toggle("Sound and haptic feedback", isOn: $model.soundsAndHapticsEnabled)

                Picker("Float Behavior:", selection: $model.floatWheelBehavior) {
                    ForEach(FloatWheelBehavior.allCases) { b in
                        Text(b.title).tag(b)
                    }
                }

                Picker("Terminal Application:", selection: $model.terminalApplication) {
                    Text("Terminal").tag("com.apple.Terminal")
                    Text("iTerm2").tag("com.googlecode.iterm2")
                }

                Toggle("Launch Flow Converter at login", isOn: Binding(
                    get: { loginController.state == .on },
                    set: { loginController.setEnabled($0) }
                ))
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Wheel Shortcuts").font(.title2.bold())
            Text("While dragging files in Finder or any app, tap or hold the modifier key below to summon the corresponding radial wheel at your cursor.")
                .foregroundColor(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    modifierPickerRow(title: "Conversion Wheel:", selection: $model.conversionDragModifierMask)
                    Divider()
                    modifierPickerRow(title: "File Tools Wheel:", selection: $model.toolsDragModifierMask)
                    Divider()
                    modifierPickerRow(title: "Quick Actions Wheel:", selection: $model.actionsDragModifierMask)
                }
                .padding(10)
            }
        }
    }

    private func modifierPickerRow(title: String, selection: Binding<UInt>) -> some View {
        HStack {
            Text(title).frame(width: 160, alignment: .leading)
            Picker("", selection: selection) {
                Text("⌥ Option").tag(NSEvent.ModifierFlags.option.rawValue)
                Text("⌘ Command").tag(NSEvent.ModifierFlags.command.rawValue)
                Text("⌃ Control").tag(NSEvent.ModifierFlags.control.rawValue)
                Text("⇧ Shift").tag(NSEvent.ModifierFlags.shift.rawValue)
            }
            .pickerStyle(.segmented)
        }
    }

    private var conversionDefaultsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Conversion Defaults").font(.title2.bold())
            Text("Conversion defaults are configured on the output format you choose.")
                .foregroundColor(.secondary)

            Picker("Output Format:", selection: $model.selectedDefaultFormat) {
                ForEach(ConversionFormat.allCases) { fmt in
                    Text(fmt.displayName).tag(fmt)
                }
            }
            .frame(maxWidth: 260)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Quality:", selection: $model.defaultOptions.quality) {
                        ForEach(ConversionQuality.allCases) { q in
                            Text(q.title).tag(q)
                        }
                    }
                    Toggle("Preserve metadata", isOn: $model.defaultOptions.preserveMetadata)

                    if model.selectedDefaultFormat.group == .audio {
                        Picker("Audio Sample Depth:", selection: $model.defaultOptions.audioSampleDepth) {
                            ForEach(AudioSampleDepth.allCases) { d in
                                Text(d.title).tag(d)
                            }
                        }
                    }

                    if model.selectedDefaultFormat == .epub {
                        Picker("EPUB Layout:", selection: $model.defaultOptions.epubLayout) {
                            ForEach(EPUBLayout.allCases) { l in
                                Text(l.title).tag(l)
                            }
                        }
                    }

                    if model.selectedDefaultFormat == .docx || model.selectedDefaultFormat == .pages {
                        Picker("PDF to Office Layout:", selection: $model.defaultOptions.pdfOfficeLayout) {
                            ForEach(PDFOfficeLayout.allCases) { l in
                                Text(l.title).tag(l)
                            }
                        }
                    }

                    Button("Restore Defaults") {
                        model.restoreDefaults()
                    }
                }
                .padding(10)
            }
        }
    }

    private var compressionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Compression Settings").font(.title2.bold())

            GroupBox(label: Text("Image Compression").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Strength:", selection: $model.imageCompressionOptions.strength) {
                        ForEach(ImageCompressionStrength.allCases) { s in
                            Text(s.title).tag(s)
                        }
                    }
                    Picker("Max Dimensions:", selection: $model.imageCompressionOptions.size) {
                        ForEach(ImageCompressionSize.allCases) { sz in
                            Text(sz.title).tag(sz)
                        }
                    }
                }
                .padding(10)
            }

            GroupBox(label: Text("Video Compression").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Strength:", selection: $model.videoCompressionOptions.strength) {
                        ForEach(VideoCompressionStrength.allCases) { s in
                            Text(s.title).tag(s)
                        }
                    }
                }
                .padding(10)
            }
        }
    }

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Folder Access").font(.title2.bold())
            Text("Flow Converter saves results beside the originals. Allowing a parent folder, such as your home folder, covers every folder inside it.")
                .foregroundColor(.secondary)

            Button("Allow Folder Access…") {
                folderStore.requestFolderAccess()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.0, green: 0.898, blue: 1.0))

            if folderStore.folders.isEmpty {
                Text("No folders explicitly bookmarked yet (Standard access active).")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(folderStore.folders, id: \.self) { url in
                    HStack {
                        Image(systemName: "folder.fill").foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                        Text(url.path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button(role: .destructive) {
                            folderStore.removeFolder(url)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(6)
                }
            }
        }
    }

    private var formatMatrixSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Supported Formats (\(ConversionFormat.allCases.count) Formats)").font(.title2.bold())
            ForEach(SupportedFormatGroup.allCases) { group in
                let formats = ConversionFormat.allCases.filter { $0.group == group }
                GroupBox(label: Label(group.title, systemImage: group.iconName).font(.headline)) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(formats) { fmt in
                            Text(fmt.displayName)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.14))
                                .cornerRadius(6)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private var printers3DSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("3D Printers (.3MF Converter)").font(.title2.bold())
                    Text("Configure your 3D printer models here. When you drag a .3mf file and open the Conversion Wheel (⌥ Option), all printers checked below appear directly as petals on the wheel for instant 1-drop conversion.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Restore Default Printers") {
                    model.resetPrinters3DToDefaults()
                }
                .controlSize(.small)
            }

            // Add Custom Printer Box
            GroupBox(label: Label("Add New 3D Printer Model", systemImage: "plus.circle.fill").font(.headline)) {
                let brandModels = Printer3DModel.models(forBrand: model.newPrinterBrand)
                VStack(alignment: .leading, spacing: 12) {
                    // Row 1: Manufacturer Picker + Model Picker
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Manufacturer (Fabricante)").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: Binding(
                                get: { model.newPrinterBrand },
                                set: { model.selectManufacturer($0) }
                            )) {
                                ForEach(Printer3DModel.manufacturerList, id: \.self) { brand in
                                    Text(brand).tag(brand)
                                }
                            }
                            .labelsHidden()
                        }
                        .frame(width: 175)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Printer Model (Modelo)").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: Binding(
                                get: { model.selectedPresetModelID },
                                set: { model.selectPresetModel(id: $0) }
                            )) {
                                ForEach(brandModels) { preset in
                                    Text("\(preset.name) (\(preset.bedWidthMM)×\(preset.bedDepthMM)×\(preset.bedHeightMM) mm)")
                                        .tag(preset.id)
                                }
                                Text("Outro / Digitar Manualmente…").tag("custom")
                            }
                            .labelsHidden()
                        }
                    }

                    // Row 2: Editable Slicer Name + Short Wheel Label
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Full Printer Model Name (Slicer ID)").font(.caption).foregroundColor(.secondary)
                            TextField("e.g. Anycubic Kobra X", text: $model.newPrinterName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Wheel Label (Short)").font(.caption).foregroundColor(.secondary)
                            TextField("e.g. Kobra X", text: $model.newPrinterShortName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 150)
                    }

                    // Row 3: Dimensions, Nozzle, Firmware & Add Button
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Width (X mm)").font(.caption).foregroundColor(.secondary)
                            TextField("260", text: $model.newPrinterBedWidth)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 85)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Depth (Y mm)").font(.caption).foregroundColor(.secondary)
                            TextField("260", text: $model.newPrinterBedDepth)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 85)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Height (Z mm)").font(.caption).foregroundColor(.secondary)
                            TextField("260", text: $model.newPrinterBedHeight)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 85)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nozzle").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: $model.newPrinterNozzle) {
                                Text("0.2 mm").tag(0.2)
                                Text("0.4 mm").tag(0.4)
                                Text("0.6 mm").tag(0.6)
                                Text("0.8 mm").tag(0.8)
                            }
                            .labelsHidden()
                        }
                        .frame(width: 90)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Firmware / G-code").font(.caption).foregroundColor(.secondary)
                            Picker("", selection: $model.newPrinterFlavor) {
                                Text("Marlin / Bambu").tag("marlin")
                                Text("Klipper").tag("klipper")
                                Text("RepRap").tag("reprapfirmware")
                            }
                            .labelsHidden()
                        }
                        .frame(width: 125)

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(" ").font(.caption)
                            Button {
                                model.addCustomPrinter3D()
                            } label: {
                                Label("Add to List", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 0.0, green: 0.898, blue: 1.0))
                            .disabled(model.newPrinterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(10)
            }

            // Configured Printers List
            GroupBox(label: Label("Configured 3D Printers (\(model.wheelPrinters3D.count) active on Radial Wheel)", systemImage: "printer.fill").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(model.printers3D.enumerated()), id: \.element.id) { idx, printer in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { model.printers3D[idx].showInWheel },
                                set: { model.printers3D[idx].showInWheel = $0 }
                            ))
                            .labelsHidden()
                            .help("Show this printer on the Radial Wheel when dragging a .3mf file")

                            Image(systemName: "printer.fill")
                                .foregroundColor(printer.showInWheel ? Color(red: 0.0, green: 0.898, blue: 1.0) : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(printer.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(printer.brand)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.16))
                                        .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                                        .cornerRadius(4)
                                    if printer.showInWheel {
                                        Text("Wheel: \"\(printer.shortWheelName)\"")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                                Text("Bed: \(printer.bedWidthMM)×\(printer.bedDepthMM)×\(printer.bedHeightMM) mm · Nozzle: \(String(format: "%.1f", printer.nozzleDiameterMM)) mm · G-code: \(printer.gcodeFlavor)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if idx > 0 {
                                Button {
                                    model.printers3D.swapAt(idx, idx - 1)
                                } label: {
                                    Image(systemName: "arrow.up")
                                }
                                .buttonStyle(.borderless)
                                .help("Move up in wheel order")
                            }

                            if idx < model.printers3D.count - 1 {
                                Button {
                                    model.printers3D.swapAt(idx, idx + 1)
                                } label: {
                                    Image(systemName: "arrow.down")
                                }
                                .buttonStyle(.borderless)
                                .help("Move down in wheel order")
                            }

                            Button(role: .destructive) {
                                model.removePrinter3D(id: printer.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove printer")
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(printer.showInWheel ? Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.06) : Color.clear)
                        .cornerRadius(8)

                        if idx < model.printers3D.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(8)
            }
        }
    }
}
