import Foundation
import AppKit
import SwiftUI

// MARK: - Fan Highlight Sound Player

public final class FanHighlightSoundPlayer {
    public static let shared = FanHighlightSoundPlayer()
    private var sounds: [NSSound] = []
    private var nextSoundIndex: Int = 0
    private var didLoadSounds: Bool = false

    public init() {}

    private func loadIfNeeded() {
        guard !didLoadSounds else { return }
        didLoadSounds = true
        let candidates = [
            Bundle.main.url(forResource: "HighlightSound", withExtension: "wav"),
            Bundle.main.url(forResource: "HighlightSound", withExtension: "mp3")
        ].compactMap { $0 }

        if let url = candidates.first {
            for _ in 0..<4 {
                if let snd = NSSound(contentsOf: url, byReference: false) {
                    snd.volume = 0.65
                    sounds.append(snd)
                }
            }
        }
    }

    public func playHighlight() {
        guard FlowConverterSettingsModel.shared.soundsAndHapticsEnabled else { return }
        loadIfNeeded()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        guard !sounds.isEmpty else {
            NSSound.Pop?.play()
            return
        }
        let sound = sounds[nextSoundIndex % sounds.count]
        nextSoundIndex = (nextSoundIndex + 1) % sounds.count
        sound.stop()
        sound.play()
    }
}

private extension NSSound {
    static var Pop: NSSound? { NSSound(named: NSSound.Name("Pop")) }
}

// MARK: - Native Glass Fan Model & Shapes

public final class NativeGlassFanModel: ObservableObject {
    @Published public var actions: [ConversionFanAction] = []
    @Published public var highlightedSlot: Int? = nil
    @Published public var centerLabelText: String = "Drop to Convert"
    @Published public var centerLabelUsesCompactStyle: Bool = false
    @Published public var isCenterLabelVisible: Bool = true
    @Published public var visualTheme: ConversionFanTheme = FlowConverterSettingsModel.shared.conversionFanTheme
    @Published public var fanMode: ConversionFanMode = .conversions
    @Published public var sourceURLs: [URL] = []
    @Published public var isExpanded: Bool = false

    public init() {}

    public func configure(urls: [URL], mode: ConversionFanMode) {
        self.sourceURLs = urls
        self.fanMode = mode
        self.visualTheme = FlowConverterSettingsModel.shared.conversionFanTheme
        self.highlightedSlot = nil

        switch mode {
        case .conversions:
            if !urls.isEmpty {
                if urls.allSatisfy({ FileTool.is3MFFile($0) }) {
                    let wheelPrinters = Array(FlowConverterSettingsModel.shared.wheelPrinters3D.prefix(11))
                    var printerActions: [ConversionFanAction] = wheelPrinters.map { .convert3MFPrinter($0) }
                    printerActions.append(.fileTool(.convert3MF))
                    self.actions = printerActions
                    self.centerLabelText = "Choose 3D Printer"
                } else if let first = urls.first, let srcFormat = ConversionFormat.detect(from: first) {
                    var common = srcFormat.compatibleOutputFormats()
                    for url in urls.dropFirst() {
                        if let fmt = ConversionFormat.detect(from: url) {
                            let compat = Set(fmt.compatibleOutputFormats())
                            common = common.filter { compat.contains($0) }
                        } else {
                            // Directory or unknown file in multi-selection: can still pack into ZIP
                            common = common.filter { $0 == .zip }
                        }
                    }
                    if common.isEmpty {
                        common = [.zip, .tar, .gzip]
                    }
                    self.actions = Array(common.prefix(12)).map { .convert($0) }
                    self.centerLabelText = urls.count > 1 ? "Convert \(urls.count) items" : "Convert \(srcFormat.displayName)"
                } else {
                    // Folder or generic files: offer archive packing formats (.zip, .tar, .gz)
                    self.actions = [.zip, .tar, .gzip].map { .convert($0) }
                    self.centerLabelText = "Pack into Archive"
                }
            } else {
                self.actions = [.jpg, .png, .webp, .pdf, .mp4, .mp3, .gif, .zip].map { .convert($0) }
                self.centerLabelText = "Drop files to convert"
            }
        case .fileTools:
            let tools = FileTool.compatibleTools(for: urls)
            if tools.isEmpty && urls.isEmpty {
                self.actions = [.compress, .createArchive, .convert3MF, .removeMetadata, .cropImage, .editImage, .annotateImage, .frameImage, .trimVideo, .organizePDF, .readQRCode].map { .fileTool($0) }
                self.centerLabelText = "File Tools"
            } else {
                self.actions = Array(tools.prefix(12)).map { .fileTool($0) }
                self.centerLabelText = self.actions.isEmpty ? "No tools available" : "Choose a Tool"
            }
        case .fileActions:
            self.actions = [.float, .airDrop, .copy, .move, .copyPath, .openTerminal]
            self.centerLabelText = "Quick Actions"
        }
    }
}

