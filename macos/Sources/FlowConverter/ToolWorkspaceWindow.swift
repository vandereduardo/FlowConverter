import Foundation
import AppKit
import SwiftUI
import PDFKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - QR Code Scanner Window & Model

public struct QRCodeResult: Identifiable, Equatable {
    public let id = UUID()
    public let sourceName: String
    public let page: Int?
    public let text: String
}

public final class QRCodeResultsWindowController: NSWindowController {
    private let urls: [URL]
    @Published public var results: [QRCodeResult] = []
    @Published public var isLoading: Bool = true
    @Published public var copiedID: UUID? = nil

    public init(urls: [URL]) {
        self.urls = urls
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "QR Code Results"
        panel.center()
        super.init(window: panel)
        panel.contentView = NSHostingView(rootView: QRCodeResultsView(controller: self))
        scanAll()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func scanAll() {
        DispatchQueue.global(qos: .userInitiated).async {
            var found: [QRCodeResult] = []
            for url in self.urls {
                if url.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: url) {
                    for p in 0..<pdf.pageCount {
                        if let page = pdf.page(at: p) {
                            let img = page.thumbnail(of: NSSize(width: 1200, height: 1600), for: .mediaBox)
                            for payload in Self.detectBarcodes(in: img) {
                                found.append(QRCodeResult(sourceName: url.lastPathComponent, page: p + 1, text: payload))
                            }
                        }
                    }
                } else if let img = NSImage(contentsOf: url) {
                    for payload in Self.detectBarcodes(in: img) {
                        found.append(QRCodeResult(sourceName: url.lastPathComponent, page: nil, text: payload))
                    }
                }
            }
            DispatchQueue.main.async {
                self.results = found
                self.isLoading = false
            }
        }
    }

    private static func detectBarcodes(in image: NSImage) -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        var payloads: [String] = []
        let req = VNDetectBarcodesRequest { request, _ in
            if let obs = request.results as? [VNBarcodeObservation] {
                payloads = obs.compactMap { $0.payloadStringValue }
            }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([req])
        return payloads
    }
}

extension QRCodeResultsWindowController: ObservableObject {}

private struct QRCodeResultsView: View {
    @ObservedObject var controller: QRCodeResultsWindowController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Detected QR & Barcodes", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                Spacer()
                if !controller.results.isEmpty {
                    Button("Copy All") {
                        let all = controller.results.map { $0.text }.joined(separator: "\n")
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(all, forType: .string)
                    }
                    .controlSize(.small)
                }
            }

            if controller.isLoading {
                ProgressView("Reading QR codes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if controller.results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No QR codes found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(controller.results) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Text(item.page != nil ? "\(item.sourceName) · Page \(item.page!)" : item.sourceName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(controller.copiedID == item.id ? "Copied" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.text, forType: .string)
                            controller.copiedID = item.id
                        }
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 440, minHeight: 300)
    }
}

// MARK: - Interactive File Tool Options Model & Window

public struct PDFPagePreview: Identifiable, Equatable {
    public let id = UUID()
    public let originalIndex: Int
    public var rotationDegrees: Int = 0
    public let thumbnail: NSImage
}

public final class FileToolOptionsModel: ObservableObject {
    @Published public var sourceURLs: [URL]
    @Published public var tool: FileTool
    @Published public var options = FileToolOptions()
    @Published public var previewImage: NSImage?
    @Published public var adjustedPreviewImage: NSImage?
    @Published public var imagePreviews: [URL: NSImage] = [:]
    @Published public var imageSizes: [URL: CGSize] = [:]
    @Published public var activeCropURL: URL?
    @Published public var cropAspect: CropAspectPreset = .free
    @Published public var pdfPages: [PDFPagePreview] = []
    @Published public var mediaDuration: Double = 15.0
    @Published public var audioWaveform: [Double] = []
    @Published public var isLoadingWaveform: Bool = false
    @Published public var isPlayingAudioPreview: Bool = false
    @Published public var audioPlaybackTime: Double = 0.0
    @Published public var selectedRedactionID: UUID?
    @Published public var redactionPreviewTime: Double = 0.0
    @Published public var threeMFInfo = ThreeMFProjectInfo()
    @Published public var showAddPrinterIn3MFEditor: Bool = false
    @Published public var isWorking: Bool = false
    @Published public var statusMessage: String?

    // Drag gesture tracking for visual crop, redaction & audio trim editors (avoids @State macro in sandbox)
    public var cropMoveOrigin: CropSelection?
    public var cropResizeOrigin: CropSelection?
    public var cropDrawOrigin: CGPoint?
    public var redactionMoveOrigin: RedactionRectangle?
    public var redactionResizeOrigin: RedactionRectangle?
    public var redactionDrawOrigin: CGPoint?
    public var trimStartDragOrigin: Double?
    public var trimEndDragOrigin: Double?
    public var trimRangeDragOrigin: (start: Double, end: Double)?

    private var audioPlayer: AVPlayer?
    private var audioTimeObserver: Any?

    public var onApply: (() -> Void)?
    public var onCancel: (() -> Void)?

    public init(urls: [URL], tool: FileTool) {
        self.sourceURLs = urls
        self.tool = tool
        self.activeCropURL = urls.first
        loadInitialData()
    }

    public var activeCropImage: NSImage? {
        if let active = activeCropURL, let img = imagePreviews[active] {
            return img
        }
        return previewImage
    }

    public var activeCropPixelSize: CGSize {
        if let active = activeCropURL, let sz = imageSizes[active], sz.width > 0, sz.height > 0 {
            return sz
        }
        if let img = activeCropImage, img.size.width > 0, img.size.height > 0 {
            return img.size
        }
        return CGSize(width: 1920, height: 1080)
    }

    public var currentCropSelection: CropSelection {
        get {
            if !options.useSharedCropForAllImages,
               let active = activeCropURL,
               let perFile = options.cropSelections[active] {
                return perFile
            }
            return options.cropSelection
        }
        set {
            var clamped = newValue
            clamped.width = min(max(clamped.width, 0.01), 1.0)
            clamped.height = min(max(clamped.height, 0.01), 1.0)
            clamped.x = min(max(clamped.x, 0.0), 1.0 - clamped.width)
            clamped.y = min(max(clamped.y, 0.0), 1.0 - clamped.height)

            options.cropSelection = clamped
            if let active = activeCropURL {
                options.cropSelections[active] = clamped
            }
            if options.useSharedCropForAllImages {
                for u in sourceURLs {
                    options.cropSelections[u] = clamped
                }
            }
        }
    }

    public var cropWidthPixels: Int {
        let w = activeCropPixelSize.width * currentCropSelection.width
        return max(1, Int(round(w)))
    }

    public var cropHeightPixels: Int {
        let h = activeCropPixelSize.height * currentCropSelection.height
        return max(1, Int(round(h)))
    }

    public var cropXPixels: Int {
        let x = activeCropPixelSize.width * currentCropSelection.x
        return max(0, Int(round(x)))
    }

    public var cropYPixels: Int {
        let y = activeCropPixelSize.height * currentCropSelection.y
        return max(0, Int(round(y)))
    }

    public func setCropWidthPixels(_ px: Int) {
        let totalW = max(activeCropPixelSize.width, 1)
        let totalH = max(activeCropPixelSize.height, 1)
        var sel = currentCropSelection
        let newNormW = min(max(Double(px) / Double(totalW), 2.0 / Double(totalW)), 1.0)
        sel.width = newNormW
        if sel.x + sel.width > 1.0 {
            sel.x = max(0.0, 1.0 - sel.width)
        }
        if let targetRatio = cropAspect.ratio(for: activeCropPixelSize), targetRatio > 0 {
            let desiredPixelH = (newNormW * Double(totalW)) / targetRatio
            let newNormH = min(max(desiredPixelH / Double(totalH), 2.0 / Double(totalH)), 1.0)
            sel.height = newNormH
            if sel.y + sel.height > 1.0 {
                sel.y = max(0.0, 1.0 - sel.height)
            }
        }
        currentCropSelection = sel
    }

    public func setCropHeightPixels(_ px: Int) {
        let totalW = max(activeCropPixelSize.width, 1)
        let totalH = max(activeCropPixelSize.height, 1)
        var sel = currentCropSelection
        let newNormH = min(max(Double(px) / Double(totalH), 2.0 / Double(totalH)), 1.0)
        sel.height = newNormH
        if sel.y + sel.height > 1.0 {
            sel.y = max(0.0, 1.0 - sel.height)
        }
        if let targetRatio = cropAspect.ratio(for: activeCropPixelSize), targetRatio > 0 {
            let desiredPixelW = (newNormH * Double(totalH)) * targetRatio
            let newNormW = min(max(desiredPixelW / Double(totalW), 2.0 / Double(totalW)), 1.0)
            sel.width = newNormW
            if sel.x + sel.width > 1.0 {
                sel.x = max(0.0, 1.0 - sel.width)
            }
        }
        currentCropSelection = sel
    }

    public func applyAspectPreset(_ preset: CropAspectPreset) {
        cropAspect = preset
        guard let targetRatio = preset.ratio(for: activeCropPixelSize), targetRatio > 0 else {
            return
        }
        let srcW = max(Double(activeCropPixelSize.width), 1.0)
        let srcH = max(Double(activeCropPixelSize.height), 1.0)
        let cur = currentCropSelection
        let centerX = cur.x + cur.width * 0.5
        let centerY = cur.y + cur.height * 0.5

        // Normalized width/height ratio so that (normW * srcW) / (normH * srcH) == targetRatio
        let normRatio = targetRatio * (srcH / srcW)

        var newW = min(max(cur.width, 0.25), 0.92)
        var newH = newW / normRatio
        if newH > 0.92 {
            newH = 0.92
            newW = newH * normRatio
        }
        if newW > 0.92 {
            newW = 0.92
            newH = newW / normRatio
        }
        newW = min(max(newW, 0.02), 1.0)
        newH = min(max(newH, 0.02), 1.0)

        let newX = min(max(centerX - newW * 0.5, 0.0), 1.0 - newW)
        let newY = min(max(centerY - newH * 0.5, 0.0), 1.0 - newH)
        currentCropSelection = CropSelection(x: newX, y: newY, width: newW, height: newH)
    }

