import Foundation
import AppKit
import SwiftUI
import QuickLookUI
import QuickLookThumbnailing

// MARK: - Quick Actions (AirDrop, Clipboard, Move, Terminal)

public final class AirDropSharingController: NSObject, NSSharingServiceDelegate {
    public var onFinish: (() -> Void)?
    private let sourceURLs: [URL]
    private var service: NSSharingService?

    public init(urls: [URL]) {
        self.sourceURLs = urls
        super.init()
    }

    public func start() {
        guard let airDrop = NSSharingService(named: .sendViaAirDrop),
              airDrop.canPerform(withItems: sourceURLs) else {
            let alert = NSAlert()
            alert.messageText = "Couldn’t AirDrop files"
            alert.informativeText = "AirDrop isn’t available for these files on this Mac."
            alert.runModal()
            onFinish?()
            return
        }
        self.service = airDrop
        airDrop.delegate = self
        airDrop.perform(withItems: sourceURLs)
    }

    public func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        onFinish?()
    }

    public func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        onFinish?()
    }
}

public final class FileClipboardController {
    public static let shared = FileClipboardController()

    public init() {}

    public func copyFiles(_ urls: [URL]) {
        let localURLs = urls.filter { $0.isFileURL }
        guard !localURLs.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(localURLs as [NSURL])
    }

    public func copyPaths(_ urls: [URL]) {
        let paths = urls.filter { $0.isFileURL }.map { $0.path }.joined(separator: "\n")
        guard !paths.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(paths, forType: .string)
    }
}

public final class FileMoveAction {
    public static let shared = FileMoveAction()

    public init() {}

    public func moveFiles(_ urls: [URL]) {
        let localURLs = urls.filter { $0.isFileURL }
        guard !localURLs.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose a destination folder"
        panel.prompt = "Move Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let destDir = panel.url else { return }

        var movedURLs: [URL] = []
        for src in localURLs {
            let dst = UniqueOutputURL.make(in: destDir, baseName: src.deletingPathExtension().lastPathComponent, ext: src.pathExtension)
            do {
                try FileManager.default.moveItem(at: src, to: dst)
                movedURLs.append(dst)
            } catch {
                // Keep going if one fails
            }
        }
        if !movedURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(movedURLs)
        }
    }
}

public final class TerminalFileAction {
    public static let shared = TerminalFileAction()

    public init() {}

    public func openTerminal(for urls: [URL]) {
        guard let first = urls.first, first.isFileURL else { return }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir)
        let folderURL = isDir.boolValue ? first : first.deletingLastPathComponent()

        let bundleID = FlowConverterSettingsModel.shared.terminalApplication
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: config, completionHandler: nil)
        } else if let fallbackURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open([folderURL], withApplicationAt: fallbackURL, configuration: config, completionHandler: nil)
        }
    }
}

// MARK: - Floating Shelf ("Float") Models

public enum FloatingTabEdge: String, CaseIterable, Hashable {
    case top, right, bottom, left
}

public enum FloatingTabViewMode: String, CaseIterable, Hashable {
    case icons, list
}

public enum FloatingTabPresentation: String, CaseIterable, Hashable {
    case compact, expanded
}

public final class FloatingFileItem: Identifiable, ObservableObject {
    public let id = UUID()
    public let url: URL
    @Published public var thumbnail: NSImage?

    public init(url: URL) {
        self.url = url
        self.thumbnail = NSWorkspace.shared.icon(forFile: url.path)
        loadHighResThumbnail()
    }

    private func loadHighResThumbnail() {
        let req = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 128, height: 128),
            scale: NSScreen.main?.backingScaleFactor ?? 2.0,
            representationTypes: .all
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] rep, _ in
            if let img = rep?.nsImage {
                DispatchQueue.main.async {
                    self?.thumbnail = img
                }
            }
        }
    }
}

public final class FloatingFileGroupModel: ObservableObject, Identifiable {
    public let id = UUID()
    @Published public var items: [FloatingFileItem] = []
    @Published public var selectedItemIDs: Set<UUID> = []
    @Published public var presentation: FloatingTabPresentation = .expanded
    @Published public var viewMode: FloatingTabViewMode = .icons
    @Published public var attachedEdge: FloatingTabEdge? = nil

    public init(urls: [URL]) {
        addURLs(urls)
    }

    public func addURLs(_ urls: [URL]) {
        let existingPaths = Set(items.map { $0.url.path })
        for url in urls where url.isFileURL && !existingPaths.contains(url.path) {
            items.append(FloatingFileItem(url: url))
        }
        if let first = items.first, selectedItemIDs.isEmpty {
            selectedItemIDs.insert(first.id)
        }
    }

    public func removeItem(_ item: FloatingFileItem) {
        items.removeAll { $0.id == item.id }
        selectedItemIDs.remove(item.id)
    }

    public var selectedURLs: [URL] {
        let selected = items.filter { selectedItemIDs.contains($0.id) }.map { $0.url }
        return selected.isEmpty ? items.map { $0.url } : selected
    }
}

// MARK: - QuickLook Helper

public final class FloatingQuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    public static let shared = FloatingQuickLookController()
    public var urls: [URL] = []

    public func togglePreview(for urls: [URL]) {
        self.urls = urls
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return urls.count
    }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index >= 0 && index < urls.count else { return nil }
        return urls[index] as NSURL
    }
}

// MARK: - Floating Shelf Window & Views

public final class FloatingFilePanel: NSPanel {
    public var keyDownHandler: ((NSEvent) -> Bool)?

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
        self.hasShadow = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
    }

    public override func keyDown(with event: NSEvent) {
        if let handler = keyDownHandler, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
}

public final class FloatingFileWindowController: NSWindowController {
    public let model: FloatingFileGroupModel
    public var onDismiss: (() -> Void)?

