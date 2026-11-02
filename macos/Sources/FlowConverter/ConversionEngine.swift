import Foundation
import AppKit
import SwiftUI
import ImageIO
import PDFKit
import AVFoundation
import UniformTypeIdentifiers
import WebKit

// MARK: - Unique Output URL Helper

public enum UniqueOutputURL {
    public static func writableDirectory(preferring directory: URL) -> URL {
        let probe = directory.appendingPathComponent(".flowconverter_write_probe_\(UUID().uuidString)")
        if (try? Data().write(to: probe)) != nil {
            try? FileManager.default.removeItem(at: probe)
            return directory
        }
        let fallback = URL(fileURLWithPath: "/Users/vander/DEV/Clone Tagerine/Converted")
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    public static func make(in directory: URL, baseName: String, ext: String) -> URL {
        let targetDir = writableDirectory(preferring: directory)
        let cleanBase = baseName.isEmpty ? "Converted" : baseName
        let suffixExt = ext.isEmpty ? "" : ".\(ext)"
        var candidate = targetDir.appendingPathComponent("\(cleanBase)\(suffixExt)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = targetDir.appendingPathComponent("\(cleanBase) \(counter)\(suffixExt)")
            counter += 1
        }
        return candidate
    }
}

// MARK: - Bundled Resource & Binary Locator

public enum BundledResources {
    public static var resourceRoot: URL {
        if let res = Bundle.main.resourceURL {
            return res
        }
        return URL(fileURLWithPath: "/Users/vander/DEV/Clone Tagerine/FlowConverter/macos/Resources")
    }

    public static var ffmpegPath: String {
        let bundled = resourceRoot.appendingPathComponent("Tools/ffmpeg").path
        if FileManager.default.isExecutableFile(atPath: bundled) { return bundled }
        if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/ffmpeg") { return "/opt/homebrew/bin/ffmpeg" }
        return "/usr/local/bin/ffmpeg"
    }

    public static var cwebpPath: String {
        let bundled = resourceRoot.appendingPathComponent("Tools/cwebp").path
        if FileManager.default.isExecutableFile(atPath: bundled) { return bundled }
        if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/cwebp") { return "/opt/homebrew/bin/cwebp" }
        return "/usr/local/bin/cwebp"
    }

    public static var officeConverterScriptPath: String {
        return resourceRoot.appendingPathComponent("Scripts/flow_office_converter.py").path
    }
}

// MARK: - Operation Progress Controller & Window

public final class OperationProgressWindowController: NSWindowController {
    @Published public var titleText: String = "Operation in progress"
    @Published public var statusText: String = "Preparing…"
    @Published public var progress: Double = 0.0
    @Published public var isFinished: Bool = false
    @Published public var errors: [String] = []
    public var savedOutputs: [URL] = []
    public var onClose: (() -> Void)?

    public init(title: String, itemCount: Int) {
        self.titleText = title
        self.statusText = "Processing \(itemCount) \(itemCount == 1 ? "item" : "items")…"
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 150),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Flow Converter"
        panel.level = .floating
        panel.center()
        super.init(window: panel)

        let view = OperationProgressView(controller: self)
        panel.contentView = NSHostingView(rootView: view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func show() {
        window?.orderFrontRegardless()
    }

    public func update(progress: Double, status: String) {
        DispatchQueue.main.async {
            self.progress = min(max(progress, 0.0), 1.0)
            self.statusText = status
        }
    }

    public func finish(outputs: [URL], failures: [String]) {
        DispatchQueue.main.async {
            self.savedOutputs = outputs
            self.errors = failures
            self.progress = 1.0
            self.isFinished = true
            if failures.isEmpty {
                self.titleText = "Completed!"
                self.statusText = "Saved \(outputs.count) \(outputs.count == 1 ? "file" : "files")."
                if !outputs.isEmpty {
                    NSWorkspace.shared.activateFileViewerSelecting(outputs)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                    self?.close()
                    self?.onClose?()
                }
            } else {
                self.titleText = outputs.isEmpty ? "Operation failed!" : "Finished with errors"
                self.statusText = failures.joined(separator: "\n")
            }
        }
    }
}

private struct OperationProgressView: View {
    @ObservedObject var controller: OperationProgressWindowController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: controller.isFinished ? (controller.errors.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill") : "arrow.triangle.2.circlepath")
                    .foregroundColor(Color(red: 0.0, green: 0.898, blue: 1.0))
                    .font(.title2)
                Text(controller.titleText)
                    .font(.headline)
                Spacer()
            }