    public func resetCrop(fullImage: Bool = false) {
        cropAspect = .free
        if fullImage {
            currentCropSelection = CropSelection(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        } else {
            currentCropSelection = CropSelection(x: 0.05, y: 0.05, width: 0.90, height: 0.90)
        }
    }

    private func loadInitialData() {
        guard let first = sourceURLs.first else { return }

        for url in sourceURLs {
            if let (img, pxSize) = Self.loadOrientedImageAndPixelSize(from: url) {
                self.imagePreviews[url] = img
                self.imageSizes[url] = pxSize
                if url == first {
                    self.previewImage = img
                    self.adjustedPreviewImage = img
                }
            }
            self.options.cropSelections[url] = self.options.cropSelection
        }

        if tool == .cropVideo || tool == .redactVideo {
            let asset = AVURLAsset(url: first)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
            gen.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
            if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
                let pxSize = CGSize(width: cg.width, height: cg.height)
                let nsImg = NSImage(cgImage: cg, size: pxSize)
                self.previewImage = nsImg
                self.imagePreviews[first] = nsImg
                self.imageSizes[first] = pxSize
            }
        }

        if tool == .redactVideo || tool == .redactImage {
            if options.redactions.isEmpty {
                let initialRect = RedactionRectangle(x: 0.25, y: 0.25, width: 0.50, height: 0.30, timeRange: nil)
                options.redactions = [initialRect]
                selectedRedactionID = initialRect.id
            } else if selectedRedactionID == nil {
                selectedRedactionID = options.redactions.first?.id
            }
        }

        if tool == .organizePDF, let pdf = PDFDocument(url: first) {
            var pages: [PDFPagePreview] = []
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) {
                    let thumb = page.thumbnail(of: NSSize(width: 160, height: 220), for: .mediaBox)
                    pages.append(PDFPagePreview(originalIndex: i, rotationDegrees: page.rotation, thumbnail: thumb))
                }
            }
            self.pdfPages = pages
            self.options.pdfPageOrder = pages.map { $0.originalIndex }
        }

        if tool == .removeMetadata {
            loadMetadataFields(for: first)
        }

        if tool == .convert3MF {
            let info = ThreeMFConverterEngine.inspect(url: first)
            self.threeMFInfo = info
            if let thumb = info.thumbnail {
                self.previewImage = thumb
            }
            let printers = FlowConverterSettingsModel.shared.printers3D
            if let diff = printers.first(where: { $0.name.lowercased() != info.currentPrinterModel.lowercased() }) {
                self.options.target3MFPrinterID = diff.id
            } else if let firstPrinter = printers.first {
                self.options.target3MFPrinterID = firstPrinter.id
            }
        }

        if tool == .trimVideo || tool == .splitVideo || tool == .trimAudio || tool == .redactVideo || tool == .redactAudio || tool == .cropVideo {
            let asset = AVURLAsset(url: first)
            let secs = CMTimeGetSeconds(asset.duration)
            if secs.isFinite && secs > 0 {
                self.mediaDuration = secs
                self.options.trimStartSeconds = 0.0
                self.options.trimDurationSeconds = secs
            }
            if tool == .trimAudio {
                loadAudioWaveform(for: first)
            }
        }
    }

    public func updateRedactionVideoFrame(at time: Double) {
        redactionPreviewTime = min(max(time, 0.0), max(mediaDuration, 0.1))
        guard tool == .redactVideo, let first = activeCropURL ?? sourceURLs.first else { return }
        let targetSec = redactionPreviewTime
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let asset = AVURLAsset(url: first)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
            gen.requestedTimeToleranceAfter = CMTime(seconds: 0.1, preferredTimescale: 600)
            let cmTime = CMTime(seconds: targetSec, preferredTimescale: 600)
            guard let cg = try? gen.copyCGImage(at: cmTime, actualTime: nil) else { return }
            let pxSize = CGSize(width: cg.width, height: cg.height)
            let nsImg = NSImage(cgImage: cg, size: pxSize)
            DispatchQueue.main.async {
                self?.previewImage = nsImg
                self?.imagePreviews[first] = nsImg
                self?.imageSizes[first] = pxSize
            }
        }
    }

    public var selectedRedactionIndex: Int? {
        guard let selID = selectedRedactionID else { return options.redactions.indices.first }
        return options.redactions.firstIndex(where: { $0.id == selID })
    }

    public func addRedactionBox() {
        let count = options.redactions.count
        let offset = Double(count % 5) * 0.04
        let newRect = RedactionRectangle(
            x: min(0.20 + offset, 0.65),
            y: min(0.20 + offset, 0.65),
            width: 0.35,
            height: 0.22,
            timeRange: nil
        )
        options.redactions.append(newRect)
        selectedRedactionID = newRect.id
    }

    public func deleteSelectedRedaction() {
        guard let idx = selectedRedactionIndex, options.redactions.indices.contains(idx) else { return }
        options.redactions.remove(at: idx)
        selectedRedactionID = options.redactions.last?.id
    }

    public func clearAllRedactions() {
        options.redactions.removeAll()
        selectedRedactionID = nil
    }

    public var trimEndSeconds: Double {
        get {
            min(max(options.trimStartSeconds + options.trimDurationSeconds, options.trimStartSeconds + 0.1), max(mediaDuration, 0.2))
        }
        set {
            let clampedEnd = min(max(newValue, options.trimStartSeconds + 0.1), max(mediaDuration, 0.2))
            options.trimDurationSeconds = max(0.1, clampedEnd - options.trimStartSeconds)
        }
    }

    public func setTrimStart(_ newStart: Double) {
        let currentEnd = trimEndSeconds
        let clampedStart = min(max(newStart, 0.0), max(0.0, currentEnd - 0.1))
        options.trimStartSeconds = clampedStart
        options.trimDurationSeconds = max(0.1, currentEnd - clampedStart)
        if audioPlaybackTime < clampedStart || audioPlaybackTime > currentEnd {
            audioPlaybackTime = clampedStart
        }
    }

    public func setTrimEnd(_ newEnd: Double) {
        let clampedEnd = min(max(newEnd, options.trimStartSeconds + 0.1), max(mediaDuration, 0.2))
        options.trimDurationSeconds = max(0.1, clampedEnd - options.trimStartSeconds)
        if audioPlaybackTime > clampedEnd || audioPlaybackTime < options.trimStartSeconds {
            audioPlaybackTime = options.trimStartSeconds
        }
    }

    public func resetTrimFullAudio() {
        stopAudioPreview()
        options.trimStartSeconds = 0.0
        options.trimDurationSeconds = mediaDuration
        audioPlaybackTime = 0.0
    }

    public func toggleAudioTrimPreview() {
        if isPlayingAudioPreview {
            stopAudioPreview()
            return
        }
        guard let first = sourceURLs.first else { return }
        stopAudioPreview()

        let player = AVPlayer(url: first)
        self.audioPlayer = player
        let start = options.trimStartSeconds
        let startCM = CMTime(seconds: start, preferredTimescale: 600)
        player.seek(to: startCM, toleranceBefore: .zero, toleranceAfter: .zero)
        audioPlaybackTime = start
        isPlayingAudioPreview = true

        let interval = CMTime(seconds: 0.03, preferredTimescale: 600)
        audioTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let cur = CMTimeGetSeconds(time)
            if cur.isFinite {
                self.audioPlaybackTime = cur
                if cur >= self.trimEndSeconds {
                    self.stopAudioPreview()
                    self.audioPlaybackTime = self.options.trimStartSeconds
                }
            }
        }
        player.play()
    }

    public func stopAudioPreview() {
        if let obs = audioTimeObserver, let player = audioPlayer {
            player.removeTimeObserver(obs)
        }
        audioTimeObserver = nil
        audioPlayer?.pause()
        audioPlayer = nil
        isPlayingAudioPreview = false
    }

    public static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00.00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let hundredths = Int(round((seconds - floor(seconds)) * 100)) % 100
        return String(format: "%02d:%02d.%02d", mins, secs, hundredths)
    }

    private func loadAudioWaveform(for url: URL, barCount: Int = 120) {
        isLoadingWaveform = true
        DispatchQueue.global(qos: .userInitiated).async {
            let samples = Self.extractWaveformPeaks(from: url, count: barCount)
            DispatchQueue.main.async {
                self.audioWaveform = samples
                self.isLoadingWaveform = false
            }
        }
    }

    public static func extractWaveformPeaks(from url: URL, count: Int) -> [Double] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: BundledResources.ffmpegPath)
        proc.arguments = [
            "-hide_banner", "-loglevel", "error",
            "-i", url.path,
            "-vn", "-ac", "1", "-ar", "2000", "-f", "s16le", "pipe:1"
        ]
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            return Self.syntheticWaveform(count: count)
        }

        let rawData = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        let sampleCount = rawData.count / MemoryLayout<Int16>.size
        guard sampleCount > 0 else {
            return Self.syntheticWaveform(count: count)
        }

        var allSamples = [Int16](repeating: 0, count: sampleCount)
        _ = allSamples.withUnsafeMutableBytes { dst in
            rawData.copyBytes(to: dst)
        }

        let bucketSize = max(1, allSamples.count / count)
        var peaks: [Double] = []
        peaks.reserveCapacity(count)
        var maxPeak: Double = 0.01

        for i in 0..<count {
            let startIdx = i * bucketSize
            if startIdx >= allSamples.count {
                peaks.append(0.08)
                continue
            }
            let endIdx = min(allSamples.count, startIdx + bucketSize)
            var sumSq: Double = 0
            var localMax: Double = 0
            for j in startIdx..<endIdx {
                let val = Int(allSamples[j])
                let s = Double(abs(val)) / 32768.0
                sumSq += s * s
                if s > localMax { localMax = s }
            }
            let rms = sqrt(sumSq / Double(max(1, endIdx - startIdx)))
            let blended = rms * 0.65 + localMax * 0.35
            peaks.append(blended)
            if blended > maxPeak { maxPeak = blended }
        }

        return peaks.map { min(max(($0 / maxPeak), 0.08), 1.0) }
    }

    public static func syntheticWaveform(count: Int) -> [Double] {
        return (0..<count).map { i in
            let v = abs(sin(Double(i) * 0.29) * cos(Double(i) * 0.13))
            return min(max(0.12 + v * 0.82, 0.1), 1.0)
        }
    }

    public static func loadOrientedImageAndPixelSize(from url: URL) -> (NSImage, CGSize)? {
        if let ci = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) {
            let ctx = CIContext(options: nil)
            let extent = ci.extent
            if extent.width > 0 && extent.height > 0,
               let cg = ctx.createCGImage(ci, from: extent) {
                let pxSize = CGSize(width: cg.width, height: cg.height)
                let nsImg = NSImage(cgImage: cg, size: pxSize)
                return (nsImg, pxSize)
            }
        }
        if let img = NSImage(contentsOf: url) {
            if let rep = img.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
                return (img, CGSize(width: rep.pixelsWide, height: rep.pixelsHigh))
            }
            return (img, img.size)
        }
        return nil
    }

    public func updateAdjustedImagePreview() {
        guard let base = previewImage else { return }
        adjustedPreviewImage = ToolExecutionEngine.applyCoreImageAdjustments(to: base, adjustments: options.imageAdjustments)
    }

    private func loadMetadataFields(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            var parsed: [MetadataField] = []
            if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
               let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any] {
                for (topKey, topVal) in props {
                    if let subDict = topVal as? [String: Any] {
                        let scope = topKey.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
                        for (k, v) in subDict {
                            parsed.append(MetadataField(scope: scope, key: k, original: "\(v)", value: "\(v)", editable: false, removable: true))
                        }
                    } else {
                        parsed.append(MetadataField(scope: "Image", key: topKey, original: "\(topVal)", value: "\(topVal)", editable: false, removable: true))
                    }
                }
            } else if url.pathExtension.lowercased() == "pdf",
                      let pdf = PDFDocument(url: url),
                      let attrs = pdf.documentAttributes {
                for (k, v) in attrs {
                    let keyStr = "\(k)"
                    parsed.append(MetadataField(scope: "PDF", key: keyStr, original: "\(v)", value: "\(v)", editable: false, removable: true))
                }
            }
            parsed.sort { "\($0.scope).\($0.key)" < "\($1.scope).\($1.key)" }
            DispatchQueue.main.async {
                self.options.metadataFields = parsed
            }
        }
    }
}

public final class FileToolOptionsWindowController: NSWindowController, NSWindowDelegate {
    public let model: FileToolOptionsModel
    public var onDismiss: (() -> Void)?
    private let taskStore: ConversionTaskStore