public struct NativePetalGlassShape: Shape {
    public var centerAngle: Double // radians
    public var sectorAngle: Double // radians
    public var gapWidth: CGFloat
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat

    public init(centerAngle: Double, sectorAngle: Double, gapWidth: CGFloat = 5, innerRadius: CGFloat = 56, outerRadius: CGFloat = 152) {
        self.centerAngle = centerAngle
        self.sectorAngle = sectorAngle
        self.gapWidth = gapWidth
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let innerGapAngle = Double(gapWidth / max(innerRadius, 1))
        let outerGapAngle = Double(gapWidth / max(outerRadius, 1))

        let startInner = centerAngle - (sectorAngle / 2) + (innerGapAngle / 2)
        let endInner = centerAngle + (sectorAngle / 2) - (innerGapAngle / 2)
        let startOuter = centerAngle - (sectorAngle / 2) + (outerGapAngle / 2)
        let endOuter = centerAngle + (sectorAngle / 2) - (outerGapAngle / 2)

        var path = Path()
        guard endInner > startInner && endOuter > startOuter else { return path }

        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .radians(startInner),
            endAngle: .radians(endInner),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .radians(endOuter),
            endAngle: .radians(startOuter),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

public struct NativeFanDiskShape: Shape {
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addArc(center: center, radius: outerRadius, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: false)
        if innerRadius > 0 {
            path.addArc(center: center, radius: innerRadius, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: true)
        }
        return path
    }
}

// MARK: - SwiftUI Radial Fan View

public struct NativeGlassFanView: View {
    @ObservedObject var model: NativeGlassFanModel
    public var onSelectAction: ((ConversionFanAction) -> Void)?
    public var onModeSwitch: ((ConversionFanMode) -> Void)?

    private let innerRadius: CGFloat = 58
    private let outerRadius: CGFloat = 158
    private let labelRadius: CGFloat = 108

    public init(model: NativeGlassFanModel, onSelectAction: ((ConversionFanAction) -> Void)? = nil, onModeSwitch: ((ConversionFanMode) -> Void)? = nil) {
        self.model = model
        self.onSelectAction = onSelectAction
        self.onModeSwitch = onModeSwitch
    }

    public var body: some View {
        ZStack {
            // Subtle backdrop glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(model.visualTheme == .metallic ? 0.55 : 0.35),
                            Color.black.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 175
                    )
                )
                .frame(width: 350, height: 350)

            // Radial Petals
            let count = max(model.actions.count, 1)
            let sectorAngle = (2.0 * Double.pi) / Double(count)

            ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                let angle = -Double.pi / 2.0 + Double(index) * sectorAngle
                let isHighlighted = model.highlightedSlot == index
                let curOuter = isHighlighted ? outerRadius + 8 : outerRadius

                ZStack {
                    NativePetalGlassShape(
                        centerAngle: angle,
                        sectorAngle: sectorAngle,
                        gapWidth: 6,
                        innerRadius: innerRadius,
                        outerRadius: curOuter
                    )
                    .fill(petalFill(isHighlighted: isHighlighted))
                    .overlay(
                        NativePetalGlassShape(
                            centerAngle: angle,
                            sectorAngle: sectorAngle,
                            gapWidth: 6,
                            innerRadius: innerRadius,
                            outerRadius: curOuter
                        )
                        .stroke(
                            isHighlighted
                                ? Color(red: 1.0, green: 0.45, blue: 0.1)
                                : Color.white.opacity(model.visualTheme == .metallic ? 0.32 : 0.22),
                            lineWidth: isHighlighted ? 2.2 : 1.0
                        )
                    )
                    .shadow(color: isHighlighted ? Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.45) : Color.black.opacity(0.28), radius: isHighlighted ? 12 : 6, x: 0, y: 3)

                    // Petal Label & Optional Icon
                    let labelPos = CGPoint(
                        x: 180 + CGFloat(cos(angle)) * (isHighlighted ? labelRadius + 4 : labelRadius),
                        y: 180 + CGFloat(sin(angle)) * (isHighlighted ? labelRadius + 4 : labelRadius)
                    )