            ProgressView(value: controller.progress, total: 1.0)
                .tint(Color(red: 0.0, green: 0.898, blue: 1.0))

            Text(controller.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            if controller.isFinished && !controller.errors.isEmpty {
                HStack {
                    Spacer()
                    Button("Close") {
                        controller.close()
                        controller.onClose?()
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 380)
    }
}

extension OperationProgressWindowController: ObservableObject {}

// MARK: - Universal Conversion Engine

public final class UniversalConverter {
    public static let shared = UniversalConverter()

    public init() {}

    public func convertBatch(urls: [URL], to targetFormat: ConversionFormat, taskStore: ConversionTaskStore) {
        let progressWC = OperationProgressWindowController(
            title: "Converting to \(targetFormat.displayName)",
            itemCount: urls.count
        )
        progressWC.show()

        let options = FlowConverterSettingsModel.shared.options(for: targetFormat)

        DispatchQueue.global(qos: .userInitiated).async {
            var outputs: [URL] = []
            var failures: [String] = []

            // When targetFormat is an archive (.zip, .tar, .gz) and the user dropped multiple files or a non-archive file/folder,
            // pack all dropped items together into a single archive file!
            let allInputsAreArchives = !urls.isEmpty && urls.allSatisfy { ConversionFormat.detect(from: $0)?.group == .archives }
            if targetFormat.group == .archives && (urls.count > 1 || !allInputsAreArchives) {
                let taskID = taskStore.addTask(sourceName: urls.first?.lastPathComponent ?? "Archive", targetTitle: targetFormat.displayName)
                progressWC.update(progress: 0.3, status: "Packing \(urls.count) \(urls.count == 1 ? "item" : "items") into \(targetFormat.displayName)…")
                do {
                    let outURL = try ArchiveConverter.packItems(urls: urls, targetFormat: targetFormat)
                    outputs.append(outURL)
                    UnlockStore.shared.recordUsage(count: 1)
                } catch {
                    failures.append(error.localizedDescription)
                }
                taskStore.removeTask(id: taskID)
                progressWC.finish(outputs: outputs, failures: failures)
                return
            }

            for (idx, srcURL) in urls.enumerated() {
                let taskID = taskStore.addTask(sourceName: srcURL.lastPathComponent, targetTitle: targetFormat.displayName)
                progressWC.update(
                    progress: Double(idx) / Double(max(urls.count, 1)),
                    status: "\(srcURL.lastPathComponent) → \(targetFormat.displayName)"
                )

                do {
                    let outURL = try self.convertSingleFile(srcURL: srcURL, to: targetFormat, options: options) { itemProg in
                        let overall = (Double(idx) + itemProg) / Double(max(urls.count, 1))
                        progressWC.update(progress: overall, status: "\(srcURL.lastPathComponent) → \(targetFormat.displayName)")
                    }
                    outputs.append(outURL)
                    UnlockStore.shared.recordUsage(count: 1)
                } catch {
                    failures.append("\(srcURL.lastPathComponent): \(error.localizedDescription)")
                }

                taskStore.removeTask(id: taskID)
            }

            progressWC.finish(outputs: outputs, failures: failures)
        }
    }

    public func convertSingleFile(
        srcURL: URL,
        to targetFormat: ConversionFormat,
        options: ConversionOptions,
        onProgress: ((Double) -> Void)? = nil
    ) throws -> URL {
        let dir = srcURL.deletingLastPathComponent()
        let baseName = srcURL.deletingPathExtension().lastPathComponent
        let outURL = UniqueOutputURL.make(in: dir, baseName: baseName, ext: targetFormat.fileExtension)

        let srcFormat = ConversionFormat.detect(from: srcURL)

        // 1. Subtitle Conversions (.srt <-> .vtt)
        if targetFormat == .srt || targetFormat == .vtt {
            try SubtitleConverter.convert(from: srcURL, to: outURL, targetFormat: targetFormat)
            return outURL
        }

        // 2. Archive Conversions (.zip, .tar, .gz)
        if targetFormat.group == .archives {
            try ArchiveConverter.convert(from: srcURL, to: outURL, targetFormat: targetFormat)
            return outURL
        }

        // 3. Spreadsheet Conversions (.xlsx, .xls, .ods, .csv, .tsv, .pdf)
        if srcFormat?.group == .spreadsheets || targetFormat.group == .spreadsheets {
            try runOfficeConverter(srcURL: srcURL, outURL: outURL, targetFormat: targetFormat, onProgress: onProgress)
            return outURL
        }

        // 4. Presentation Conversions (.ppt, .pptx <-> .pdf)
        if srcFormat == .ppt || srcFormat == .pptx || targetFormat == .ppt || targetFormat == .pptx {
            try runOfficeConverter(srcURL: srcURL, outURL: outURL, targetFormat: targetFormat, onProgress: onProgress)
            return outURL
        }

        // 5. Image to PDF or Image to Image
        if srcFormat?.group == .images {
            if targetFormat == .pdf {
                try convertImageToPDF(srcURL: srcURL, outURL: outURL)
                return outURL
            }
            if targetFormat == .webp {
                try convertImageToWebP(srcURL: srcURL, outURL: outURL, options: options)
                return outURL
            }
            if targetFormat.group == .images || targetFormat == .gif {
                try convertImageWithImageIOOrFFmpeg(srcURL: srcURL, outURL: outURL, targetFormat: targetFormat, options: options)
                return outURL
            }
        }

        // 6. PDF to Image / Text / Markdown / RTF / HTML / DOCX
        if srcFormat == .pdf {
            switch targetFormat {
            case .png, .jpg, .tiff, .webp, .heic:
                try renderPDFFirstPageToImage(srcURL: srcURL, outURL: outURL, targetFormat: targetFormat, options: options)
                return outURL
            case .txt, .md, .html, .rtf, .docx:
                try convertPDFToDocument(srcURL: srcURL, outURL: outURL, targetFormat: targetFormat)
                return outURL
            default:
                break
            }
        }

        // 7. Text / Markdown / RTF / HTML / DOCX conversions via NSAttributedString / PDFKit
        if srcFormat?.group == .documents && (targetFormat.group == .documents) {
            try convertDocumentViaAttributedString(srcURL: srcURL, outURL: outURL, targetFormat: targetFormat)
            return outURL
        }

        // 8. Audio & Video conversions via bundled FFmpeg
        if targetFormat.group == .audio || targetFormat.group == .video || srcFormat?.group == .video || srcFormat?.group == .audio {
            try convertMediaWithFFmpeg(srcURL: srcURL, outURL: outURL, targetFormat: targetFormat, options: options, onProgress: onProgress)
            return outURL
        }

        throw ConversionError.unsupportedPair(srcURL.pathExtension.uppercased(), targetFormat.displayName)
    }

    // MARK: - Image Conversions

    private func convertImageToPDF(srcURL: URL, outURL: URL) throws {
        guard let image = NSImage(contentsOf: srcURL),
              let page = PDFPage(image: image) else {
            throw ConversionError.sourceCannotBeRead
        }
        let pdf = PDFDocument()
        pdf.insert(page, at: 0)
        guard pdf.write(to: outURL) else {
            throw ConversionError.encodingFailed("Could not create the PDF.")
        }
    }

    private func convertImageToWebP(srcURL: URL, outURL: URL, options: ConversionOptions) throws {
        let q: String
        switch options.quality {
        case .compact: q = "65"
        case .balanced: q = "82"
        case .high: q = "94"
        }
        try ProcessRunner.run(executable: BundledResources.cwebpPath, arguments: ["-q", q, srcURL.path, "-o", outURL.path])
    }

    private func convertImageWithImageIOOrFFmpeg(srcURL: URL, outURL: URL, targetFormat: ConversionFormat, options: ConversionOptions) throws {
        let utType: CFString? = {
            switch targetFormat {
            case .jpg: return UTType.jpeg.identifier as CFString
            case .png: return UTType.png.identifier as CFString
            case .heic: return UTType.heic.identifier as CFString
            case .tiff: return UTType.tiff.identifier as CFString
            case .bmp: return UTType.bmp.identifier as CFString
            case .gif: return UTType.gif.identifier as CFString
            default: return nil
            }
        }()

        let qualityVal: Double = {
            switch options.quality {
            case .compact: return 0.65
            case .balanced: return 0.82
            case .high: return 0.95
            }
        }()

        if let utType = utType,
           let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
           let cgImg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            if let dst = CGImageDestinationCreateWithURL(outURL as CFURL, utType, 1, nil) {
                var props: [CFString: Any] = [:]
                if targetFormat == .jpg || targetFormat == .heic {
                    props[kCGImageDestinationLossyCompressionQuality] = qualityVal
                }
                if options.preserveMetadata && targetFormat != .bmp && targetFormat != .gif,
                   let meta = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
                    for (k, v) in meta { props[k] = v }
                }
                CGImageDestinationAddImage(dst, cgImg, props as CFDictionary)
                if CGImageDestinationFinalize(dst) {
                    return
                }
            }

            // Fallback to NSBitmapImageRep for standard raster formats (BMP, PNG, JPEG, TIFF, GIF)
            let bitmapType: NSBitmapImageRep.FileType? = {
                switch targetFormat {
                case .bmp: return .bmp
                case .png: return .png
                case .jpg: return .jpeg
                case .tiff: return .tiff
                case .gif: return .gif
                default: return nil
                }
            }()
            if let bitmapType = bitmapType {
                let rep = NSBitmapImageRep(cgImage: cgImg)
                let repProps: [NSBitmapImageRep.PropertyKey: Any] = targetFormat == .jpg ? [.compressionFactor: qualityVal] : [:]
                if let data = rep.representation(using: bitmapType, properties: repProps) {
                    try data.write(to: outURL, options: .atomic)
                    return
                }
            }
        }

        // Fallback to ffmpeg (supports AVIF, SVG raster, animated GIF, etc.)
        try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: ["-y", "-i", srcURL.path, outURL.path])
    }