    public init(urls: [URL], tool: FileTool, taskStore: ConversionTaskStore) {
        self.model = FileToolOptionsModel(urls: urls, tool: tool)
        self.taskStore = taskStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = tool.title
        window.center()
        super.init(window: window)
        window.delegate = self

        model.onCancel = { [weak self] in
            self?.model.stopAudioPreview()
            self?.close()
            self?.onDismiss?()
        }

        model.onApply = { [weak self] in
            guard let self = self else { return }
            self.model.stopAudioPreview()
            let urls = self.model.sourceURLs
            let tool = self.model.tool
            var opts = self.model.options
            if tool == .organizePDF {
                opts.pdfPageOrder = self.model.pdfPages.map { $0.originalIndex }
                var rots: [Int: Int] = [:]
                for p in self.model.pdfPages {
                    rots[p.originalIndex] = p.rotationDegrees
                }
                opts.pdfPageRotations = rots
            }
            self.close()
            self.onDismiss?()
            ToolExecutionEngine.shared.execute(tool: tool, urls: urls, options: opts, taskStore: self.taskStore)
        }

        window.contentView = NSHostingView(rootView: FileToolOptionsView(model: model))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        model.stopAudioPreview()
        onDismiss?()
    }
}

// MARK: - SwiftUI Tool Options View

public struct FileToolOptionsView: View {
    @ObservedObject var model: FileToolOptionsModel
    @ObservedObject var settings = FlowConverterSettingsModel.shared

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(model.tool.title, systemImage: model.tool.iconName)
                    .font(.title3.bold())
                    .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                Spacer()
                Text("\(model.sourceURLs.count) \(model.sourceURLs.count == 1 ? "file" : "files")")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding(16)

            Divider()