                    VStack(spacing: 3) {
                        if let icon = action.iconName {
                            Image(systemName: icon)
                                .font(.system(size: count > 8 ? 13 : 15, weight: .semibold))
                                .foregroundColor(isHighlighted ? .white : .white.opacity(0.92))
                        }
                        Text(action.label)
                            .font(.system(size: count > 8 ? 10.5 : 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(width: 66)
                    }
                    .position(labelPos)
                }
                .frame(width: 360, height: 360)
                .contentShape(
                    NativePetalGlassShape(
                        centerAngle: angle,
                        sectorAngle: sectorAngle,
                        gapWidth: 4,
                        innerRadius: innerRadius,
                        outerRadius: outerRadius + 10
                    )
                )
                .onTapGesture {
                    onSelectAction?(action)
                }
            }

            // Center Hub Disk
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(NSColor.windowBackgroundColor).opacity(0.92),
                                Color.black.opacity(0.85)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 102, height: 102)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.75), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 2)

                VStack(spacing: 4) {
                    Text(model.fanMode.title.uppercased())
                        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                    Text(activeCenterText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                }
                .frame(width: 94)
            }
            .onTapGesture {
                // Cycle fan mode on clicking center hub when open interactively
                let all = ConversionFanMode.allCases
                if let idx = all.firstIndex(of: model.fanMode) {
                    let next = all[(idx + 1) % all.count]
                    onModeSwitch?(next)
                }
            }
        }
        .frame(width: 360, height: 360)
        .scaleEffect(model.isExpanded ? 1.0 : 0.72)
        .opacity(model.isExpanded ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.76)) {
                model.isExpanded = true
            }
        }
    }

    private var activeCenterText: String {
        if let slot = model.highlightedSlot, slot >= 0, slot < model.actions.count {
            return model.actions[slot].centerDescription
        }
        return model.centerLabelText
    }

    private func petalFill(isHighlighted: Bool) -> AnyShapeStyle {
        if isHighlighted {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.42, blue: 0.05),
                        Color(red: 0.90, green: 0.26, blue: 0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if model.visualTheme == .metallic {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(white: 0.28, opacity: 0.92),
                        Color(white: 0.14, opacity: 0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(white: 0.22, opacity: 0.78),
                        Color(white: 0.10, opacity: 0.84)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

// MARK: - AppKit Drag Receiver View & Panel

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

public final class ConversionOverlayPanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        self.ignoresMouseEvents = false
    }
}

public final class ConversionOverlayView: NSView {
    public let fanModel = NativeGlassFanModel()
    public var onDrop: (([URL], ConversionFanAction) -> Void)?
    public var onDragStateChanged: ((Bool) -> Void)?
    public var onSelectInteractive: ((ConversionFanAction) -> Void)?

    private var hostingView: NSHostingView<NativeGlassFanView>!
    private var trackingArea: NSTrackingArea?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        let rootView = NativeGlassFanView(
            model: fanModel,
            onSelectAction: { [weak self] action in
                self?.onSelectInteractive?(action)
            },
            onModeSwitch: { [weak self] newMode in
                guard let self = self else { return }
                self.fanModel.configure(urls: self.fanModel.sourceURLs, mode: newMode)
            }
        )
        hostingView = PassthroughHostingView(rootView: rootView)
        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        return frame.contains(point) ? self : nil
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        updateHighlight(at: pt)
    }

    public override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dist = hypot(pt.x - center.x, pt.y - center.y)

        // Click on center hub -> switch wheel mode
        if dist < 54 {
            let all = ConversionFanMode.allCases
            if let idx = all.firstIndex(of: fanModel.fanMode) {
                let next = all[(idx + 1) % all.count]
                fanModel.configure(urls: fanModel.sourceURLs, mode: next)
            }
            return
        }

        // Click on a highlighted petal -> trigger interactive action
        updateHighlight(at: pt)
        if let slot = fanModel.highlightedSlot, slot >= 0, slot < fanModel.actions.count {
            onSelectInteractive?(fanModel.actions[slot])
        }
    }

    public override func mouseExited(with event: NSEvent) {
        if fanModel.highlightedSlot != nil {
            fanModel.highlightedSlot = nil
        }
    }

    public func updateHighlightFromScreenPoint(_ screenPoint: NSPoint) {
        guard let win = window else { return }
        let winPt = win.convertPoint(fromScreen: screenPoint)
        let localPt = convert(winPt, from: nil)
        updateHighlight(at: localPt)
    }

    private func updateHighlight(at point: NSPoint) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dyTopDown = (bounds.height - point.y) - center.y
        let dist = hypot(dx, dyTopDown)

        guard dist >= 48 && dist <= 178, !fanModel.actions.isEmpty else {
            if fanModel.highlightedSlot != nil {
                fanModel.highlightedSlot = nil
            }
            return
        }

        let count = fanModel.actions.count
        let sectorAngle = (2.0 * Double.pi) / Double(count)
        let angle = atan2(Double(dyTopDown), Double(dx))
        let startRef = -Double.pi / 2.0 - sectorAngle / 2.0
        var rel = angle - startRef
        while rel < 0 { rel += 2.0 * Double.pi }
        while rel >= 2.0 * Double.pi { rel -= 2.0 * Double.pi }

        let slot = Int(floor(rel / sectorAngle)) % count
        if fanModel.highlightedSlot != slot {
            fanModel.highlightedSlot = slot
            FanHighlightSoundPlayer.shared.playHighlight()
        }
    }

    // MARK: - NSDraggingDestination

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragStateChanged?(true)
        let urls = extractURLs(from: sender.draggingPasteboard)
        if !urls.isEmpty && fanModel.sourceURLs != urls {
            fanModel.configure(urls: urls, mode: fanModel.fanMode)
        }
        let pt = convert(sender.draggingLocation, from: nil)
        updateHighlight(at: pt)
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = extractURLs(from: sender.draggingPasteboard)
        if !urls.isEmpty && fanModel.sourceURLs.isEmpty {
            fanModel.configure(urls: urls, mode: fanModel.fanMode)
        }
        let pt = convert(sender.draggingLocation, from: nil)
        updateHighlight(at: pt)
        return fanModel.highlightedSlot != nil ? .copy : .generic
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        fanModel.highlightedSlot = nil
        onDragStateChanged?(false)
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pt = convert(sender.draggingLocation, from: nil)
        updateHighlight(at: pt)
        return fanModel.highlightedSlot != nil
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pt = convert(sender.draggingLocation, from: nil)
        updateHighlight(at: pt)
        guard let slot = fanModel.highlightedSlot,
              slot >= 0, slot < fanModel.actions.count else {
            return false
        }
        var urls = extractURLs(from: sender.draggingPasteboard)
        if urls.isEmpty {
            urls = fanModel.sourceURLs
        }
        guard !urls.isEmpty else { return false }
        let chosenAction = fanModel.actions[slot]
        onDrop?(urls, chosenAction)
        return true
    }

    private func extractURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let items = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !items.isEmpty {
            return items
        }
        if let filenames = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            return filenames.map { URL(fileURLWithPath: $0) }
        }
        return []
    }
}