    private func renderPDFFirstPageToImage(srcURL: URL, outURL: URL, targetFormat: ConversionFormat, options: ConversionOptions) throws {
        guard let pdf = PDFDocument(url: srcURL), let page = pdf.page(at: 0) else {
            throw ConversionError.encodingFailed("The PDF cannot be read or is password-protected.")
        }
        let rect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let img = page.thumbnail(of: NSSize(width: rect.width * scale, height: rect.height * scale), for: .mediaBox)
        let tempPNG = FileManager.default.temporaryDirectory.appendingPathComponent("flowconverter-pdf-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempPNG) }
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            throw ConversionError.encodingFailed("A PDF page could not be rendered.")
        }
        try pngData.write(to: tempPNG)
        if targetFormat == .png {
            try FileManager.default.copyItem(at: tempPNG, to: outURL)
        } else if targetFormat == .webp {
            try convertImageToWebP(srcURL: tempPNG, outURL: outURL, options: options)
        } else {
            try convertImageWithImageIOOrFFmpeg(srcURL: tempPNG, outURL: outURL, targetFormat: targetFormat, options: options)
        }
    }

    // MARK: - Document Conversions

    private func convertPDFToDocument(srcURL: URL, outURL: URL, targetFormat: ConversionFormat) throws {
        guard let pdf = PDFDocument(url: srcURL) else {
            throw ConversionError.encodingFailed("The PDF cannot be read or is password-protected.")
        }
        let fullText = pdf.string ?? ""
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConversionError.encodingFailed("This PDF has no selectable text. Scanned pages need OCR before text can be exported.")
        }