            // Tool-Specific Editor Body
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    toolBody
                }
                .padding(18)
            }

            Divider()

            // Footer Actions
            HStack {
                Button("Cancel") {
                    model.onCancel?()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(actionButtonTitle) {
                    model.onApply?()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.898, blue: 1.0))
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(minWidth: 620, minHeight: 460)
    }

    private var actionButtonTitle: String {
        switch model.tool {
        case .removeMetadata: return "Save Cleaned Copy"
        case .editImage: return "Save Edited Copy"
        case .annotateImage: return "Save Annotated Copy"
        case .frameImage: return "Save with Background"
        case .organizePDF: return "Save Organized PDF"
        case .audioToVideo: return "Create Visualization"
        case .redactImage, .redactVideo: return "Save Redacted Copy"
        case .redactAudio: return "Save Bleeped Copy"
        case .joinVideos: return "Export One Video"
        case .convert3MF: return "Convert 3MF Project"
        default: return "Apply & Save"
        }
    }

    @ViewBuilder
    private var toolBody: some View {
        switch model.tool {
        case .compress:
            compressionEditor
        case .removeMetadata:
            metadataEditor
        case .editImage:
            imageAdjustmentsEditor
        case .frameImage:
            frameImageEditor
        case .cropImage, .cropVideo:
            cropEditor
        case .annotateImage:
            annotationEditor
        case .createCollage:
            collageEditor
        case .organizePDF:
            pdfOrganizerEditor
        case .trimVideo, .trimAudio:
            trimEditor
        case .changeVideoSpeed:
            videoSpeedEditor
        case .normalizeAudio:
            audioNormalizationEditor
        case .audioChannels:
            audioChannelsEditor
        case .audioToVideo:
            audioVisualizerEditor
        case .splitVideo:
            videoSplitEditor
        case .videoSnapshots:
            videoSnapshotsEditor
        case .redactImage, .redactVideo:
            redactionEditor
        case .redactAudio:
            audioBleepEditor
        case .joinVideos:
            orderedSourceEditor
        case .convert3MF:
            threeMFConverterEditor
        default:
            Text("Ready to process \(model.sourceURLs.count) selected file(s).")
        }
    }

    // MARK: - Sub-Editors

    private var compressionEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Compression Mode:", selection: $model.options.compressionTargetMode) {
                ForEach(CompressionTargetMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if model.options.compressionTargetMode == .preset {
                Picker("Image Strength:", selection: $model.options.imageCompression.strength) {
                    ForEach(ImageCompressionStrength.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
                Picker("Image Size:", selection: $model.options.imageCompression.size) {
                    ForEach(ImageCompressionSize.allCases) { sz in
                        Text(sz.title).tag(sz)
                    }
                }
                Picker("Video Strength:", selection: $model.options.videoCompression.strength) {
                    ForEach(VideoCompressionStrength.allCases) { s in
                        Text(s.title).tag(s)
                    }
                }
            } else if model.options.compressionTargetMode == .fileSize {
                HStack {
                    Text("Maximum Size:")
                    TextField("5", text: $model.options.targetSizeText)
                        .frame(width: 80)
                    Picker("", selection: $model.options.targetSizeUnit) {
                        Text("KB").tag("KB")
                        Text("MB").tag("MB")
                    }
                    .frame(width: 80)
                }
            } else {
                Slider(value: $model.options.compressionReductionPercentage, in: 10...90, step: 5) {
                    Text("Reduction: \(Int(model.options.compressionReductionPercentage))%")
                }
            }
        }
    }

    private var metadataEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Remove all private metadata & camera/location data (Preserves ICC profile & pixel hash)", isOn: $model.options.removeAllMetadata)
                .font(.headline)

            if !model.options.metadataFields.isEmpty {
                Text("Detected Metadata Fields (\(model.options.metadataFields.count)):")
                    .font(.subheadline.bold())
                ForEach($model.options.metadataFields) { $field in
                    HStack {
                        Text("\(field.scope):\(field.key)")
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 180, alignment: .leading)
                        TextField("Value", text: $field.value)
                            .textFieldStyle(.roundedBorder)
                            .disabled(model.options.removeAllMetadata || !field.editable)
                        Toggle("Remove", isOn: $field.removed)
                            .disabled(model.options.removeAllMetadata || !field.removable)
                    }
                }
            } else {
                Text("For photos, Remove All clears EXIF, XMP, GPS, Apple MakerNotes, and JUMBF Content Credentials while preserving visual fidelity.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var imageAdjustmentsEditor: some View {
        HStack(alignment: .top, spacing: 18) {
            if let img = model.adjustedPreviewImage ?? model.previewImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .cornerRadius(10)
            }
            VStack(alignment: .leading, spacing: 10) {
                adjustmentSlider("Exposure", value: $model.options.imageAdjustments.exposure, range: -2...2)
                adjustmentSlider("Brightness", value: $model.options.imageAdjustments.brightness, range: -0.5...0.5)
                adjustmentSlider("Contrast", value: $model.options.imageAdjustments.contrast, range: -0.5...0.5)
                adjustmentSlider("Saturation", value: $model.options.imageAdjustments.saturation, range: -1...1)
                adjustmentSlider("Temperature", value: $model.options.imageAdjustments.temperature, range: -1...1)
                adjustmentSlider("Sharpness", value: $model.options.imageAdjustments.sharpness, range: 0...2)
                adjustmentSlider("Vignette", value: $model.options.imageAdjustments.vignette, range: 0...2)
                adjustmentSlider("Blur", value: $model.options.imageAdjustments.blur, range: 0...20)
                Button("Reset Adjustments") {
                    model.options.imageAdjustments = ImageAdjustments()
                    model.updateAdjustedImagePreview()
                }
                .controlSize(.small)
            }
        }
    }

    private func adjustmentSlider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(label).font(.caption).frame(width: 85, alignment: .leading)
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: {
                    value.wrappedValue = $0
                    model.updateAdjustedImagePreview()
                }
            ), in: range)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.caption.monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
    }

    private var frameImageEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Background Preset:", selection: $model.options.imageFrame.background) {
                ForEach(FrameBackgroundPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            Picker("Canvas Ratio:", selection: $model.options.imageFrame.canvasRatio) {
                ForEach(FrameCanvasRatio.allCases) { ratio in
                    Text(ratio.title).tag(ratio)
                }
            }
            HStack {
                Text("Padding: \(Int(model.options.imageFrame.padding)) px").frame(width: 130, alignment: .leading)
                Slider(value: $model.options.imageFrame.padding, in: 0...200)
            }
            HStack {
                Text("Corner Radius: \(Int(model.options.imageFrame.cornerRadius)) px").frame(width: 130, alignment: .leading)
                Slider(value: $model.options.imageFrame.cornerRadius, in: 0...64)
            }
            HStack {
                Text("Shadow Radius: \(Int(model.options.imageFrame.shadowRadius)) px").frame(width: 130, alignment: .leading)
                Slider(value: $model.options.imageFrame.shadowRadius, in: 0...64)
            }
        }
    }

    private var cropEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Interactive Visual Crop Canvas
            VisualCropCanvasView(model: model)
                .frame(height: 360)

            // Aspect Ratio Presets Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Aspect Ratio:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    let pxSize = model.activeCropPixelSize
                    Text("Source: \(Int(pxSize.width)) × \(Int(pxSize.height)) px   •   Crop: \(model.cropWidthPixels) × \(model.cropHeightPixels) px (X: \(model.cropXPixels), Y: \(model.cropYPixels))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CropAspectPreset.allCases) { preset in
                            let isSelected = (model.cropAspect == preset)
                            Button {
                                model.applyAspectPreset(preset)
                            } label: {
                                Text(preset.title)
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(isSelected ? Color(red: 0.0, green: 0.898, blue: 1.0) : Color.secondary.opacity(0.14))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        Divider().frame(height: 18)

                        Button("Full Image") {
                            model.resetCrop(fullImage: true)
                        }
                        .controlSize(.small)

                        Button("Reset") {
                            model.resetCrop(fullImage: false)
                        }
                        .controlSize(.small)
                    }
                }
            }

            // Pixel Width & Height Fine Controls
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("Width (px):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(
                        "Width",
                        value: Binding(
                            get: { model.cropWidthPixels },
                            set: { model.setCropWidthPixels($0) }
                        ),
                        formatter: NumberFormatter()
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 78)
                    .help("Crop width in pixels")
                }

                HStack(spacing: 6) {
                    Text("Height (px):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField(
                        "Height",
                        value: Binding(
                            get: { model.cropHeightPixels },
                            set: { model.setCropHeightPixels($0) }
                        ),
                        formatter: NumberFormatter()
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 78)
                    .help("Crop height in pixels")
                }

                Spacer()

                Text("Drag inside the box to reposition, drag any corner/edge handle to resize, or drag outside to draw a new crop.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Multi-Image Thumbnail Strip & Shared Crop Toggle
            if model.sourceURLs.count > 1 {
                Divider()
                Toggle("Use this crop, as the same share of each image, for every image", isOn: $model.options.useSharedCropForAllImages)
                    .font(.caption)
                    .onChange(of: model.options.useSharedCropForAllImages) { shared in
                        if shared {
                            let current = model.currentCropSelection
                            for u in model.sourceURLs {
                                model.options.cropSelections[u] = current
                            }
                        }
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.sourceURLs, id: \.self) { url in
                            let isActive = (model.activeCropURL == url)
                            Button {
                                model.activeCropURL = url
                            } label: {
                                VStack(spacing: 4) {
                                    if let thumb = model.imagePreviews[url] {
                                        Image(nsImage: thumb)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 68, height: 50)
                                            .clipped()
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(isActive ? Color(red: 0.0, green: 0.898, blue: 1.0) : Color.clear, lineWidth: 2.5)
                                            )
                                    }
                                    Text(url.lastPathComponent)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .frame(width: 68)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var annotationEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach([AnnotationKind.arrow, .rectangle, .ellipse, .text, .number]) { kind in
                    Button {
                        let nextNum = model.options.annotations.filter { $0.kind == .number }.count + 1
                        model.options.annotations.append(
                            ImageAnnotation(
                                kind: kind,
                                x: 0.2,
                                y: 0.2,
                                endX: 0.6,
                                endY: 0.6,
                                text: kind == .text ? "Callout" : "",
                                number: nextNum
                            )
                        )
                    } label: {
                        Label("Add \(kind.title)", systemImage: kind.iconName)
                    }
                }
                if !model.options.annotations.isEmpty {
                    Button("Clear All", role: .destructive) {
                        model.options.annotations.removeAll()
                    }
                }
            }
            Text("\(model.options.annotations.count) annotation(s) queued on canvas.")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach($model.options.annotations) { $ann in
                HStack {
                    Image(systemName: ann.kind.iconName).foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                    Text(ann.kind.title).frame(width: 80, alignment: .leading)
                    if ann.kind == .text {
                        TextField("Text", text: $ann.text).textFieldStyle(.roundedBorder)
                    }
                    Slider(value: $ann.x, in: 0...0.9)
                    Slider(value: $ann.y, in: 0...0.9)
                }
            }
        }
    }

    private var collageEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Layout Style:", selection: $model.options.collage.style) {
                ForEach(CollageStyle.allCases) { s in
                    Text(s.title).tag(s)
                }
            }
            Stepper("Columns: \(model.options.collage.columns)", value: $model.options.collage.columns, in: 1...6)
            Picker("Background:", selection: $model.options.collage.background) {
                ForEach(CollageBackground.allCases) { bg in
                    Text(bg.title).tag(bg)
                }
            }
            HStack {
                Text("Spacing: \(Int(model.options.collage.spacing)) px").frame(width: 120, alignment: .leading)
                Slider(value: $model.options.collage.spacing, in: 0...64)
            }
            HStack {
                Text("Padding: \(Int(model.options.collage.padding)) px").frame(width: 120, alignment: .leading)
                Slider(value: $model.options.collage.padding, in: 0...96)
            }
        }
    }

    private var pdfOrganizerEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Make all pages the same width", isOn: $model.options.equalizePDFPageWidths)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(Array(model.pdfPages.enumerated()), id: \.element.id) { idx, page in
                    VStack(spacing: 6) {
                        Image(nsImage: page.thumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 110)
                            .rotationEffect(.degrees(Double(page.rotationDegrees)))
                            .cornerRadius(4)
                        Text("Page \(page.originalIndex + 1)")
                            .font(.caption.bold())
                        HStack(spacing: 6) {
                            Button {
                                model.pdfPages[idx].rotationDegrees = (model.pdfPages[idx].rotationDegrees + 90) % 360
                            } label: {
                                Image(systemName: "rotate.right")
                            }
                            .buttonStyle(.borderless)
                            if idx > 0 {
                                Button {
                                    model.pdfPages.swapAt(idx, idx - 1)
                                } label: {
                                    Image(systemName: "arrow.left")
                                }
                                .buttonStyle(.borderless)
                            }
                            if idx < model.pdfPages.count - 1 {
                                Button {
                                    model.pdfPages.swapAt(idx, idx + 1)
                                } label: {
                                    Image(systemName: "arrow.right")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var trimEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header info & Playback controls
            HStack {
                Button {
                    model.toggleAudioTrimPreview()
                } label: {
                    Label(
                        model.isPlayingAudioPreview ? "Pause Preview" : "Play Selected Range",
                        systemImage: model.isPlayingAudioPreview ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.0, green: 0.898, blue: 1.0))
                .controlSize(.regular)

                Button("Reset Full Audio") {
                    model.resetTrimFullAudio()
                }
                .controlSize(.regular)

                Spacer()

                Text("Total: \(FileToolOptionsModel.formatTime(model.mediaDuration))")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // Interactive Rectangular Waveform Box with Left & Right Sliding Vertical Bars
            AudioWaveformTrimView(model: model)
                .frame(height: 176)

            // Start / End / Selected Duration Cards with Fine Adjustment Buttons
            HStack(spacing: 14) {
                // Start Time Card
                VStack(alignment: .leading, spacing: 4) {
                    Text("START (LEFT BAR)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Text(FileToolOptionsModel.formatTime(model.options.trimStartSeconds))
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                        Button("-0.1s") { model.setTrimStart(model.options.trimStartSeconds - 0.1) }
                            .controlSize(.mini)
                        Button("+0.1s") { model.setTrimStart(model.options.trimStartSeconds + 0.1) }
                            .controlSize(.mini)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                // End Time Card
                VStack(alignment: .leading, spacing: 4) {
                    Text("END (RIGHT BAR)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Text(FileToolOptionsModel.formatTime(model.trimEndSeconds))
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                        Button("-0.1s") { model.setTrimEnd(model.trimEndSeconds - 0.1) }
                            .controlSize(.mini)
                        Button("+0.1s") { model.setTrimEnd(model.trimEndSeconds + 0.1) }
                            .controlSize(.mini)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                // Resulting Duration Card
                VStack(alignment: .leading, spacing: 4) {
                    Text("SELECTED DURATION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(FileToolOptionsModel.formatTime(model.options.trimDurationSeconds)) (\(String(format: "%.2fs", model.options.trimDurationSeconds)))")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Text("Drag the left vertical orange bar to set the new start time, drag the right vertical bar to set the new end time, or drag inside the selected region to move the window.")
                .font(.caption2)
                .foregroundColor(.secondary)

            if model.tool == .trimAudio {
                Divider()
                Toggle("Trim silent ends automatically", isOn: $model.options.autoTrimSilence)
                if model.options.autoTrimSilence {
                    HStack {
                        Text("Silence Threshold: \(Int(model.options.silenceThresholdDB)) dB")
                            .font(.caption)
                        Slider(value: $model.options.silenceThresholdDB, in: -80...(-10))
                    }
                }
            }
        }
    }

    private var videoSpeedEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Playback Speed: \(String(format: "%.2f×", model.options.playbackSpeed))")
                .font(.headline)
            Slider(value: $model.options.playbackSpeed, in: 0.25...4.0, step: 0.25)
            HStack(spacing: 8) {
                ForEach([0.5, 0.75, 1.25, 1.5, 2.0, 4.0], id: \.self) { spd in
                    Button("\(String(format: "%g×", spd))") {
                        model.options.playbackSpeed = spd
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var audioNormalizationEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EBU R128 Loudness Normalization").font(.headline)
            HStack {
                Text("Target Loudness: \(String(format: "%.1f LUFS", model.options.normalizationTargetLoudness))")
                    .frame(width: 190, alignment: .leading)
                Slider(value: $model.options.normalizationTargetLoudness, in: -30...(-8), step: 0.5)
            }
            HStack {
                Text("Loudness Range: \(String(format: "%.1f LU", model.options.normalizationLoudnessRange))")
                    .frame(width: 190, alignment: .leading)
                Slider(value: $model.options.normalizationLoudnessRange, in: 1...20, step: 0.5)
            }
            HStack {
                Text("True Peak: \(String(format: "%.1f dBTP", model.options.normalizationTruePeak))")
                    .frame(width: 190, alignment: .leading)
                Slider(value: $model.options.normalizationTruePeak, in: -9...0, step: 0.5)
            }
        }
    }

    private var audioChannelsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Output Channels:", selection: $model.options.audioChannelCount) {
                Text("Stereo (2.0)").tag(2)
                Text("Mono (1.0)").tag(1)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Left Channel Volume: \(Int(model.options.audioLeftVolume * 100))%")
                    .frame(width: 190, alignment: .leading)
                Slider(value: $model.options.audioLeftVolume, in: 0...2.0)
            }
            HStack {
                Text("Right Channel Volume: \(Int(model.options.audioRightVolume * 100))%")
                    .frame(width: 190, alignment: .leading)
                Slider(value: $model.options.audioRightVolume, in: 0...2.0)
            }
        }
    }

    private var audioVisualizerEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Live Visual Canvas Preview
            GeometryReader { geo in
                let canvasDims = model.options.videoCanvas.dimensions
                let fitRect = VisualCropCanvasView.aspectFitRect(imageSize: canvasDims, in: geo.size, padding: 12)
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(0.45))

                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 0.07, green: 0.07, blue: 0.08))

                        if model.options.audioVisualization == .staticImage,
                           let imgURL = model.options.staticImageURL,
                           let nsImg = NSImage(contentsOf: imgURL) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFit()
                                .frame(width: fitRect.width, height: fitRect.height)
                                .clipped()
                        } else if model.options.audioVisualization == .staticImage {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                                Text("Choose a static image for the video")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        } else {
                            // Stylized Orange Waveform Preview
                            HStack(alignment: .center, spacing: 3) {
                                ForEach(0..<48, id: \.self) { i in
                                    let norm = abs(sin(Double(i) * 0.37) * cos(Double(i) * 0.19))
                                    let barH = max(6.0, CGFloat(0.12 + norm * 0.72) * fitRect.height)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.75), Color(red: 1.0, green: 0.32, blue: 0.0), Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.75)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: max(2, (fitRect.width * 0.82) / 68.0), height: barH)
                                }
                            }
                        }

                        VStack {
                            Spacer()
                            HStack {
                                Text("\(Int(canvasDims.width)) × \(Int(canvasDims.height)) px • 30 fps")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.65))
                                    .cornerRadius(5)
                                Spacer()
                            }
                            .padding(8)
                        }
                    }
                    .frame(width: fitRect.width, height: fitRect.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                }
            }
            .frame(height: 260)

            Picker("Visualization Style:", selection: $model.options.audioVisualization) {
                ForEach(AudioVisualizationStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Picker("Video Canvas:", selection: $model.options.videoCanvas) {
                ForEach(MediaCanvas.allCases) { canvas in
                    Text(canvas.title).tag(canvas)
                }
            }
            .pickerStyle(.segmented)

            if model.options.audioVisualization == .staticImage {
                HStack {
                    Button("Choose Image…") {
                        let panel = NSOpenPanel()
                        panel.title = "Choose a static image"
                        panel.allowedContentTypes = [.image]
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK {
                            model.options.staticImageURL = panel.url
                        }
                    }
                    if let url = model.options.staticImageURL {
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var videoSplitEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Export Mode:", selection: $model.options.splitExportMode) {
                ForEach(SplitExportMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Button("Add Split Point at Midpoint (\(String(format: "%.1fs", model.mediaDuration / 2)))") {
                let pt = model.mediaDuration / 2
                if !model.options.splitTimes.contains(pt) {
                    model.options.splitTimes.append(pt)
                    model.options.splitTimes.sort()
                }
            }
            ForEach(Array(model.options.splitTimes.enumerated()), id: \.offset) { idx, t in
                HStack {
                    Text("Split #\(idx + 1) at \(String(format: "%.2fs", t))")
                    Slider(value: Binding(
                        get: { model.options.splitTimes[idx] },
                        set: { model.options.splitTimes[idx] = $0 }
                    ), in: 0.1...max(model.mediaDuration - 0.1, 0.2))
                }
            }
        }
    }

    private var videoSnapshotsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Add Frame Timestamp") {
                let next = min((model.options.snapshotTimes.last ?? 0) + 1.0, model.mediaDuration)
                model.options.snapshotTimes.append(next)
            }
            ForEach(Array(model.options.snapshotTimes.enumerated()), id: \.offset) { idx, _ in
                HStack {
                    Text("Frame #\(idx + 1): \(String(format: "%.2fs", model.options.snapshotTimes[idx]))")
                        .frame(width: 130, alignment: .leading)
                    Slider(value: Binding(
                        get: { model.options.snapshotTimes[idx] },
                        set: { model.options.snapshotTimes[idx] = $0 }
                    ), in: 0...max(model.mediaDuration, 1.0))
                }
            }
        }
    }

    private var redactionEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. Top Toolbar: Style + Add/Delete/Clear Boxes
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("Style:")
                        .font(.subheadline.weight(.medium))
                    Picker("", selection: $model.options.redactionStyle) {
                        ForEach(RedactionStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }

                Spacer()

                Button {
                    model.addRedactionBox()
                } label: {
                    Label("Add Box", systemImage: "plus.rectangle.on.rectangle")
                }
                .controlSize(.small)

                Button(role: .destructive) {
                    model.deleteSelectedRedaction()
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .controlSize(.small)
                .disabled(model.selectedRedactionIndex == nil)

                if model.options.redactions.count > 1 {
                    Button("Clear All") {
                        model.clearAllRedactions()
                    }
                    .controlSize(.small)
                }
            }

            // 2. Interactive Visual Redaction Canvas (Draw, Move & Resize Boxes Directly on Video/Image)
            VisualRedactionCanvasView(model: model)
                .frame(height: 335)

            Text("Tip: Drag anywhere on the image/video to draw a new redaction box, drag inside a box to move it, or drag its orange handles to resize.")
                .font(.caption)
                .foregroundColor(.secondary)

            // 3. Video Frame Scrubber Timeline (Only for Redact Video)
            if model.tool == .redactVideo {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Video Timeline Scrubber", systemImage: "film")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(FileToolOptionsModel.formatTime(model.redactionPreviewTime)) / \(FileToolOptionsModel.formatTime(model.mediaDuration))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                    }
                    Slider(
                        value: Binding(
                            get: { model.redactionPreviewTime },
                            set: { model.updateRedactionVideoFrame(at: $0) }
                        ),
                        in: 0...max(model.mediaDuration, 0.2)
                    )
                    .tint(Color(red: 0.0, green: 0.898, blue: 1.0))
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }

            // 4. Box Selector Pills + Selected Box Properties (Coordinates & Video Time Range)
            if !model.options.redactions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(model.options.redactions.enumerated()), id: \.element.id) { idx, rect in
                                let isSelected = (rect.id == model.selectedRedactionID) || (model.selectedRedactionID == nil && idx == 0)
                                Button {
                                    model.selectedRedactionID = rect.id
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: model.options.redactionStyle == .blur ? "drop.halffull" : "rectangle.fill")
                                            .font(.caption2)
                                        Text("Box #\(idx + 1)")
                                            .font(.caption.weight(.semibold))
                                        if let tr = rect.timeRange {
                                            Text("(\(String(format: "%.1fs–%.1fs", tr.start, tr.end)))")
                                                .font(.caption2)
                                                .opacity(0.85)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(isSelected ? Color(red: 0.0, green: 0.898, blue: 1.0) : Color.secondary.opacity(0.15))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let selIdx = model.selectedRedactionIndex, model.options.redactions.indices.contains(selIdx) {
                        let rect = model.options.redactions[selIdx]
                        let pxSize = model.activeCropPixelSize
                        let pxX = Int(round(rect.x * Double(pxSize.width)))
                        let pxY = Int(round(rect.y * Double(pxSize.height)))
                        let pxW = max(1, Int(round(rect.width * Double(pxSize.width))))
                        let pxH = max(1, Int(round(rect.height * Double(pxSize.height))))

                        HStack {
                            Text("Selected Box #\(selIdx + 1):")
                                .font(.caption.weight(.semibold))
                            Text("X: \(pxX) px · Y: \(pxY) px · Size: \(pxW) × \(pxH) px")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                        }

                        if model.tool == .redactVideo {
                            Divider()
                            HStack(spacing: 12) {
                                Toggle(
                                    "Show Box #\(selIdx + 1) Only During Specific Time Range",
                                    isOn: Binding(
                                        get: { model.options.redactions[selIdx].timeRange != nil },
                                        set: { enabled in
                                            if enabled {
                                                let start = min(model.redactionPreviewTime, max(0, model.mediaDuration - 0.5))
                                                let end = min(max(start + 2.0, start + 0.2), model.mediaDuration)
                                                model.options.redactions[selIdx].timeRange = RedactionTimeRange(start: start, end: end)
                                            } else {
                                                model.options.redactions[selIdx].timeRange = nil
                                            }
                                        }
                                    )
                                )
                                .font(.caption.weight(.medium))
                                Spacer()
                            }

                            if let tr = model.options.redactions[selIdx].timeRange {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 10) {
                                        Text("Start: \(FileToolOptionsModel.formatTime(tr.start))")
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(width: 95, alignment: .leading)
                                        Slider(
                                            value: Binding(
                                                get: { model.options.redactions[selIdx].timeRange?.start ?? 0 },
                                                set: { newStart in
                                                    let curEnd = model.options.redactions[selIdx].timeRange?.end ?? model.mediaDuration
                                                    model.options.redactions[selIdx].timeRange?.start = min(max(0, newStart), max(0, curEnd - 0.1))
                                                }
                                            ),
                                            in: 0...max(model.mediaDuration - 0.1, 0.2)
                                        )
                                        Button("Set to Playhead") {
                                            let curEnd = model.options.redactions[selIdx].timeRange?.end ?? model.mediaDuration
                                            model.options.redactions[selIdx].timeRange?.start = min(model.redactionPreviewTime, max(0, curEnd - 0.1))
                                        }
                                        .controlSize(.mini)
                                    }

                                    HStack(spacing: 10) {
                                        Text("End:   \(FileToolOptionsModel.formatTime(tr.end))")
                                            .font(.system(.caption, design: .monospaced))
                                            .frame(width: 95, alignment: .leading)
                                        Slider(
                                            value: Binding(
                                                get: { model.options.redactions[selIdx].timeRange?.end ?? model.mediaDuration },
                                                set: { newEnd in
                                                    let curStart = model.options.redactions[selIdx].timeRange?.start ?? 0
                                                    model.options.redactions[selIdx].timeRange?.end = max(min(newEnd, model.mediaDuration), curStart + 0.1)
                                                }
                                            ),
                                            in: 0.1...max(model.mediaDuration, 0.2)
                                        )
                                        Button("Set to Playhead") {
                                            let curStart = model.options.redactions[selIdx].timeRange?.start ?? 0
                                            model.options.redactions[selIdx].timeRange?.end = max(model.redactionPreviewTime, min(curStart + 0.1, model.mediaDuration))
                                        }
                                        .controlSize(.mini)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
        }
    }

    private var audioBleepEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Add 1 kHz Bleep Range") {
                model.options.bleepRanges.append(RedactionTimeRange(start: 1.0, end: min(2.5, model.mediaDuration)))
            }
            Button("Bleep Entire Audio") {
                model.options.bleepRanges = [RedactionTimeRange(start: 0, end: model.mediaDuration)]
            }
            ForEach($model.options.bleepRanges) { $range in
                HStack {
                    Text("Start: \(String(format: "%.1fs", range.start))")
                    Slider(value: $range.start, in: 0...max(model.mediaDuration - 0.2, 0.5))
                    Text("End: \(String(format: "%.1fs", range.end))")
                    Slider(value: $range.end, in: 0.2...max(model.mediaDuration, 1.0))
                }
            }
        }
    }

    private var orderedSourceEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Video Order:")
                    .font(.headline)
                Spacer()
                Button("Sort by Name") {
                    model.sourceURLs.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                }
                .controlSize(.small)
            }
            ForEach(Array(model.sourceURLs.enumerated()), id: \.element) { idx, url in
                HStack {
                    Text("\(idx + 1). \(url.lastPathComponent)")
                    Spacer()
                    if idx > 0 {
                        Button { model.sourceURLs.swapAt(idx, idx - 1) } label: { Image(systemName: "arrow.up") }
                            .buttonStyle(.borderless)
                    }
                    if idx < model.sourceURLs.count - 1 {
                        Button { model.sourceURLs.swapAt(idx, idx + 1) } label: { Image(systemName: "arrow.down") }
                            .buttonStyle(.borderless)
                    }
                }
                .padding(6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    // MARK: - 3MF Converter & Inspector Editor (Cordeiro Flow Style)

    private var threeMFConverterEditor: some View {
        let info = model.threeMFInfo
        return VStack(alignment: .leading, spacing: 16) {
            // 1. Extracted .3MF Project Info Card
            GroupBox(label: Label("Informações Extraídas do Arquivo .3MF", systemImage: "cube.transparent.fill").font(.headline)) {
                HStack(alignment: .top, spacing: 16) {
                    // Plate Thumbnail or 3D Cube Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.82))
                            .frame(width: 118, height: 118)

                        if let thumb = info.thumbnail {
                            Image(nsImage: thumb)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 110, height: 110)
                                .cornerRadius(8)
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "cube.transparent.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                                Text(".3MF Project")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "printer.fill")
                                .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                            Text("Impressora Original:")
                                .font(.subheadline.weight(.semibold))
                            Text(info.currentPrinterModel)
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.16))
                                .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                                .cornerRadius(6)
                            Spacer()
                        }

                        // Metadata Pills Grid
                        HStack(spacing: 10) {
                            threeMFStatPill(icon: "square.dashed", label: "Mesa", value: "\(info.bedWidthMM)×\(info.bedDepthMM)×\(info.bedHeightMM) mm")
                            threeMFStatPill(icon: "circle.dotted", label: "Bico", value: "\(info.nozzleDiameter) mm")
                            threeMFStatPill(icon: "line.3.horizontal", label: "Camada", value: "\(info.layerHeight) mm")
                            threeMFStatPill(icon: "square.stack.3d.up", label: "Placas / Peças", value: "\(info.plateCount) / \(info.objectCount)")
                        }

                        HStack(spacing: 10) {
                            threeMFStatPill(icon: "squareshape.split.2x2", label: "Infill", value: info.infillDensity)
                            threeMFStatPill(icon: "square.on.square", label: "Paredes", value: info.wallLoops)
                            threeMFStatPill(icon: "arrow.up.to.line", label: "Suporte", value: info.supportEnabled ? "Ativado" : "Desativado")
                            if info.estimatedTimeSeconds > 0 || info.totalWeightGrams > 0 {
                                threeMFStatPill(
                                    icon: "clock",
                                    label: "Estimativa",
                                    value: "\(Self.formatPrintDuration(info.estimatedTimeSeconds)) · \(String(format: "%.1fg", info.totalWeightGrams))"
                                )
                            }
                        }

                        // Filaments / Colors Row
                        if !info.filaments.isEmpty {
                            HStack(spacing: 8) {
                                Text("Filamentos:")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(info.filaments) { fil in
                                            HStack(spacing: 5) {
                                                Circle()
                                                    .fill(Self.colorFromHex(fil.colorHex))
                                                    .frame(width: 11, height: 11)
                                                    .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 0.8))
                                                Text("#\(fil.id) \(fil.type.isEmpty ? "PLA" : fil.type)")
                                                    .font(.caption2.weight(.semibold))
                                                if let g = fil.usedGrams, g > 0 {
                                                    Text("(\(String(format: "%.1fg", g)))")
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.secondary.opacity(0.12))
                                            .cornerRadius(5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }

            // 2. Target 3D Printer Selection + Add Custom Printer
            GroupBox(
                label: HStack {
                    Label("Escolha a Impressora 3D de Destino", systemImage: "printer.fill")
                        .font(.headline)
                    Spacer()
                    Button {
                        model.showAddPrinterIn3MFEditor.toggle()
                    } label: {
                        Label(
                            model.showAddPrinterIn3MFEditor ? "Fechar Cadastro" : "Adicionar Novo Modelo de Impressora",
                            systemImage: model.showAddPrinterIn3MFEditor ? "chevron.up.circle" : "plus.circle.fill"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    if model.showAddPrinterIn3MFEditor {
                        let brandModels = Printer3DModel.models(forBrand: settings.newPrinterBrand)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Escolha o Fabricante e o Modelo (ou digite um personalizado):")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Fabricante").font(.caption2).foregroundColor(.secondary)
                                    Picker("", selection: Binding(
                                        get: { settings.newPrinterBrand },
                                        set: { settings.selectManufacturer($0) }
                                    )) {
                                        ForEach(Printer3DModel.manufacturerList, id: \.self) { brand in
                                            Text(brand).tag(brand)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                .frame(width: 155)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Modelo da Impressora").font(.caption2).foregroundColor(.secondary)
                                    Picker("", selection: Binding(
                                        get: { settings.selectedPresetModelID },
                                        set: { settings.selectPresetModel(id: $0) }
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

                            HStack(spacing: 8) {
                                TextField("Nome do Modelo (ex: Anycubic Kobra X)", text: $settings.newPrinterName)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Nome na Roda (ex: Kobra X)", text: $settings.newPrinterShortName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 135)
                            }

                            HStack(spacing: 8) {
                                Text("Mesa (mm):").font(.caption)
                                TextField("X", text: $settings.newPrinterBedWidth)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 56)
                                Text("×")
                                TextField("Y", text: $settings.newPrinterBedDepth)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 56)
                                Text("×")
                                TextField("Z", text: $settings.newPrinterBedHeight)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 56)

                                Picker("Bico:", selection: $settings.newPrinterNozzle) {
                                    Text("0.2mm").tag(0.2)
                                    Text("0.4mm").tag(0.4)
                                    Text("0.6mm").tag(0.6)
                                    Text("0.8mm").tag(0.8)
                                }
                                .frame(width: 120)

                                Spacer()

                                Button("Adicionar Impressora") {
                                    settings.addCustomPrinter3D()
                                    if let newest = settings.printers3D.first {
                                        model.options.target3MFPrinterID = newest.id
                                    }
                                    model.showAddPrinterIn3MFEditor = false
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(red: 0.0, green: 0.898, blue: 1.0))
                                .controlSize(.small)
                                .disabled(settings.newPrinterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(10)
                        .background(Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.08))
                        .cornerRadius(8)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 10)], spacing: 10) {
                        ForEach(settings.printers3D) { printer in
                            let isSelected = (model.options.target3MFPrinterID == printer.id)
                            let isSameAsSource = printer.name.lowercased() == info.currentPrinterModel.lowercased()
                            Button {
                                model.options.target3MFPrinterID = printer.id
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "printer.fill")
                                        .font(.title3)
                                        .foregroundColor(isSelected ? .white : Color(red: 0.0, green: 0.898, blue: 1.0))

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(printer.name)
                                                .font(.caption.weight(.bold))
                                                .lineLimit(1)
                                            if isSameAsSource {
                                                Text("ATUAL")
                                                    .font(.system(size: 8, weight: .heavy))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.white.opacity(0.25))
                                                    .cornerRadius(3)
                                            }
                                        }
                                        Text("\(printer.bedWidthMM)×\(printer.bedDepthMM)×\(printer.bedHeightMM) mm · \(String(format: "%.1f", printer.nozzleDiameterMM))mm")
                                            .font(.system(size: 10, design: .monospaced))
                                            .opacity(isSelected ? 0.92 : 0.72)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected ? Color(red: 0.0, green: 0.898, blue: 1.0) : Color.secondary.opacity(0.10))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(isSelected ? Color(red: 0.0, green: 0.898, blue: 1.0) : Color.primary.opacity(0.10), lineWidth: 1.2)
                                )
                                .foregroundColor(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(8)
            }

            // 3. Preset & Adaptation Options
            GroupBox(label: Label("Opções de Conversão e Otimização", systemImage: "slider.horizontal.3").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Preset de Impressão:", selection: $model.options.threeMFPreset) {
                        ForEach(ThreeMFOptimizationPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    HStack(spacing: 20) {
                        Toggle("Re-centralizar peças automaticamente na mesa da nova impressora", isOn: $model.options.recenter3MFOnBed)
                        Toggle("Preservar cores e filamentos do projeto", isOn: $model.options.preserve3MFFilaments)
                    }
                    .font(.subheadline)
                }
                .padding(8)
            }
        }
    }

    @ViewBuilder
    private func threeMFStatPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
            Text("\(label):")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.10))
        .cornerRadius(5)
    }

    private static func formatPrintDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(max(1, m))m"
    }

    private static func colorFromHex(_ hex: String) -> Color {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count >= 6, let val = Int(cleaned.prefix(6), radix: 16) else {
            return Color(red: 0.0, green: 0.898, blue: 1.0)
        }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - Interactive Visual Crop Canvas View (FlowConverter.CropEditor)

public struct VisualCropCanvasView: View {
    @ObservedObject var model: FileToolOptionsModel

    public init(model: FileToolOptionsModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { geo in
            let canvasSize = geo.size
            ZStack(alignment: .topLeading) {
                // Dark studio backdrop
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.84))

                if let image = model.activeCropImage {
                    let pxSize = model.activeCropPixelSize
                    let fittedRect = Self.aspectFitRect(imageSize: pxSize, in: canvasSize, padding: 18)
                    let sel = model.currentCropSelection
                    let cropRect = CGRect(
                        x: fittedRect.minX + CGFloat(sel.x) * fittedRect.width,
                        y: fittedRect.minY + CGFloat(sel.y) * fittedRect.height,
                        width: max(8, CGFloat(sel.width) * fittedRect.width),
                        height: max(8, CGFloat(sel.height) * fittedRect.height)
                    )

                    // 1. Source Image
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fittedRect.width, height: fittedRect.height)
                        .position(x: fittedRect.midX, y: fittedRect.midY)
                        .gesture(
                            DragGesture(minimumDistance: 2, coordinateSpace: .named("CropCanvasSpace"))
                                .onChanged { value in
                                    handleDrawNewSelection(value: value, fittedRect: fittedRect)
                                }
                                .onEnded { _ in
                                    model.cropDrawOrigin = nil
                                }
                        )

                    // 2. Outside Dimmed Overlay (4 regions around cropRect within fittedRect)
                    outsideDimOverlay(fittedRect: fittedRect, cropRect: cropRect)
                        .allowsHitTesting(false)

                    // 3. Interactive Crop Box (Drag inside to reposition + Rule-of-Thirds Grid + Border)
                    ZStack(alignment: .topLeading) {
                        // Transparent hit surface for dragging/repositioning the crop selection
                        Color.white.opacity(0.001)

                        // Rule of thirds lines
                        Path { path in
                            let w = cropRect.width
                            let h = cropRect.height
                            for i in 1...2 {
                                let x = w * CGFloat(i) / 3.0
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: h))
                                let y = h * CGFloat(i) / 3.0
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: w, y: y))
                            }
                        }
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
                        .allowsHitTesting(false)

                        // Crisp outer border
                        Rectangle()
                            .strokeBorder(Color.white, lineWidth: 1.6)
                            .background(
                                Rectangle().strokeBorder(Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.9), lineWidth: 0.8).padding(-1)
                            )
                            .allowsHitTesting(false)

                        // Live Pixel Size Badge
                        if cropRect.width > 95 && cropRect.height > 34 {
                            Text("\(model.cropWidthPixels) × \(model.cropHeightPixels) px")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.72))
                                .cornerRadius(5)
                                .padding(6)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .help("Crop selection. Drag to reposition.")
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("CropCanvasSpace"))
                            .onChanged { value in
                                handleMoveCrop(value: value, fittedRect: fittedRect)
                            }
                            .onEnded { _ in
                                model.cropMoveOrigin = nil
                            }
                    )

                    // 4. 8 Interactive Resize Handles (Corners & Edges)
                    ForEach(CropResizeHandle.allCases) { handle in
                        let pt = Self.handlePosition(for: handle, in: cropRect)
                        cropHandleView(for: handle)
                            .position(x: pt.x, y: pt.y)
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .named("CropCanvasSpace"))
                                    .onChanged { value in
                                        handleResizeCrop(handle: handle, value: value, fittedRect: fittedRect)
                                    }
                                    .onEnded { _ in
                                        model.cropResizeOrigin = nil
                                    }
                            )
                    }
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading preview…")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .coordinateSpace(name: "CropCanvasSpace")
        }
    }

    @ViewBuilder
    private func outsideDimOverlay(fittedRect: CGRect, cropRect: CGRect) -> some View {
        let dimColor = Color.black.opacity(0.58)
        let topH = max(0, cropRect.minY - fittedRect.minY)
        let botH = max(0, fittedRect.maxY - cropRect.maxY)
        let leftW = max(0, cropRect.minX - fittedRect.minX)
        let rightW = max(0, fittedRect.maxX - cropRect.maxX)

        ZStack(alignment: .topLeading) {
            // Top bar
            if topH > 0 {
                Rectangle()
                    .fill(dimColor)
                    .frame(width: fittedRect.width, height: topH)
                    .position(x: fittedRect.midX, y: fittedRect.minY + topH * 0.5)
            }
            // Bottom bar
            if botH > 0 {
                Rectangle()
                    .fill(dimColor)
                    .frame(width: fittedRect.width, height: botH)
                    .position(x: fittedRect.midX, y: cropRect.maxY + botH * 0.5)
            }
            // Left bar (between top and bottom)
            if leftW > 0 {
                Rectangle()
                    .fill(dimColor)
                    .frame(width: leftW, height: cropRect.height)
                    .position(x: fittedRect.minX + leftW * 0.5, y: cropRect.midY)
            }
            // Right bar (between top and bottom)
            if rightW > 0 {
                Rectangle()
                    .fill(dimColor)
                    .frame(width: rightW, height: cropRect.height)
                    .position(x: cropRect.maxX + rightW * 0.5, y: cropRect.midY)
            }
        }
    }

    @ViewBuilder
    private func cropHandleView(for handle: CropResizeHandle) -> some View {
        let isCorner: Bool = {
            switch handle {
            case .topLeft, .topRight, .bottomLeft, .bottomRight: return true
            default: return false
            }
        }()

        ZStack {
            // Generous invisible hit area
            Color.white.opacity(0.001)
                .frame(width: 24, height: 24)

            if isCorner {
                Circle()
                    .fill(Color(red: 0.0, green: 0.898, blue: 1.0))
                    .frame(width: 13, height: 13)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
            } else if handle == .top || handle == .bottom {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 20, height: 7)
                    .overlay(Capsule().stroke(Color(red: 0.0, green: 0.898, blue: 1.0), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
            } else {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 7, height: 20)
                    .overlay(Capsule().stroke(Color(red: 0.0, green: 0.898, blue: 1.0), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
            }
        }
    }

    private func handleMoveCrop(value: DragGesture.Value, fittedRect: CGRect) {
        guard fittedRect.width > 1, fittedRect.height > 1 else { return }
        if model.cropMoveOrigin == nil {
            model.cropMoveOrigin = model.currentCropSelection
        }
        guard let origin = model.cropMoveOrigin else { return }
        let dx = Double(value.translation.width / fittedRect.width)
        let dy = Double(value.translation.height / fittedRect.height)
        var updated = origin
        updated.x = min(max(origin.x + dx, 0.0), 1.0 - origin.width)
        updated.y = min(max(origin.y + dy, 0.0), 1.0 - origin.height)
        model.currentCropSelection = updated
    }

    private func handleDrawNewSelection(value: DragGesture.Value, fittedRect: CGRect) {
        guard fittedRect.width > 1, fittedRect.height > 1 else { return }
        if model.cropDrawOrigin == nil {
            let startX = min(max(Double((value.startLocation.x - fittedRect.minX) / fittedRect.width), 0.0), 1.0)
            let startY = min(max(Double((value.startLocation.y - fittedRect.minY) / fittedRect.height), 0.0), 1.0)
            model.cropDrawOrigin = CGPoint(x: startX, y: startY)
        }
        guard let start = model.cropDrawOrigin else { return }
        let curX = min(max(Double((value.location.x - fittedRect.minX) / fittedRect.width), 0.0), 1.0)
        let curY = min(max(Double((value.location.y - fittedRect.minY) / fittedRect.height), 0.0), 1.0)

        let minX = min(Double(start.x), curX)
        let minY = min(Double(start.y), curY)
        var width = max(abs(curX - Double(start.x)), 0.02)
        var height = max(abs(curY - Double(start.y)), 0.02)

        if let targetRatio = model.cropAspect.ratio(for: model.activeCropPixelSize), targetRatio > 0 {
            let srcSize = model.activeCropPixelSize
            let normRatio = targetRatio * Double(max(srcSize.height, 1) / max(srcSize.width, 1))
            height = min(width / normRatio, 1.0 - minY)
            width = min(height * normRatio, 1.0 - minX)
        }

        model.currentCropSelection = CropSelection(
            x: min(minX, 1.0 - width),
            y: min(minY, 1.0 - height),
            width: width,
            height: height
        )
    }

    private func handleResizeCrop(handle: CropResizeHandle, value: DragGesture.Value, fittedRect: CGRect) {
        guard fittedRect.width > 1, fittedRect.height > 1 else { return }
        if model.cropResizeOrigin == nil {
            model.cropResizeOrigin = model.currentCropSelection
        }
        guard let origin = model.cropResizeOrigin else { return }

        let dx = Double(value.translation.width / fittedRect.width)
        let dy = Double(value.translation.height / fittedRect.height)
        let minSpan = 0.02

        var left = origin.x
        var top = origin.y
        var right = origin.x + origin.width
        var bottom = origin.y + origin.height

        switch handle {
        case .topLeft:
            left = min(max(origin.x + dx, 0.0), right - minSpan)
            top = min(max(origin.y + dy, 0.0), bottom - minSpan)
        case .top:
            top = min(max(origin.y + dy, 0.0), bottom - minSpan)
        case .topRight:
            right = max(min(origin.x + origin.width + dx, 1.0), left + minSpan)
            top = min(max(origin.y + dy, 0.0), bottom - minSpan)
        case .right:
            right = max(min(origin.x + origin.width + dx, 1.0), left + minSpan)
        case .bottomRight:
            right = max(min(origin.x + origin.width + dx, 1.0), left + minSpan)
            bottom = max(min(origin.y + origin.height + dy, 1.0), top + minSpan)
        case .bottom:
            bottom = max(min(origin.y + origin.height + dy, 1.0), top + minSpan)
        case .bottomLeft:
            left = min(max(origin.x + dx, 0.0), right - minSpan)
            bottom = max(min(origin.y + origin.height + dy, 1.0), top + minSpan)
        case .left:
            left = min(max(origin.x + dx, 0.0), right - minSpan)
        }

        var w = right - left
        var h = bottom - top

        // Apply aspect ratio constraint if active
        if let targetRatio = model.cropAspect.ratio(for: model.activeCropPixelSize), targetRatio > 0 {
            let srcSize = model.activeCropPixelSize
            let normRatio = targetRatio * Double(max(srcSize.height, 1) / max(srcSize.width, 1))
            if handle == .top || handle == .bottom {
                w = min(h * normRatio, 1.0)
                let centerX = (left + right) * 0.5
                left = min(max(centerX - w * 0.5, 0.0), 1.0 - w)
            } else {
                h = min(w / normRatio, 1.0)
                if handle == .topLeft || handle == .topRight {
                    top = max(bottom - h, 0.0)
                    h = bottom - top
                    w = h * normRatio
                    if handle == .topLeft {
                        left = right - w
                    }
                } else if handle == .left || handle == .right {
                    let centerY = (top + bottom) * 0.5
                    top = min(max(centerY - h * 0.5, 0.0), 1.0 - h)
                }
            }
        }

        model.currentCropSelection = CropSelection(x: left, y: top, width: w, height: h)
    }

    public static func aspectFitRect(imageSize: CGSize, in containerSize: CGSize, padding: CGFloat) -> CGRect {
        let availW = max(containerSize.width - padding * 2, 10)
        let availH = max(containerSize.height - padding * 2, 10)
        let imgW = max(imageSize.width, 1)
        let imgH = max(imageSize.height, 1)
        let scale = min(availW / imgW, availH / imgH)
        let fitW = imgW * scale
        let fitH = imgH * scale
        let x = (containerSize.width - fitW) * 0.5
        let y = (containerSize.height - fitH) * 0.5
        return CGRect(x: x, y: y, width: fitW, height: fitH)
    }

    public static func handlePosition(for handle: CropResizeHandle, in rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .top: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .right: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .bottom: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .left: return CGPoint(x: rect.minX, y: rect.midY)
        }
    }
}