// MARK: - Conversion Overlay Controller

public final class ConversionOverlayController {
    public var onDrop: (([URL], ConversionFanAction) -> Void)?
    public var onDismiss: (() -> Void)?
    public private(set) var isDragInside: Bool = false

    private let panel: ConversionOverlayPanel
    private let overlayView: ConversionOverlayView
    private var didTriggerDropInCurrentSession: Bool = false

    public var isVisible: Bool { panel.isVisible }
    public var fanMode: ConversionFanMode {
        get { overlayView.fanModel.fanMode }
        set { overlayView.fanModel.configure(urls: overlayView.fanModel.sourceURLs, mode: newValue) }
    }

    public init() {
        let rect = NSRect(x: 0, y: 0, width: 360, height: 360)
        self.panel = ConversionOverlayPanel(contentRect: rect)
        self.overlayView = ConversionOverlayView(frame: rect)
        self.panel.contentView = overlayView

        overlayView.onDragStateChanged = { [weak self] inside in
            self?.isDragInside = inside
        }

        overlayView.onDrop = { [weak self] urls, action in
            guard let self = self, !self.didTriggerDropInCurrentSession else { return }
            self.didTriggerDropInCurrentSession = true
            self.dismiss()
            self.onDrop?(urls, action)
        }

        overlayView.onSelectInteractive = { [weak self] action in
            guard let self = self else { return }
            let urls = self.overlayView.fanModel.sourceURLs
            if !urls.isEmpty {
                self.dismiss()
                self.onDrop?(urls, action)
            } else {
                self.pickFilesAndExecute(action: action)
            }
        }
    }