    public init(urls: [URL]) {
        self.model = FloatingFileGroupModel(urls: urls)
        let rect = NSRect(x: 120, y: 240, width: 280, height: 320)
        let panel = FloatingFilePanel(contentRect: rect)
        super.init(window: panel)

        let rootView = FloatingFilePanelContentView(
            model: model,
            onClose: { [weak self] in
                self?.closeShelf()
            },
            onToggleExpand: { [weak self] in
                self?.toggleExpand()
            }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = rect
        panel.contentView = hosting

        panel.keyDownHandler = { [weak self] event in
            guard let self = self else { return false }
            if event.keyCode == 49 { // Space -> QuickLook
                FloatingQuickLookController.shared.togglePreview(for: self.model.selectedURLs)
                return true
            }
            return false
        }

        // Position near cursor or right edge of screen
        if let screen = NSScreen.main {
            let mouse = NSEvent.mouseLocation
            let x = min(max(mouse.x - 140, screen.visibleFrame.minX + 16), screen.visibleFrame.maxX - 296)
            let y = min(max(mouse.y - 160, screen.visibleFrame.minY + 16), screen.visibleFrame.maxY - 336)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        window?.orderFrontRegardless()
    }

    public func closeShelf() {
        window?.orderOut(nil)
        onDismiss?()
    }

    public func toggleExpand() {
        guard let panel = window else { return }
        if model.presentation == .expanded {
            model.presentation = .compact
            var frame = panel.frame
            frame.size = NSSize(width: 96, height: 112)
            panel.setFrame(frame, display: true, animate: true)
        } else {
            model.presentation = .expanded
            var frame = panel.frame
            frame.size = NSSize(width: 280, height: 320)
            panel.setFrame(frame, display: true, animate: true)
        }
    }
}

public struct FloatingFilePanelContentView: View {
    @ObservedObject var model: FloatingFileGroupModel
    var onClose: () -> Void
    var onToggleExpand: () -> Void

    public var body: some View {
        ZStack(alignment: .top) {
            if model.presentation == .compact {
                compactView
            } else {
                expandedView
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private var compactView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.flowAccentLight.opacity(0.65), lineWidth: 1.5)
                )

            VStack(spacing: 4) {
                ZStack {
                    if let clipImg = Bundle.main.image(forResource: NSImage.Name("FloatPaperClip")) {
                        Image(nsImage: clipImg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "paperclip")
                            .font(.title2.bold())
                            .foregroundColor(Color.flowAccentLight)
                    }
                }
                Text("\(model.items.count) \(model.items.count == 1 ? "file" : "files")")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
        }
        .frame(width: 92, height: 104)
        .onTapGesture {
            onToggleExpand()
        }
    }

    private var expandedView: some View {
        VStack(spacing: 0) {
            // Header bar with paperclip graphic & controls
            HStack(spacing: 8) {
                if let clipImg = Bundle.main.image(forResource: NSImage.Name("FloatPaperClip")) {
                    Image(nsImage: clipImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "paperclip")
                        .foregroundColor(Color.flowAccentLight)
                        .font(.system(size: 14, weight: .bold))
                }

                Text("Float (\(model.items.count))")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))

                Spacer()

                Button {
                    model.viewMode = (model.viewMode == .icons) ? .list : .icons
                } label: {
                    Image(systemName: model.viewMode == .icons ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Toggle view mode")

                Button {
                    FloatingQuickLookController.shared.togglePreview(for: model.selectedURLs)
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .help("Quick Look (Space)")

                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Collapse Float")

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Close Float without deleting files")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            Divider()

            // File Items
            ScrollView {
                if model.viewMode == .icons {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 10) {
                        ForEach(model.items) { item in
                            FloatingGridItemView(item: item, model: model)
                        }
                    }
                    .padding(12)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(model.items) { item in
                            FloatingListItemView(item: item, model: model)
                        }
                    }
                    .padding(10)
                }
            }

            Divider()

            // Footer Bar: Drag All or Clear
            HStack {
                Text("Drag items out or drop more here")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Copy All") {
                    FileClipboardController.shared.copyFiles(model.items.map { $0.url })
                }
                .controlSize(.mini)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 280, height: 320)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        model.addURLs([url])
                    }
                }
            }
        }
        return true
    }
}

private struct FloatingGridItemView: View {
    @ObservedObject var item: FloatingFileItem
    @ObservedObject var model: FloatingFileGroupModel

    var isSelected: Bool { model.selectedItemIDs.contains(item.id) }

    var body: some View {
        VStack(spacing: 4) {
            if let img = item.thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .cornerRadius(6)
            }
            Text(item.url.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 26)
        }
        .padding(6)
        .frame(width: 76)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.flowAccent.opacity(0.45) : Color.clear)
        )
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                model.selectedItemIDs = [item.id]
            }
        )
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Button("Quick Look") { FloatingQuickLookController.shared.togglePreview(for: [item.url]) }
            Divider()
            Button("Copy File") { FileClipboardController.shared.copyFiles([item.url]) }
            Button("Copy Path") { FileClipboardController.shared.copyPaths([item.url]) }
            Divider()
            Button("Remove from Float", role: .destructive) {
                model.removeItem(item)
            }
        }
    }
}

private struct FloatingListItemView: View {
    @ObservedObject var item: FloatingFileItem
    @ObservedObject var model: FloatingFileGroupModel

    var isSelected: Bool { model.selectedItemIDs.contains(item.id) }

    var body: some View {
        HStack(spacing: 8) {
            if let img = item.thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            Text(item.url.lastPathComponent)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                model.removeItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.flowAccent.opacity(0.45) : Color.clear)
        )
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                model.selectedItemIDs = [item.id]
            }
        )
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}