        switch targetFormat {
        case .txt, .md:
            try fullText.write(to: outURL, atomically: true, encoding: .utf8)
        case .html:
            let escaped = fullText
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .components(separatedBy: "\n\n")
                .map { "<p>\($0.replacingOccurrences(of: "\n", with: "<br/>"))</p>" }
                .joined(separator: "\n")
            let html = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"/><title>\(srcURL.deletingPathExtension().lastPathComponent)</title><style>body{font:12pt Arial,sans-serif;line-height:1.4;margin:2em;}</style></head><body>\(escaped)</body></html>"
            try html.write(to: outURL, atomically: true, encoding: .utf8)
        case .rtf, .docx:
            let attr = NSAttributedString(string: fullText, attributes: [
                .font: NSFont.systemFont(ofSize: 12)
            ])
            let docType: NSAttributedString.DocumentType = (targetFormat == .docx) ? .officeOpenXML : .rtf
            let data = try attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: docType])
            try data.write(to: outURL)
        default:
            throw ConversionError.unsupportedPair("PDF", targetFormat.displayName)
        }
    }

    private func convertDocumentViaAttributedString(srcURL: URL, outURL: URL, targetFormat: ConversionFormat) throws {
        let attr = try NSAttributedString(url: srcURL, options: [:], documentAttributes: nil)
        switch targetFormat {
        case .txt, .md:
            try attr.string.write(to: outURL, atomically: true, encoding: .utf8)
        case .rtf:
            let data = try attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            try data.write(to: outURL)
        case .html:
            let data = try attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
            try data.write(to: outURL)
        case .docx:
            let data = try attr.data(from: NSRange(location: 0, length: attr.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
            try data.write(to: outURL)
        case .pdf:
            let printOpts: [NSPrintInfo.AttributeKey: Any] = [
                .jobDisposition: NSPrintInfo.JobDisposition.save,
                .jobSavingURL: outURL
            ]
            let printInfo = NSPrintInfo(dictionary: printOpts)
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
            textView.textStorage?.setAttributedString(attr)
            let op = NSPrintOperation(view: textView, printInfo: printInfo)
            op.showsPrintPanel = false
            op.showsProgressPanel = false
            if Thread.isMainThread {
                _ = op.run()
            } else {
                DispatchQueue.main.sync {
                    _ = op.run()
                }
            }
        default:
            throw ConversionError.unsupportedPair(srcURL.pathExtension.uppercased(), targetFormat.displayName)
        }
    }

    // MARK: - Clean-Room Office & Spreadsheet Engine

    private func runOfficeConverter(srcURL: URL, outURL: URL, targetFormat: ConversionFormat, onProgress: ((Double) -> Void)?) throws {
        let scriptPath = BundledResources.officeConverterScriptPath
        onProgress?(0.2)
        if targetFormat == .pdf {
            let tempHTML = FileManager.default.temporaryDirectory.appendingPathComponent("flowconverter-office-\(UUID().uuidString).html")
            defer { try? FileManager.default.removeItem(at: tempHTML) }
            try ProcessRunner.run(executable: "/usr/bin/python3", arguments: [scriptPath, srcURL.path, tempHTML.path])
            onProgress?(0.6)
            try convertDocumentViaAttributedString(srcURL: tempHTML, outURL: outURL, targetFormat: .pdf)
        } else {
            try ProcessRunner.run(executable: "/usr/bin/python3", arguments: [scriptPath, srcURL.path, outURL.path])
        }
        onProgress?(1.0)
        guard FileManager.default.fileExists(atPath: outURL.path) else {
            throw ConversionError.outputMissing
        }
    }

    // MARK: - FFmpeg Media Conversions

    private func convertMediaWithFFmpeg(
        srcURL: URL,
        outURL: URL,
        targetFormat: ConversionFormat,
        options: ConversionOptions,
        onProgress: ((Double) -> Void)?
    ) throws {
        var args = ["-y", "-i", srcURL.path]

        if !options.preserveMetadata {
            args += ["-map_metadata", "-1"]
        }

        if targetFormat == .gif {
            let fps = max(options.gifFrameRate, 5)
            let width = max(options.gifMaxWidth, 160)
            args += [
                "-vf", "fps=\(fps),scale='min(\(width),iw)':-2:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
            ]
        } else if targetFormat.group == .video {
            if options.videoMaxHeight > 0 {
                args += ["-vf", "scale=-2:'min(\(options.videoMaxHeight),ih)':force_original_aspect_ratio=decrease"]
            }
            switch targetFormat {
            case .mp4, .mov, .mkv:
                let qv = options.quality == .high ? "78" : (options.quality == .balanced ? "65" : "50")
                args += ["-c:v", "h264_videotoolbox", "-q:v", qv, "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "\(options.audioBitrate)k"]
            case .webm:
                args += ["-c:a", "opus", "-strict", "-2"]
            default:
                break
            }
        } else if targetFormat.group == .audio {
            args += ["-vn"]
            switch targetFormat {
            case .mp3:
                args += ["-c:a", "libmp3lame", "-b:a", "\(options.audioBitrate)k"]
            case .m4a:
                args += ["-c:a", "aac", "-b:a", "\(options.audioBitrate)k"]
            case .flac:
                args += ["-c:a", "flac"]
            case .ogg:
                args += ["-c:a", "vorbis", "-strict", "-2", "-b:a", "\(options.audioBitrate)k"]
            case .opus:
                args += ["-c:a", "opus", "-strict", "-2", "-b:a", "\(options.audioBitrate)k"]
            case .wav, .aiff:
                switch options.audioSampleDepth {
                case .bit16, .matchSource: args += ["-c:a", targetFormat == .wav ? "pcm_s16le" : "pcm_s16be"]
                case .bit24: args += ["-c:a", targetFormat == .wav ? "pcm_s24le" : "pcm_s24be"]
                case .bit32: args += ["-c:a", targetFormat == .wav ? "pcm_s32le" : "pcm_s32be"]
                case .float32: args += ["-c:a", targetFormat == .wav ? "pcm_f32le" : "pcm_f32be"]
                }
            default:
                break
            }
        }

        args.append(outURL.path)
        try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: args)
        guard FileManager.default.fileExists(atPath: outURL.path) else {
            throw ConversionError.outputMissing
        }
    }
}

// MARK: - Subtitle Converter (.srt <-> .vtt)

public enum SubtitleConverter {
    public static func convert(from srcURL: URL, to outURL: URL, targetFormat: ConversionFormat) throws {
        guard let text = try? String(contentsOf: srcURL, encoding: .utf8) else {
            throw ConversionError.encodingFailed("The subtitle file is not valid UTF-8.")
        }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

        if targetFormat == .vtt {
            // SRT -> WebVTT
            var lines = normalized.components(separatedBy: "\n")
            for i in 0..<lines.count {
                if lines[i].contains("-->") {
                    lines[i] = lines[i].replacingOccurrences(of: ",", with: ".")
                }
            }
            let vtt = "WEBVTT\n\n" + lines.joined(separator: "\n")
            try vtt.write(to: outURL, atomically: true, encoding: .utf8)
        } else {
            // WebVTT -> SRT
            var blocks = normalized.components(separatedBy: "\n\n")
            if let first = blocks.first, first.hasPrefix("WEBVTT") {
                blocks.removeFirst()
            }
            var srtBlocks: [String] = []
            var counter = 1
            for block in blocks {
                let lines = block.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                guard let arrowIdx = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
                let timeLine = lines[arrowIdx].replacingOccurrences(of: ".", with: ",")
                let textLines = lines[(arrowIdx + 1)...].joined(separator: "\n")
                srtBlocks.append("\(counter)\n\(timeLine)\n\(textLines)")
                counter += 1
            }
            guard !srtBlocks.isEmpty else {
                throw ConversionError.encodingFailed("No valid subtitle cues were found.")
            }
            try (srtBlocks.joined(separator: "\n\n") + "\n").write(to: outURL, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Archive Converter (.zip, .tar, .gz)

public enum ArchiveConverter {
    public static func packItems(urls: [URL], targetFormat: ConversionFormat = .zip) throws -> URL {
        guard let first = urls.first else { throw ConversionError.sourceCannotBeRead }
        let dir = first.deletingLastPathComponent()
        let isDir = (try? first.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let defaultBase: String
        if urls.count == 1 {
            defaultBase = isDir ? first.lastPathComponent : first.deletingPathExtension().lastPathComponent
        } else {
            defaultBase = "Archive"
        }
        let outURL = UniqueOutputURL.make(in: dir, baseName: defaultBase, ext: targetFormat.fileExtension)

        if urls.count == 1 && targetFormat == .zip {
            try ProcessRunner.run(executable: "/usr/bin/ditto", arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", first.path, outURL.path])
            return outURL
        }

        let stageDir = FileManager.default.temporaryDirectory.appendingPathComponent("FlowConverter-pack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stageDir) }

        for u in urls {
            var dst = stageDir.appendingPathComponent(u.lastPathComponent)
            var idx = 2
            while FileManager.default.fileExists(atPath: dst.path) {
                let b = u.deletingPathExtension().lastPathComponent
                let e = u.pathExtension
                dst = stageDir.appendingPathComponent(e.isEmpty ? "\(b) \(idx)" : "\(b) \(idx).\(e)")
                idx += 1
            }
            try FileManager.default.copyItem(at: u, to: dst)
        }

        switch targetFormat {
        case .zip:
            try ProcessRunner.run(executable: "/usr/bin/ditto", arguments: ["-c", "-k", "--sequesterRsrc", stageDir.path, outURL.path])
        case .tar:
            try ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-cf", outURL.path, "-C", stageDir.path, "."])
        case .gzip:
            try ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-czf", outURL.path, "-C", stageDir.path, "."])
        default:
            throw ConversionError.unsupportedPair(first.pathExtension, targetFormat.displayName)
        }
        return outURL
    }

    public static func convert(from srcURL: URL, to outURL: URL, targetFormat: ConversionFormat) throws {
        let srcFmt = ConversionFormat.detect(from: srcURL)
        if srcFmt?.group != .archives {
            // Regular file/folder -> pack into archive
            if targetFormat == .zip {
                try ProcessRunner.run(executable: "/usr/bin/ditto", arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", srcURL.path, outURL.path])
                return
            }
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("FlowConverter-archive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Extract input archive first if it is an archive
        try extract(archiveURL: srcURL, to: tempDir)

        switch targetFormat {
        case .zip:
            try ProcessRunner.run(executable: "/usr/bin/ditto", arguments: ["-c", "-k", "--sequesterRsrc", tempDir.path, outURL.path])
        case .tar:
            try ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-cf", outURL.path, "-C", tempDir.path, "."])
        case .gzip:
            try ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-czf", outURL.path, "-C", tempDir.path, "."])
        default:
            throw ConversionError.unsupportedPair(srcURL.pathExtension, targetFormat.displayName)
        }
    }

    public static func extract(archiveURL: URL, to destinationDir: URL) throws {
        let ext = archiveURL.pathExtension.lowercased()
        if ext == "zip" {
            try ProcessRunner.run(executable: "/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, destinationDir.path])
        } else {
            try ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xf", archiveURL.path, "-C", destinationDir.path])
        }
    }
}

// MARK: - Process Runner Helper

public enum ProcessRunner {
    @discardableResult
    public static func run(executable: String, arguments: [String], onLine: ((String) -> Void)? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        if executable.hasSuffix("/ffmpeg") && !arguments.contains("-hide_banner") {
            process.arguments = ["-hide_banner", "-loglevel", "error"] + arguments
        } else {
            process.arguments = arguments
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        if let onLine = onLine {
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                        onLine(line)
                    }
                }
            }
        }

        try process.run()
        process.waitUntilExit()
        outPipe.fileHandleForReading.readabilityHandler = nil

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let msg = errStr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ConversionError.processFailed(msg.isEmpty ? outStr : msg)
        }
        return outStr
    }
}