    public func present(at screenPoint: NSPoint, urls: [URL], mode: ConversionFanMode) {
        didTriggerDropInCurrentSession = false
        overlayView.fanModel.isExpanded = false
        overlayView.fanModel.configure(urls: urls, mode: mode)
        let origin = NSPoint(x: screenPoint.x - 180, y: screenPoint.y - 180)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                self.overlayView.fanModel.isExpanded = true
            }
        }
    }

    public func updateCursorWhileDragging(at screenPoint: NSPoint, urls: [URL]) {
        guard panel.isVisible else { return }
        if !urls.isEmpty && overlayView.fanModel.sourceURLs != urls {
            overlayView.fanModel.configure(urls: urls, mode: overlayView.fanModel.fanMode)
        }
        overlayView.updateHighlightFromScreenPoint(screenPoint)
    }

    public func commitDropIfHighlighted(fallbackURLs: [URL]) -> Bool {
        guard panel.isVisible, !didTriggerDropInCurrentSession else { return false }
        overlayView.updateHighlightFromScreenPoint(NSEvent.mouseLocation)
        guard let slot = overlayView.fanModel.highlightedSlot,
              slot >= 0, slot < overlayView.fanModel.actions.count else {
            return false
        }
        let urls = !overlayView.fanModel.sourceURLs.isEmpty ? overlayView.fanModel.sourceURLs : fallbackURLs
        guard !urls.isEmpty else { return false }
        let action = overlayView.fanModel.actions[slot]
        didTriggerDropInCurrentSession = true
        dismiss()
        onDrop?(urls, action)
        return true
    }

    public func dismiss() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        isDragInside = false
        onDismiss?()
    }

    private func pickFilesAndExecute(action: ConversionFanAction) {
        dismiss()
        let openPanel = NSOpenPanel()
        openPanel.title = "Choose Files for \(action.label)"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = true
        if openPanel.runModal() == .OK, !openPanel.urls.isEmpty {
            onDrop?(openPanel.urls, action)
        }
    }
}

// MARK: - Drag Gesture Monitor

public final class DragGestureMonitor {
    public weak var overlayController: ConversionOverlayController?
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var timer: Timer?
    private var pasteboardChangeCountBeforeMouseDown: Int = 0
    private var wasPrimaryButtonDown: Bool = false
    private var previousModifiers: NSEvent.ModifierFlags = []
    private var cachedDraggedURLs: [URL] = []

    public init(overlayController: ConversionOverlayController) {
        self.overlayController = overlayController
    }

    public func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { [weak self] _ in
            self?.poll()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let buttons = NSEvent.pressedMouseButtons
        let isPrimaryDown = (buttons & 1) != 0
        let modifiers = NSEvent.modifierFlags.intersection([.option, .command, .control, .shift])
        let mouseLoc = NSEvent.mouseLocation

        if isPrimaryDown && !wasPrimaryButtonDown {
            pasteboardChangeCountBeforeMouseDown = dragPasteboard.changeCount
            cachedDraggedURLs = []
        }

        if isPrimaryDown {
            let currentURLs = readDraggedURLs()
            if !currentURLs.isEmpty {
                cachedDraggedURLs = currentURLs
            }

            // Continuously update petal highlight while the wheel is open during a drag!
            if let overlay = overlayController, overlay.isVisible {
                overlay.updateCursorWhileDragging(at: mouseLoc, urls: cachedDraggedURLs)
            }

            let currentChangeCount = dragPasteboard.changeCount
            let isDraggingSession = currentChangeCount != pasteboardChangeCountBeforeMouseDown || !cachedDraggedURLs.isEmpty

            if isDraggingSession, modifiers != previousModifiers, !modifiers.isEmpty {
                let settings = FlowConverterSettingsModel.shared
                let rawMask = modifiers.rawValue
                var targetMode: ConversionFanMode? = nil

                if (rawMask & settings.conversionDragModifierMask) != 0 {
                    targetMode = .conversions
                } else if (rawMask & settings.toolsDragModifierMask) != 0 {
                    targetMode = .fileTools
                } else if (rawMask & settings.actionsDragModifierMask) != 0 {
                    targetMode = .fileActions
                }

                if let mode = targetMode, let overlay = overlayController {
                    if overlay.isVisible && overlay.fanMode == mode {
                        overlay.dismiss()
                    } else {
                        overlay.present(at: mouseLoc, urls: cachedDraggedURLs, mode: mode)
                    }
                }
            }
        }

        if !isPrimaryDown && wasPrimaryButtonDown {
            if let overlay = overlayController, overlay.isVisible {
                let urlsToUse = !cachedDraggedURLs.isEmpty ? cachedDraggedURLs : readDraggedURLs()
                let committed = overlay.commitDropIfHighlighted(fallbackURLs: urlsToUse)
                if !committed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        if NSEvent.pressedMouseButtons == 0 {
                            overlay.dismiss()
                        }
                    }
                }
            }
            cachedDraggedURLs = []
        }

        wasPrimaryButtonDown = isPrimaryDown
        previousModifiers = modifiers
    }

    private func readDraggedURLs() -> [URL] {
        if let urls = dragPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            return urls
        }
        if let filenames = dragPasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            return filenames.map { URL(fileURLWithPath: $0) }
        }
        return []
    }
}