// MARK: - Interactive Audio Waveform Trim View (Two Sliding Vertical Bars)

public struct AudioWaveformTrimView: View {
    @ObservedObject var model: FileToolOptionsModel

    public init(model: FileToolOptionsModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { geo in
            let totalW = max(geo.size.width, 100)
            let totalH = max(geo.size.height, 80)
            let handleWidth: CGFloat = 14
            let trackInset: CGFloat = handleWidth
            let trackW = max(totalW - trackInset * 2, 40)
            let duration = max(model.mediaDuration, 0.2)

            let startRatio = CGFloat(min(max(model.options.trimStartSeconds / duration, 0.0), 1.0))
            let endRatio = CGFloat(min(max(model.trimEndSeconds / duration, 0.0), 1.0))
            let playheadRatio = CGFloat(min(max(model.audioPlaybackTime / duration, 0.0), 1.0))

            let startX = trackInset + startRatio * trackW
            let endX = trackInset + endRatio * trackW
            let playheadX = trackInset + playheadRatio * trackW
            let selectedW = max(2, endX - startX)

            ZStack(alignment: .topLeading) {
                // 1. Rectangular Dark Track Container
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                // Center horizontal zero-axis guide line
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: trackW, height: 1)
                    .position(x: totalW * 0.5, y: totalH * 0.5)

                // 2. Audio Waveform Bars
                if model.isLoadingWaveform && model.audioWaveform.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Loading waveform…")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let samples = model.audioWaveform.isEmpty ? FileToolOptionsModel.syntheticWaveform(count: 120) : model.audioWaveform
                    let count = max(samples.count, 1)
                    let spacing: CGFloat = 2.0
                    let barW = max(1.8, (trackW - CGFloat(count - 1) * spacing) / CGFloat(count))

                    HStack(alignment: .center, spacing: spacing) {
                        ForEach(0..<count, id: \.self) { idx in
                            let barRatio = (CGFloat(idx) + 0.5) / CGFloat(count)
                            let isInside = (barRatio >= startRatio && barRatio <= endRatio)
                            let amp = CGFloat(samples[idx])
                            let barH = max(5, amp * (totalH - 36))

                            Capsule()
                                .fill(
                                    isInside
                                        ? LinearGradient(
                                            colors: [Color(red: 0.0, green: 0.898, blue: 1.0), Color(red: 1.0, green: 0.36, blue: 0.05)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(
                                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.14)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                                .frame(width: barW, height: barH)
                        }
                    }
                    .frame(width: trackW, height: totalH)
                    .position(x: totalW * 0.5, y: totalH * 0.5)
                }

                // 3. Dimmed Masks Outside Selected Range (Left & Right)
                if startX > trackInset {
                    let leftMaskW = startX - trackInset
                    Rectangle()
                        .fill(Color.black.opacity(0.48))
                        .frame(width: leftMaskW, height: totalH - 4)
                        .position(x: trackInset + leftMaskW * 0.5, y: totalH * 0.5)
                        .allowsHitTesting(false)
                }
                if endX < trackInset + trackW {
                    let rightMaskW = (trackInset + trackW) - endX
                    Rectangle()
                        .fill(Color.black.opacity(0.48))
                        .frame(width: rightMaskW, height: totalH - 4)
                        .position(x: endX + rightMaskW * 0.5, y: totalH * 0.5)
                        .allowsHitTesting(false)
                }

                // 4. Selected Window Interior (Tint + Top/Bottom Orange Rails + Drag to Slide Window)
                ZStack {
                    Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.08)

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(red: 0.0, green: 0.898, blue: 1.0))
                            .frame(height: 3.5)
                        Spacer()
                        Rectangle()
                            .fill(Color(red: 0.0, green: 0.898, blue: 1.0))
                            .frame(height: 3.5)
                    }
                }
                .frame(width: selectedW, height: totalH - 6)
                .position(x: startX + selectedW * 0.5, y: totalH * 0.5)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("AudioTrimTrackSpace"))
                        .onChanged { value in
                            if model.trimRangeDragOrigin == nil {
                                model.trimRangeDragOrigin = (model.options.trimStartSeconds, model.trimEndSeconds)
                            }
                            guard let orig = model.trimRangeDragOrigin else { return }
                            let deltaSec = Double(value.translation.width / trackW) * duration
                            let span = orig.end - orig.start
                            let newStart = min(max(0.0, orig.start + deltaSec), max(0.0, duration - span))
                            model.options.trimStartSeconds = newStart
                            model.options.trimDurationSeconds = span
                            model.audioPlaybackTime = newStart
                        }
                        .onEnded { _ in
                            model.trimRangeDragOrigin = nil
                        }
                )

                // 5. Playhead Vertical Indicator Bar
                if playheadX >= startX && playheadX <= endX {
                    ZStack(alignment: .top) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: totalH - 12)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                    .position(x: playheadX, y: totalH * 0.5)
                    .allowsHitTesting(false)
                }

                // 6. LEFT SLIDING VERTICAL BAR (Start Handle)
                verticalTrimBar(
                    isLeading: true,
                    timeText: FileToolOptionsModel.formatTime(model.options.trimStartSeconds),
                    height: totalH - 6,
                    handleWidth: handleWidth
                )
                .position(x: startX - handleWidth * 0.5, y: totalH * 0.5)
                .help("Drag left or right to set the new audio start time")
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("AudioTrimTrackSpace"))
                        .onChanged { value in
                            if model.trimStartDragOrigin == nil {
                                model.trimStartDragOrigin = model.options.trimStartSeconds
                            }
                            guard let origStart = model.trimStartDragOrigin else { return }
                            let deltaSec = Double(value.translation.width / trackW) * duration
                            model.setTrimStart(origStart + deltaSec)
                        }
                        .onEnded { _ in
                            model.trimStartDragOrigin = nil
                        }
                )

                // 7. RIGHT SLIDING VERTICAL BAR (End Handle)
                verticalTrimBar(
                    isLeading: false,
                    timeText: FileToolOptionsModel.formatTime(model.trimEndSeconds),
                    height: totalH - 6,
                    handleWidth: handleWidth
                )
                .position(x: endX + handleWidth * 0.5, y: totalH * 0.5)
                .help("Drag left or right to set the new audio end time")
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("AudioTrimTrackSpace"))
                        .onChanged { value in
                            if model.trimEndDragOrigin == nil {
                                model.trimEndDragOrigin = model.trimEndSeconds
                            }
                            guard let origEnd = model.trimEndDragOrigin else { return }
                            let deltaSec = Double(value.translation.width / trackW) * duration
                            model.setTrimEnd(origEnd + deltaSec)
                        }
                        .onEnded { _ in
                            model.trimEndDragOrigin = nil
                        }
                )
            }
            .coordinateSpace(name: "AudioTrimTrackSpace")
        }
    }

    @ViewBuilder
    private func verticalTrimBar(isLeading: Bool, timeText: String, height: CGFloat, handleWidth: CGFloat) -> some View {
        ZStack {
            // Generous hit area for easy grabbing
            Color.white.opacity(0.001)
                .frame(width: 28, height: height)

            // Vertical Orange Bar
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(red: 0.0, green: 0.898, blue: 1.0))
                .frame(width: handleWidth, height: height)
                .shadow(color: .black.opacity(0.45), radius: 3, x: 0, y: 1)
                .overlay(
                    // Double vertical grip lines in the center of the bar
                    HStack(spacing: 2.5) {
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 1.6, height: 24)
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 1.6, height: 24)
                    }
                )

            // Time badge pill at top/bottom of the bar
            VStack {
                if isLeading {
                    Text(timeText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.78))
                        .cornerRadius(4)
                        .offset(x: 24, y: 6)
                    Spacer()
                } else {
                    Spacer()
                    Text(timeText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.78))
                        .cornerRadius(4)
                        .offset(x: -24, y: -6)
                }
            }
            .frame(height: height)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Interactive Visual Redaction Canvas View (FlowConverter.RedactionEditor)

public struct VisualRedactionCanvasView: View {
    @ObservedObject var model: FileToolOptionsModel

    public init(model: FileToolOptionsModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { geo in
            let canvasSize = geo.size
            ZStack(alignment: .topLeading) {
                // Dark studio backdrop
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.86))

                if let image = model.activeCropImage {
                    let pxSize = model.activeCropPixelSize
                    let fittedRect = VisualCropCanvasView.aspectFitRect(imageSize: pxSize, in: canvasSize, padding: 18)

                    // 1. Base Video Frame / Photo (Drag on empty space to draw a new redaction box)
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: fittedRect.width, height: fittedRect.height)
                        .position(x: fittedRect.midX, y: fittedRect.midY)
                        .gesture(
                            DragGesture(minimumDistance: 3, coordinateSpace: .named("RedactionCanvasSpace"))
                                .onChanged { value in
                                    handleDrawNewBox(value: value, fittedRect: fittedRect)
                                }
                                .onEnded { _ in
                                    model.redactionDrawOrigin = nil
                                }
                        )

                    // 2. Redaction Boxes Overlay
                    ForEach(Array(model.options.redactions.enumerated()), id: \.element.id) { idx, rect in
                        let isSelected = (rect.id == model.selectedRedactionID) || (model.selectedRedactionID == nil && idx == 0)
                        let isVisibleAtTime: Bool = {
                            guard model.tool == .redactVideo, let tr = rect.timeRange else { return true }
                            return model.redactionPreviewTime >= tr.start && model.redactionPreviewTime <= tr.end
                        }()

                        let boxRect = CGRect(
                            x: fittedRect.minX + CGFloat(rect.x) * fittedRect.width,
                            y: fittedRect.minY + CGFloat(rect.y) * fittedRect.height,
                            width: max(10, CGFloat(rect.width) * fittedRect.width),
                            height: max(10, CGFloat(rect.height) * fittedRect.height)
                        )

                        // Box Interior (Solid Black or Live Gaussian Blur Preview)
                        ZStack(alignment: .topLeading) {
                            if isVisibleAtTime {
                                if model.options.redactionStyle == .solid {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.96))
                                } else {
                                    // Live Blur preview of the underlying image region
                                    Image(nsImage: image)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: fittedRect.width, height: fittedRect.height)
                                        .blur(radius: 14)
                                        .offset(
                                            x: fittedRect.minX - boxRect.minX,
                                            y: fittedRect.minY - boxRect.minY
                                        )
                                        .frame(width: boxRect.width, height: boxRect.height, alignment: .topLeading)
                                        .clipped()
                                        .overlay(Color.white.opacity(0.08))
                                }
                            } else {
                                // Inactive at current video timestamp: subtle hatch tint
                                Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.10)
                            }

                            // Selection / Box Border
                            Rectangle()
                                .strokeBorder(
                                    isSelected ? Color(red: 0.0, green: 0.898, blue: 1.0) : Color.white.opacity(0.75),
                                    style: StrokeStyle(
                                        lineWidth: isSelected ? 2.2 : 1.2,
                                        dash: isVisibleAtTime ? [] : [5, 4]
                                    )
                                )

                            // Box Badge Label (#1, #2, etc.)
                            HStack(spacing: 4) {
                                Text("#\(idx + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                if !isVisibleAtTime {
                                    Text("hidden at current time")
                                        .font(.system(size: 9, weight: .medium))
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color(red: 0.0, green: 0.898, blue: 1.0).opacity(0.92) : Color.black.opacity(0.72))
                            .cornerRadius(4)
                            .padding(4)
                        }
                        .frame(width: boxRect.width, height: boxRect.height)
                        .position(x: boxRect.midX, y: boxRect.midY)
                        .help("Redaction Box #\(idx + 1). Drag to move, or drag handles to resize.")
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("RedactionCanvasSpace"))
                                .onChanged { value in
                                    model.selectedRedactionID = rect.id
                                    handleMoveBox(boxID: rect.id, value: value, fittedRect: fittedRect)
                                }
                                .onEnded { _ in
                                    model.redactionMoveOrigin = nil
                                }
                        )

                        // 3. 8 Resize Handles for the Selected Box
                        if isSelected {
                            ForEach(CropResizeHandle.allCases) { handle in
                                let pt = VisualCropCanvasView.handlePosition(for: handle, in: boxRect)
                                redactionHandleView(for: handle)
                                    .position(x: pt.x, y: pt.y)
                                    .gesture(
                                        DragGesture(minimumDistance: 0, coordinateSpace: .named("RedactionCanvasSpace"))
                                            .onChanged { value in
                                                handleResizeBox(boxID: rect.id, handle: handle, value: value, fittedRect: fittedRect)
                                            }
                                            .onEnded { _ in
                                                model.redactionResizeOrigin = nil
                                            }
                                    )
                            }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading preview…")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .coordinateSpace(name: "RedactionCanvasSpace")
        }
    }

    @ViewBuilder
    private func redactionHandleView(for handle: CropResizeHandle) -> some View {
        let isCorner: Bool = {
            switch handle {
            case .topLeft, .topRight, .bottomLeft, .bottomRight: return true
            default: return false
            }
        }()

        ZStack {
            Color.white.opacity(0.001)
                .frame(width: 24, height: 24)

            if isCorner {
                Circle()
                    .fill(Color(red: 0.0, green: 0.898, blue: 1.0))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
            } else if handle == .top || handle == .bottom {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 18, height: 6)
                    .overlay(Capsule().stroke(Color(red: 0.0, green: 0.898, blue: 1.0), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
            } else {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 6, height: 18)
                    .overlay(Capsule().stroke(Color(red: 0.0, green: 0.898, blue: 1.0), lineWidth: 1.2))
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
            }
        }
    }

    private func handleMoveBox(boxID: UUID, value: DragGesture.Value, fittedRect: CGRect) {
        guard fittedRect.width > 1, fittedRect.height > 1,
              let idx = model.options.redactions.firstIndex(where: { $0.id == boxID }) else { return }

        if model.redactionMoveOrigin == nil {
            model.redactionMoveOrigin = model.options.redactions[idx]
        }
        guard let origin = model.redactionMoveOrigin else { return }

        let dx = Double(value.translation.width / fittedRect.width)
        let dy = Double(value.translation.height / fittedRect.height)

        var updated = model.options.redactions[idx]
        updated.x = min(max(origin.x + dx, 0.0), 1.0 - origin.width)
        updated.y = min(max(origin.y + dy, 0.0), 1.0 - origin.height)
        model.options.redactions[idx] = updated
    }

    private func handleResizeBox(boxID: UUID, handle: CropResizeHandle, value: DragGesture.Value, fittedRect: CGRect) {
        guard fittedRect.width > 1, fittedRect.height > 1,
              let idx = model.options.redactions.firstIndex(where: { $0.id == boxID }) else { return }

        if model.redactionResizeOrigin == nil {
            model.redactionResizeOrigin = model.options.redactions[idx]
        }
        guard let origin = model.redactionResizeOrigin else { return }

        let dx = Double(value.translation.width / fittedRect.width)
        let dy = Double(value.translation.height / fittedRect.height)
        let minSpan = 0.02

        var left = origin.x
        var top = origin.y
        var right = origin.x + origin.width
        var bottom = origin.y + origin.height

        switch handle {
        case .topLeft:
            left = min(max(origin.x + dx, 0.0), right - minSpan)
            top = min(max(origin.y + dy, 0.0), bottom - minSpan)
        case .top:
            top = min(max(origin.y + dy, 0.0), bottom - minSpan)
        case .topRight:
            right = max(min(origin.x + origin.width + dx, 1.0), left + minSpan)
            top = min(max(origin.y + dy, 0.0), bottom - minSpan)
        case .right:
            right = max(min(origin.x + origin.width + dx, 1.0), left + minSpan)
        case .bottomRight:
            right = max(min(origin.x + origin.width + dx, 1.0), left + minSpan)
            bottom = max(min(origin.y + origin.height + dy, 1.0), top + minSpan)
        case .bottom:
            bottom = max(min(origin.y + origin.height + dy, 1.0), top + minSpan)
        case .bottomLeft:
            left = min(max(origin.x + dx, 0.0), right - minSpan)
            bottom = max(min(origin.y + origin.height + dy, 1.0), top + minSpan)
        case .left:
            left = min(max(origin.x + dx, 0.0), right - minSpan)
        }

        var updated = model.options.redactions[idx]
        updated.x = left
        updated.y = top
        updated.width = max(minSpan, right - left)
        updated.height = max(minSpan, bottom - top)
        model.options.redactions[idx] = updated
    }

    private func handleDrawNewBox(value: DragGesture.Value, fittedRect: CGRect) {
        guard fittedRect.width > 1, fittedRect.height > 1 else { return }

        if model.redactionDrawOrigin == nil {
            let startX = min(max(Double((value.startLocation.x - fittedRect.minX) / fittedRect.width), 0.0), 1.0)
            let startY = min(max(Double((value.startLocation.y - fittedRect.minY) / fittedRect.height), 0.0), 1.0)
            model.redactionDrawOrigin = CGPoint(x: startX, y: startY)

            let newRect = RedactionRectangle(
                x: startX,
                y: startY,
                width: 0.02,
                height: 0.02,
                timeRange: nil
            )
            model.options.redactions.append(newRect)
            model.selectedRedactionID = newRect.id
        }

        guard let start = model.redactionDrawOrigin,
              let selID = model.selectedRedactionID,
              let idx = model.options.redactions.firstIndex(where: { $0.id == selID }) else { return }

        let curX = min(max(Double((value.location.x - fittedRect.minX) / fittedRect.width), 0.0), 1.0)
        let curY = min(max(Double((value.location.y - fittedRect.minY) / fittedRect.height), 0.0), 1.0)

        let minX = min(Double(start.x), curX)
        let minY = min(Double(start.y), curY)
        let width = min(max(abs(curX - Double(start.x)), 0.02), 1.0 - minX)
        let height = min(max(abs(curY - Double(start.y)), 0.02), 1.0 - minY)

        var updated = model.options.redactions[idx]
        updated.x = minX
        updated.y = minY
        updated.width = width
        updated.height = height
        model.options.redactions[idx] = updated
    }
}
