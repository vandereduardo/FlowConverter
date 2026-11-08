import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Unified System Accent Palette

public extension Color {
    /// Deep royal blue (#1968E6) for filled buttons, active cards, and controls with white text (WCAG AA > 5.1:1 contrast).
    static let flowAccent = Color(red: 0.10, green: 0.41, blue: 0.90)
    /// Soft azure blue (#4294FF) for icons, badges, and borders on dark surfaces.
    static let flowAccentLight = Color(red: 0.26, green: 0.58, blue: 1.0)
}

// MARK: - Core Formats & Groups

public enum SupportedFormatGroup: String, CaseIterable, Identifiable, Codable {
    case images
    case documents
    case spreadsheets
    case audio
    case video
    case archives
    case subtitles

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .images: return "Images"
        case .documents: return "Documents"
        case .spreadsheets: return "Spreadsheets"
        case .audio: return "Audio"
        case .video: return "Video"
        case .archives: return "Archives"
        case .subtitles: return "Subtitles"
        }
    }

    public var iconName: String {
        switch self {
        case .images: return "photo.on.rectangle.angled"
        case .documents: return "doc.richtext"
        case .spreadsheets: return "tablecells"
        case .audio: return "waveform"
        case .video: return "film"
        case .archives: return "archivebox"
        case .subtitles: return "captions.bubble"
        }
    }
}

public enum ConversionFormat: String, CaseIterable, Identifiable, Codable, Hashable {
    // Images
    case jpg, png, webp, heic, tiff, svg, avif, bmp
    // Documents
    case pdf, docx, pages, ppt, pptx, txt, md, rtf, rtfd, textClipping, html, epub
    // Spreadsheets
    case xlsx, xls, ods, csv, tsv
    // Audio
    case mp3, m4a, wav, flac, ogg, opus, aiff, wma
    // Video
    case mp4, mov, mkv, webm, avi, wmv, gif
    // Subtitles
    case srt, vtt
    // Archives
    case zip, tar, gzip = "gz", rar

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpg: return "JPG"
        case .png: return "PNG"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        case .svg: return "SVG"
        case .avif: return "AVIF"
        case .bmp: return "BMP"
        case .pdf: return "PDF"
        case .mp3: return "MP3"
        case .m4a: return "M4A"
        case .wav: return "WAV"
        case .flac: return "FLAC"
        case .ogg: return "OGG"
        case .opus: return "OPUS"
        case .aiff: return "AIFF"
        case .wma: return "WMA"
        case .mp4: return "MP4"
        case .mov: return "MOV"
        case .mkv: return "MKV"
        case .webm: return "WebM"
        case .avi: return "AVI"
        case .wmv: return "WMV"
        case .gif: return "GIF"
        case .docx: return "DOCX"
        case .pages: return "Pages"
        case .ppt: return "PPT"
        case .pptx: return "PPTX"
        case .txt: return "TXT"
        case .md: return "MD"
        case .rtf: return "RTF"
        case .rtfd: return "RTFD"
        case .textClipping: return "TextClipping"
        case .html: return "HTML"
        case .epub: return "EPUB"
        case .xlsx: return "XLSX"
        case .xls: return "XLS"
        case .ods: return "ODS"
        case .csv: return "CSV"
        case .tsv: return "TSV"
        case .srt: return "SRT"
        case .vtt: return "VTT"
        case .zip: return "ZIP"
        case .tar: return "TAR"
        case .gzip: return "GZ"
        case .rar: return "RAR"
        }
    }

    public var fileExtension: String {
        switch self {
        case .textClipping: return "textClipping"
        case .gzip: return "tar.gz"
        default: return rawValue
        }
    }

    public var group: SupportedFormatGroup {
        switch self {
        case .jpg, .png, .webp, .heic, .tiff, .svg, .avif, .bmp:
            return .images
        case .pdf, .docx, .pages, .ppt, .pptx, .txt, .md, .rtf, .rtfd, .textClipping, .html, .epub:
            return .documents
        case .xlsx, .xls, .ods, .csv, .tsv:
            return .spreadsheets
        case .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma:
            return .audio
        case .mp4, .mov, .mkv, .webm, .avi, .wmv, .gif:
            return .video
        case .srt, .vtt:
            return .subtitles
        case .zip, .tar, .gzip, .rar:
            return .archives
        }
    }

    public static func detect(from url: URL) -> ConversionFormat? {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") || ext == "gz" {
            return .gzip
        }
        switch ext {
        case "jpg", "jpeg", "jpe": return .jpg
        case "png": return .png
        case "webp": return .webp
        case "heic", "heif": return .heic
        case "tif", "tiff": return .tiff
        case "svg": return .svg
        case "avif": return .avif
        case "bmp": return .bmp
        case "pdf": return .pdf
        case "mp3": return .mp3
        case "m4a", "aac": return .m4a
        case "wav", "wave": return .wav
        case "flac": return .flac
        case "ogg", "oga": return .ogg
        case "opus": return .opus
        case "aif", "aiff": return .aiff
        case "wma": return .wma
        case "mp4", "m4v": return .mp4
        case "mov", "qt": return .mov
        case "mkv": return .mkv
        case "webm": return .webm
        case "avi": return .avi
        case "wmv": return .wmv
        case "gif": return .gif
        case "docx": return .docx
        case "pages": return .pages
        case "ppt": return .ppt
        case "pptx": return .pptx
        case "txt", "text": return .txt
        case "md", "markdown": return .md
        case "rtf": return .rtf
        case "rtfd": return .rtfd
        case "textclipping": return .textClipping
        case "htm", "html", "xhtml": return .html
        case "epub": return .epub
        case "xlsx": return .xlsx
        case "xls": return .xls
        case "ods": return .ods
        case "csv": return .csv
        case "tsv", "tab": return .tsv
        case "srt": return .srt
        case "vtt": return .vtt
        case "zip": return .zip
        case "tar": return .tar
        case "rar": return .rar
        default: return nil
        }
    }

    public func compatibleOutputFormats() -> [ConversionFormat] {
        switch self {
        case .jpg, .png, .webp, .heic, .tiff, .svg, .avif, .bmp:
            return [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .pdf, .gif, .zip].filter { $0 != self }
        case .gif:
            return [.mp4, .mov, .webm, .webp, .png, .jpg, .pdf, .zip]
        case .mp4, .mov, .mkv, .webm, .avi, .wmv:
            return [.mp4, .mov, .mkv, .webm, .avi, .wmv, .gif, .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .zip].filter { $0 != self }
        case .mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma:
            return [.mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma, .mp4, .zip].filter { $0 != self }
        case .pdf:
            return [.docx, .pages, .pptx, .xlsx, .epub, .txt, .md, .rtf, .html, .png, .jpg, .tiff, .webp, .zip]
        case .docx, .pages, .txt, .md, .rtf, .rtfd, .textClipping, .html, .epub:
            return [.pdf, .docx, .pages, .epub, .txt, .md, .rtf, .html, .zip].filter { $0 != self }
        case .ppt, .pptx:
            return [.pdf, .pptx, .png, .jpg, .zip].filter { $0 != self }
        case .xlsx, .xls, .ods, .csv, .tsv:
            return [.xlsx, .xls, .ods, .csv, .tsv, .pdf, .zip].filter { $0 != self }
        case .srt, .vtt:
            return [.srt, .vtt, .zip].filter { $0 != self }
        case .zip, .tar, .gzip, .rar:
            return [.zip, .tar, .gzip].filter { $0 != self }
        }
    }
}

// MARK: - Conversion Options

public enum ConversionQuality: String, CaseIterable, Identifiable, Codable {
    case compact, balanced, high
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum AudioSampleDepth: String, CaseIterable, Identifiable, Codable {
    case matchSource, bit16, bit24, bit32, float32
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .matchSource: return "Match Source"
        case .bit16: return "16-bit"
        case .bit24: return "24-bit"
        case .bit32: return "32-bit"
        case .float32: return "32-bit Float"
        }
    }
}

public enum CompressionLevel: String, CaseIterable, Identifiable, Codable {
    case fast, balanced, maximum
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum EPUBLayout: String, CaseIterable, Identifiable, Codable {
    case adjustableText, preservePages
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .adjustableText: return "Adjustable Text"
        case .preservePages: return "Preserve Original Pages"
        }
    }
}

public enum PDFOfficeLayout: String, CaseIterable, Identifiable, Codable {
    case editable, preservePages
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .editable: return "Editable Paragraphs"
        case .preservePages: return "Preserve Original Pages"
        }
    }
}

public struct ConversionOptions: Codable, Equatable {
    public var quality: ConversionQuality = .balanced
    public var preserveMetadata: Bool = true
    public var videoMaxHeight: Int = 0 // 0 = original
    public var audioBitrate: Int = 192
    public var audioSampleDepth: AudioSampleDepth = .matchSource
    public var gifFrameRate: Int = 15
    public var gifMaxWidth: Int = 640
    public var compression: CompressionLevel = .balanced
    public var epubLayout: EPUBLayout = .adjustableText
    public var epubReflowVersion: Int = 1
    public var pdfOfficeLayout: PDFOfficeLayout = .editable

    public init() {}
}

// MARK: - File Tools (All 27 Tools)

public enum FileTool: String, CaseIterable, Identifiable, Codable, Hashable {
    case compress
    case removeMetadata
    case editImage
    case annotateImage
    case frameImage
    case cropImage
    case normalizeAudio
    case muteVideo
    case trimVideo
    case splitPDF
    case organizePDF
    case createArchive
    case extractArchive
    case createPDF
    case mergePDF
    case cropVideo
    case changeVideoSpeed
    case joinVideos
    case videoSnapshots
    case splitVideo
    case audioToVideo
    case trimAudio
    case audioChannels
    case createCollage
    case readQRCode
    case redactImage
    case redactVideo
    case redactAudio
    case convert3MF

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .compress: return "Compress"
        case .removeMetadata: return "Metadata"
        case .editImage: return "Adjust Image"
        case .annotateImage: return "Annotate"
        case .frameImage: return "Background"
        case .cropImage: return "Crop Image"
        case .normalizeAudio: return "Normalize Volume"
        case .muteVideo: return "Mute Video"
        case .trimVideo: return "Trim Video"
        case .splitPDF: return "Split PDF"
        case .organizePDF: return "Organize PDF"
        case .createArchive: return "Create ZIP"
        case .extractArchive: return "Extract"
        case .createPDF: return "Create PDF"
        case .mergePDF: return "Merge PDF"
        case .cropVideo: return "Crop Video"
        case .changeVideoSpeed: return "Video Speed"
        case .joinVideos: return "Join Videos"
        case .videoSnapshots: return "Snapshots"
        case .splitVideo: return "Split Video"
        case .audioToVideo: return "Audio Visualizer"
        case .trimAudio: return "Trim Audio"
        case .audioChannels: return "Audio Channels"
        case .createCollage: return "Collage"
        case .readQRCode: return "Read QR Code"
        case .redactImage: return "Redact Photo"
        case .redactVideo: return "Redact Video"
        case .redactAudio: return "Bleep Audio"
        case .convert3MF: return "3MF Converter"
        }
    }

    public var iconName: String {
        switch self {
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .removeMetadata: return "tag.slash"
        case .editImage: return "slider.horizontal.3"
        case .annotateImage: return "pencil.and.outline"
        case .frameImage: return "photo.artframe"
        case .cropImage: return "crop"
        case .normalizeAudio: return "waveform.badge.magnifyingglass"
        case .muteVideo: return "speaker.slash.fill"
        case .trimVideo: return "timeline.selection"
        case .splitPDF: return "doc.on.doc"
        case .organizePDF: return "square.grid.2x2"
        case .createArchive: return "doc.zipper"
        case .extractArchive: return "archivebox.fill"
        case .createPDF: return "doc.richtext"
        case .mergePDF: return "doc.badge.plus"
        case .cropVideo: return "crop"
        case .changeVideoSpeed: return "gauge.with.dots.needle.67percent"
        case .joinVideos: return "film.stack"
        case .videoSnapshots: return "camera.viewfinder"
        case .splitVideo: return "scissors"
        case .audioToVideo: return "waveform.path.ecg.rectangle"
        case .trimAudio: return "waveform.badge.minus"
        case .audioChannels: return "hifispeaker.2"
        case .createCollage: return "rectangle.3.group"
        case .readQRCode: return "qrcode.viewfinder"
        case .redactImage: return "eye.slash"
        case .redactVideo: return "eye.trianglebadge.exclamationmark"
        case .redactAudio: return "waveform.slash"
        case .convert3MF: return "cube.transparent.fill"
        }
    }

    public static func is3MFFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent.lowercased()
        return name.hasSuffix(".3mf")
    }

    public static func compatibleTools(for urls: [URL]) -> [FileTool] {
        guard !urls.isEmpty else { return [] }
        let all3MF = urls.allSatisfy { is3MFFile($0) }
        if all3MF {
            return [.convert3MF, .extractArchive, .createArchive]
        }
        let formats = urls.compactMap { ConversionFormat.detect(from: $0) }
        let allSameCount = (formats.count == urls.count)
        let allImages = allSameCount && !formats.isEmpty && formats.allSatisfy { $0.group == .images }
        let allVideos = allSameCount && !formats.isEmpty && formats.allSatisfy { $0.group == .video && $0 != .gif }
        let allAudio = allSameCount && !formats.isEmpty && formats.allSatisfy { $0.group == .audio }
        let allPDFs = allSameCount && !formats.isEmpty && formats.allSatisfy { $0 == .pdf }
        let allArchives = allSameCount && !formats.isEmpty && formats.allSatisfy { $0.group == .archives }

        var tools: [FileTool] = []
        if allImages {
            tools.append(contentsOf: [.compress, .removeMetadata, .cropImage, .editImage, .annotateImage, .frameImage])
            if urls.count >= 2 {
                tools.append(.createCollage)
            }
            tools.append(contentsOf: [.redactImage, .readQRCode, .createPDF, .createArchive])
        } else if allVideos {
            tools.append(contentsOf: [.compress, .removeMetadata, .trimVideo, .splitVideo, .cropVideo, .changeVideoSpeed, .muteVideo, .videoSnapshots, .redactVideo])
            if urls.count >= 2 {
                tools.append(.joinVideos)
            }
            tools.append(.createArchive)
        } else if allAudio {
            tools.append(contentsOf: [.trimAudio, .normalizeAudio, .audioChannels, .audioToVideo, .redactAudio, .removeMetadata, .createArchive])
        } else if allPDFs {
            tools.append(contentsOf: [.compress, .removeMetadata, .organizePDF, .splitPDF, .readQRCode])
            if urls.count >= 2 {
                tools.append(.mergePDF)
            }
            tools.append(.createArchive)
        } else if allArchives {
            tools.append(.extractArchive)
            if urls.count >= 2 {
                tools.append(.createArchive)
            }
        } else {
            // Folders, documents, spreadsheets, or mixed file groups can always be zipped into a single archive
            tools.append(.createArchive)
        }
        return tools
    }
}

// MARK: - Fan Modes & Actions

public enum ConversionFanMode: String, CaseIterable, Hashable {
    case conversions
    case fileTools
    case fileActions

    public var title: String {
        switch self {
        case .conversions: return "Convert"
        case .fileTools: return "Tools"
        case .fileActions: return "Actions"
        }
    }
}

public enum ConversionFanAction: Hashable, Identifiable {
    case convert(ConversionFormat)
    case convert3MFPrinter(Printer3DModel)
    case fileTool(FileTool)
    case airDrop
    case float
    case copy
    case move
    case copyPath
    case openTerminal

    public var id: String {
        switch self {
        case .convert(let f): return "convert.\(f.rawValue)"
        case .convert3MFPrinter(let p): return "printer3d.\(p.id)"
        case .fileTool(let t): return "tool.\(t.rawValue)"
        case .airDrop: return "action.airDrop"
        case .float: return "action.float"
        case .copy: return "action.copy"
        case .move: return "action.move"
        case .copyPath: return "action.copyPath"
        case .openTerminal: return "action.openTerminal"
        }
    }

    public var label: String {
        switch self {
        case .convert(let f): return f.displayName
        case .convert3MFPrinter(let p): return p.shortWheelName
        case .fileTool(let t): return t.title
        case .airDrop: return "AirDrop"
        case .float: return "Float"
        case .copy: return "Copy"
        case .move: return "Move"
        case .copyPath: return "Copy Path"
        case .openTerminal: return "Terminal"
        }
    }

    public var centerDescription: String {
        switch self {
        case .convert(let f): return "Convert to \(f.displayName)"
        case .convert3MFPrinter(let p): return "Convert 3MF to \(p.name) (\(p.bedWidthMM)×\(p.bedDepthMM)mm)"
        case .fileTool(let t): return t.title
        case .airDrop: return "Share files and folders with AirDrop"
        case .float: return "Float file or folder thumbnail"
        case .copy: return "Copy files and folders"
        case .move: return "Move files and folders to a chosen folder"
        case .copyPath: return "Copy file and folder paths"
        case .openTerminal: return "Open terminal in folder"
        }
    }

    public var iconName: String? {
        switch self {
        case .convert: return nil
        case .convert3MFPrinter: return "printer.fill"
        case .fileTool(let t): return t.iconName
        case .airDrop: return "airplayaudio"
        case .float: return "paperclip"
        case .copy: return "doc.on.doc"
        case .move: return "folder"
        case .copyPath: return "link"
        case .openTerminal: return "terminal"
        }
    }
}

public enum ConversionFanTheme: String, CaseIterable, Identifiable, Codable {
    case glass
    case metallic

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum FloatWheelBehavior: String, CaseIterable, Identifiable, Codable {
    case createNew
    case addToExisting

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .createNew: return "Create a New Float"
        case .addToExisting: return "Add Files to an Existing Float"
        }
    }
}

// MARK: - Tool Options & Sub-Models

public enum CompressionTargetMode: String, CaseIterable, Identifiable, Codable {
    case preset, fileSize, percentage
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .preset: return "Preset"
        case .fileSize: return "Target Size"
        case .percentage: return "Percentage"
        }
    }
}

public enum ImageCompressionStrength: String, CaseIterable, Identifiable, Codable {
    case balanced, strong
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum ImageCompressionSize: String, CaseIterable, Identifiable, Codable {
    case original, large, medium, small
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var maxLongestEdge: CGFloat? {
        switch self {
        case .original: return nil
        case .large: return 2560
        case .medium: return 1600
        case .small: return 1024
        }
    }
}

public enum VideoCompressionStrength: String, CaseIterable, Identifiable, Codable {
    case balanced, strong
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum TargetVideoEncoding: String, CaseIterable, Identifiable, Codable {
    case accurate, fast
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct ImageCompressionOptions: Equatable, Codable {
    public var strength: ImageCompressionStrength = .balanced
    public var size: ImageCompressionSize = .original
    public init() {}
}

public struct VideoCompressionOptions: Equatable, Codable {
    public var strength: VideoCompressionStrength = .balanced
    public init() {}
}

public struct ImageAdjustments: Equatable, Codable {
    public var exposure: Double = 0
    public var brightness: Double = 0
    public var contrast: Double = 0
    public var highlights: Double = 0
    public var shadows: Double = 0
    public var whites: Double = 0
    public var blacks: Double = 0
    public var temperature: Double = 0
    public var tint: Double = 0
    public var saturation: Double = 0
    public var vibrance: Double = 0
    public var hue: Double = 0
    public var gamma: Double = 0
    public var clarity: Double = 0
    public var texture: Double = 0
    public var sharpness: Double = 0
    public var dehaze: Double = 0
    public var fade: Double = 0
    public var vignette: Double = 0
    public var grain: Double = 0
    public var noiseReduction: Double = 0
    public var blur: Double = 0
    public init() {}
}

public enum AnnotationKind: String, CaseIterable, Identifiable, Codable {
    case arrow, freehand, text, rectangle, ellipse, highlighter, number, magnifier, image
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var iconName: String {
        switch self {
        case .arrow: return "arrow.up.right"
        case .freehand: return "scribble"
        case .text: return "textformat"
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .highlighter: return "highlighter"
        case .number: return "1.circle"
        case .magnifier: return "plus.magnifyingglass"
        case .image: return "photo.badge.plus"
        }
    }
}

public enum AnnotationFont: String, CaseIterable, Identifiable, Codable {
    case system, rounded, serif, monospaced
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct AnnotationPoint: Equatable, Codable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct ImageAnnotation: Identifiable, Equatable, Codable {
    public var id: UUID = UUID()
    public var kind: AnnotationKind
    public var x: Double
    public var y: Double
    public var endX: Double
    public var endY: Double
    public var points: [AnnotationPoint] = []
    public var text: String = ""
    public var number: Int = 1
    public var red: Double = 1.0
    public var green: Double = 0.32
    public var blue: Double = 0.0
    public var fontSize: Double = 24
    public var font: AnnotationFont = .system
    public var scale: Double = 1.0
    public var magnification: Double = 2.0
    public var imageURL: URL?
}

public enum FrameBackgroundPreset: String, CaseIterable, Identifiable, Codable {
    case citrus, mesh, meadow, whisper, orchid, oasis, lagoon, aqua, dream, sorbet, frost, emerald, sunset, sky, mint, violet, graphite
    case white, yellow, lime, green, teal, cyan, cobalt, navy, purple, lavender, rose, red, coral, orange, brown, gray, black
    case custom, image

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public var previewColors: [NSColor] {
        switch self {
        case .citrus: return [NSColor(srgbRed: 1.0, green: 0.35, blue: 0.0, alpha: 1), NSColor(srgbRed: 1.0, green: 0.72, blue: 0.15, alpha: 1)]
        case .mesh: return [NSColor(srgbRed: 0.42, green: 0.35, blue: 0.95, alpha: 1), NSColor(srgbRed: 0.95, green: 0.4, blue: 0.65, alpha: 1)]
        case .meadow: return [NSColor(srgbRed: 0.2, green: 0.78, blue: 0.45, alpha: 1), NSColor(srgbRed: 0.75, green: 0.92, blue: 0.35, alpha: 1)]
        case .whisper: return [NSColor(srgbRed: 0.92, green: 0.94, blue: 0.98, alpha: 1), NSColor(srgbRed: 0.84, green: 0.88, blue: 0.95, alpha: 1)]
        case .orchid: return [NSColor(srgbRed: 0.78, green: 0.35, blue: 0.92, alpha: 1), NSColor(srgbRed: 0.45, green: 0.25, blue: 0.85, alpha: 1)]
        case .oasis: return [NSColor(srgbRed: 0.05, green: 0.68, blue: 0.75, alpha: 1), NSColor(srgbRed: 0.15, green: 0.88, blue: 0.65, alpha: 1)]
        case .lagoon: return [NSColor(srgbRed: 0.05, green: 0.45, blue: 0.85, alpha: 1), NSColor(srgbRed: 0.1, green: 0.8, blue: 0.85, alpha: 1)]
        case .aqua: return [NSColor(srgbRed: 0.2, green: 0.85, blue: 0.95, alpha: 1), NSColor(srgbRed: 0.35, green: 0.55, blue: 0.95, alpha: 1)]
        case .dream: return [NSColor(srgbRed: 0.95, green: 0.6, blue: 0.8, alpha: 1), NSColor(srgbRed: 0.65, green: 0.75, blue: 0.98, alpha: 1)]
        case .sorbet: return [NSColor(srgbRed: 1.0, green: 0.45, blue: 0.55, alpha: 1), NSColor(srgbRed: 1.0, green: 0.8, blue: 0.4, alpha: 1)]
        case .frost: return [NSColor(srgbRed: 0.82, green: 0.92, blue: 1.0, alpha: 1), NSColor(srgbRed: 0.95, green: 0.98, blue: 1.0, alpha: 1)]
        case .emerald: return [NSColor(srgbRed: 0.05, green: 0.55, blue: 0.4, alpha: 1), NSColor(srgbRed: 0.15, green: 0.8, blue: 0.55, alpha: 1)]
        case .sunset: return [NSColor(srgbRed: 0.95, green: 0.25, blue: 0.35, alpha: 1), NSColor(srgbRed: 1.0, green: 0.6, blue: 0.2, alpha: 1)]
        case .sky: return [NSColor(srgbRed: 0.25, green: 0.65, blue: 0.98, alpha: 1), NSColor(srgbRed: 0.6, green: 0.85, blue: 1.0, alpha: 1)]
        case .mint: return [NSColor(srgbRed: 0.4, green: 0.92, blue: 0.75, alpha: 1), NSColor(srgbRed: 0.2, green: 0.72, blue: 0.65, alpha: 1)]
        case .violet: return [NSColor(srgbRed: 0.45, green: 0.2, blue: 0.78, alpha: 1), NSColor(srgbRed: 0.7, green: 0.4, blue: 0.95, alpha: 1)]
        case .graphite: return [NSColor(srgbRed: 0.22, green: 0.24, blue: 0.28, alpha: 1), NSColor(srgbRed: 0.12, green: 0.13, blue: 0.16, alpha: 1)]
        case .white: return [.white, .white]
        case .yellow: return [.systemYellow, .systemYellow]
        case .lime: return [NSColor(srgbRed: 0.55, green: 0.88, blue: 0.15, alpha: 1), NSColor(srgbRed: 0.55, green: 0.88, blue: 0.15, alpha: 1)]
        case .green: return [.systemGreen, .systemGreen]
        case .teal: return [.systemTeal, .systemTeal]
        case .cyan: return [.systemCyan, .systemCyan]
        case .cobalt: return [NSColor(srgbRed: 0.1, green: 0.35, blue: 0.85, alpha: 1), NSColor(srgbRed: 0.1, green: 0.35, blue: 0.85, alpha: 1)]
        case .navy: return [NSColor(srgbRed: 0.08, green: 0.15, blue: 0.38, alpha: 1), NSColor(srgbRed: 0.08, green: 0.15, blue: 0.38, alpha: 1)]
        case .purple: return [.systemPurple, .systemPurple]
        case .lavender: return [NSColor(srgbRed: 0.75, green: 0.65, blue: 0.95, alpha: 1), NSColor(srgbRed: 0.75, green: 0.65, blue: 0.95, alpha: 1)]
        case .rose: return [NSColor(srgbRed: 0.95, green: 0.35, blue: 0.55, alpha: 1), NSColor(srgbRed: 0.95, green: 0.35, blue: 0.55, alpha: 1)]
        case .red: return [.systemRed, .systemRed]
        case .coral: return [NSColor(srgbRed: 1.0, green: 0.45, blue: 0.38, alpha: 1), NSColor(srgbRed: 1.0, green: 0.45, blue: 0.38, alpha: 1)]
        case .orange: return [.systemOrange, .systemOrange]
        case .brown: return [.systemBrown, .systemBrown]
        case .gray: return [.systemGray, .systemGray]
        case .black: return [.black, .black]
        case .custom, .image: return [.systemOrange, .systemOrange]
        }
    }
}

public enum FrameCanvasRatio: String, CaseIterable, Identifiable, Codable {
    case automatic, square, landscape, portrait
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .square: return "Square · 1:1"
        case .landscape: return "Landscape · 16:9"
        case .portrait: return "Portrait · 9:16"
        }
    }
}

public struct FrameImageOptions: Equatable, Codable {
    public var background: FrameBackgroundPreset = .citrus
    public var backgroundImageURL: URL?
    public var customRed: Double = 1.0
    public var customGreen: Double = 0.32
    public var customBlue: Double = 0.0
    public var padding: Double = 64
    public var cornerRadius: Double = 16
    public var shadowRadius: Double = 28
    public var canvasRatio: FrameCanvasRatio = .automatic
    public init() {}
}

public enum CollageStyle: String, CaseIterable, Identifiable, Codable {
    case grid, horizontal, vertical, featured
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum CollageBackground: String, CaseIterable, Identifiable, Codable {
    case white, black, transparent
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct CollageOptions: Equatable, Codable {
    public var style: CollageStyle = .grid
    public var columns: Int = 2
    public var width: Int = 1920
    public var aspectRatio: Double = 1.3333
    public var spacing: Double = 16
    public var padding: Double = 24
    public var cornerRadius: Double = 12
    public var fillImages: Bool = true
    public var background: CollageBackground = .white
    public init() {}
}

public enum RedactionStyle: String, CaseIterable, Identifiable, Codable {
    case solid, blur
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct RedactionTimeRange: Identifiable, Equatable, Codable {
    public var id: UUID = UUID()
    public var start: Double
    public var end: Double
    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }
}

public struct RedactionRectangle: Identifiable, Equatable, Codable {
    public var id: UUID = UUID()
    public var layerID: UUID = UUID()
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var red: Double = 0
    public var green: Double = 0
    public var blue: Double = 0
    public var timeRange: RedactionTimeRange?
}

public struct MetadataField: Identifiable, Equatable, Codable {
    public var id: String { "\(scope):\(key)" }
    public var scope: String
    public var key: String
    public var original: String
    public var value: String
    public var editable: Bool
    public var removable: Bool
    public var removed: Bool = false
}

public struct CropSelection: Equatable, Codable {
    public var x: Double = 0.05
    public var y: Double = 0.05
    public var width: Double = 0.90
    public var height: Double = 0.90
    public init(x: Double = 0.05, y: Double = 0.05, width: Double = 0.90, height: Double = 0.90) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum CropResizeHandle: String, CaseIterable, Identifiable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    public var id: String { rawValue }
}

public enum CropAspectPreset: String, CaseIterable, Identifiable, Equatable {
    case free = "Free"
    case original = "Original"
    case square = "1:1"
    case r16x9 = "16:9"
    case r9x16 = "9:16"
    case r4x3 = "4:3"
    case r3x4 = "3:4"
    case r3x2 = "3:2"
    case r2x3 = "2:3"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public func ratio(for sourceSize: CGSize) -> Double? {
        switch self {
        case .free: return nil
        case .original:
            guard sourceSize.height > 0 else { return 1.0 }
            return Double(sourceSize.width / sourceSize.height)
        case .square: return 1.0
        case .r16x9: return 16.0 / 9.0
        case .r9x16: return 9.0 / 16.0
        case .r4x3: return 4.0 / 3.0
        case .r3x4: return 3.0 / 4.0
        case .r3x2: return 3.0 / 2.0
        case .r2x3: return 2.0 / 3.0
        }
    }
}

public enum SplitExportMode: String, CaseIterable, Identifiable, Codable {
    case clips, merged
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .clips: return "Separate Clips"
        case .merged: return "Merged Video"
        }
    }
}

public enum AudioVisualizationStyle: String, CaseIterable, Identifiable, Codable {
    case waveform, staticImage
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .waveform: return "Waveform"
        case .staticImage: return "Static Image"
        }
    }
}

public enum MediaCanvas: String, CaseIterable, Identifiable, Codable {
    case landscape, portrait, square
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .landscape: return "Landscape · 16:9"
        case .portrait: return "Portrait · 9:16"
        case .square: return "Square · 1:1"
        }
    }
    public var dimensions: CGSize {
        switch self {
        case .landscape: return CGSize(width: 1920, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

// MARK: - 3D Printer & .3MF Converter Models (Cordeiro Flow Style)

public struct Printer3DModel: Identifiable, Codable, Equatable, Hashable {
    public var id: String
    public var brand: String
    public var name: String
    public var shortWheelName: String
    public var bedWidthMM: Int
    public var bedDepthMM: Int
    public var bedHeightMM: Int
    public var nozzleDiameterMM: Double
    public var gcodeFlavor: String
    public var printerSettingsID: String
    public var showInWheel: Bool
    public var isCustom: Bool

    public init(
        id: String = UUID().uuidString,
        brand: String,
        name: String,
        shortWheelName: String,
        bedWidthMM: Int = 256,
        bedDepthMM: Int = 256,
        bedHeightMM: Int = 256,
        nozzleDiameterMM: Double = 0.4,
        gcodeFlavor: String = "marlin",
        printerSettingsID: String? = nil,
        showInWheel: Bool = true,
        isCustom: Bool = false
    ) {
        self.id = id
        self.brand = brand
        self.name = name
        self.shortWheelName = shortWheelName
        self.bedWidthMM = bedWidthMM
        self.bedDepthMM = bedDepthMM
        self.bedHeightMM = bedHeightMM
        self.nozzleDiameterMM = nozzleDiameterMM
        self.gcodeFlavor = gcodeFlavor
        let nozzleStr = String(format: "%.1f", nozzleDiameterMM)
        self.printerSettingsID = printerSettingsID ?? "\(name) \(nozzleStr) nozzle"
        self.showInWheel = showInWheel
        self.isCustom = isCustom
    }

    public var dimensionsSummary: String {
        "\(bedWidthMM)×\(bedDepthMM)×\(bedHeightMM) mm · \(String(format: "%.1f", nozzleDiameterMM))mm"
    }

    public var sanitizedFileSuffix: String {
        let base = shortWheelName.isEmpty ? name : shortWheelName
        let cleaned = base.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return cleaned.isEmpty ? "Printer" : cleaned
    }

    public static let manufacturerList: [String] = [
        "Anycubic",
        "Bambu Lab",
        "Creality",
        "Flashforge",
        "Snapmaker",
        "Elegoo",
        "Prusa",
        "Qidi Tech",
        "Sovol",
        "Artillery",
        "Flsun",
        "Voron",
        "Two Trees",
        "Personalizada"
    ]

    public static func models(forBrand brand: String) -> [Printer3DModel] {
        allPresetModels.filter { $0.brand.caseInsensitiveCompare(brand) == .orderedSame }
    }

    public static let allPresetModels: [Printer3DModel] = [
        // MARK: Anycubic
        Printer3DModel(id: "anycubic-kobra-x", brand: "Anycubic", name: "Anycubic Kobra X", shortWheelName: "Kobra X", bedWidthMM: 260, bedDepthMM: 260, bedHeightMM: 260, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: true),
        Printer3DModel(id: "anycubic-kobra-4", brand: "Anycubic", name: "Anycubic Kobra 4", shortWheelName: "Kobra 4", bedWidthMM: 260, bedDepthMM: 260, bedHeightMM: 260, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-3", brand: "Anycubic", name: "Anycubic Kobra 3", shortWheelName: "Kobra 3", bedWidthMM: 250, bedDepthMM: 250, bedHeightMM: 260, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: true),
        Printer3DModel(id: "anycubic-kobra-3-v2", brand: "Anycubic", name: "Anycubic Kobra 3 V2", shortWheelName: "Kobra 3 V2", bedWidthMM: 250, bedDepthMM: 250, bedHeightMM: 260, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-3-combo", brand: "Anycubic", name: "Anycubic Kobra 3 Combo", shortWheelName: "Kobra 3 Combo", bedWidthMM: 250, bedDepthMM: 250, bedHeightMM: 260, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-3-max", brand: "Anycubic", name: "Anycubic Kobra 3 Max", shortWheelName: "Kobra 3 Max", bedWidthMM: 420, bedDepthMM: 420, bedHeightMM: 500, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-3-max-v2", brand: "Anycubic", name: "Anycubic Kobra 3 Max V2", shortWheelName: "Kobra 3M V2", bedWidthMM: 420, bedDepthMM: 420, bedHeightMM: 500, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-s1", brand: "Anycubic", name: "Anycubic Kobra S1", shortWheelName: "Kobra S1", bedWidthMM: 250, bedDepthMM: 250, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-s1-max", brand: "Anycubic", name: "Anycubic Kobra S1 Max", shortWheelName: "Kobra S1 Max", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 300, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-s1-combo", brand: "Anycubic", name: "Anycubic Kobra S1 Combo", shortWheelName: "Kobra S1C", bedWidthMM: 250, bedDepthMM: 250, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-2-pro", brand: "Anycubic", name: "Anycubic Kobra 2 Pro", shortWheelName: "Kobra 2 Pro", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-2-plus", brand: "Anycubic", name: "Anycubic Kobra 2 Plus", shortWheelName: "Kobra 2+", bedWidthMM: 320, bedDepthMM: 320, bedHeightMM: 400, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-2-max", brand: "Anycubic", name: "Anycubic Kobra 2 Max", shortWheelName: "Kobra 2 Max", bedWidthMM: 420, bedDepthMM: 420, bedHeightMM: 500, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-2", brand: "Anycubic", name: "Anycubic Kobra 2", shortWheelName: "Kobra 2", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-2-neo", brand: "Anycubic", name: "Anycubic Kobra 2 Neo", shortWheelName: "Kobra 2 Neo", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra", brand: "Anycubic", name: "Anycubic Kobra", shortWheelName: "Kobra", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-neo", brand: "Anycubic", name: "Anycubic Kobra Neo", shortWheelName: "Kobra Neo", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-go", brand: "Anycubic", name: "Anycubic Kobra Go", shortWheelName: "Kobra Go", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-plus", brand: "Anycubic", name: "Anycubic Kobra Plus", shortWheelName: "Kobra Plus", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 350, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-kobra-max", brand: "Anycubic", name: "Anycubic Kobra Max", shortWheelName: "Kobra Max", bedWidthMM: 400, bedDepthMM: 400, bedHeightMM: 450, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-vyper", brand: "Anycubic", name: "Anycubic Vyper", shortWheelName: "Vyper", bedWidthMM: 245, bedDepthMM: 245, bedHeightMM: 260, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-chiron", brand: "Anycubic", name: "Anycubic Chiron", shortWheelName: "Chiron", bedWidthMM: 400, bedDepthMM: 400, bedHeightMM: 450, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-mega-s", brand: "Anycubic", name: "Anycubic i3 Mega S", shortWheelName: "Mega S", bedWidthMM: 210, bedDepthMM: 210, bedHeightMM: 205, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "anycubic-mega-x", brand: "Anycubic", name: "Anycubic Mega X", shortWheelName: "Mega X", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 305, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),

        // MARK: Bambu Lab
        Printer3DModel(id: "bambu-a1-mini", brand: "Bambu Lab", name: "Bambu Lab A1 mini", shortWheelName: "A1 mini", bedWidthMM: 180, bedDepthMM: 180, bedHeightMM: 180, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: true),
        Printer3DModel(id: "bambu-a1", brand: "Bambu Lab", name: "Bambu Lab A1", shortWheelName: "Bambu A1", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: true),
        Printer3DModel(id: "bambu-p1s", brand: "Bambu Lab", name: "Bambu Lab P1S", shortWheelName: "Bambu P1S", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: true),
        Printer3DModel(id: "bambu-p1p", brand: "Bambu Lab", name: "Bambu Lab P1P", shortWheelName: "Bambu P1P", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "bambu-x1c", brand: "Bambu Lab", name: "Bambu Lab X1 Carbon", shortWheelName: "X1 Carbon", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: true),
        Printer3DModel(id: "bambu-x1e", brand: "Bambu Lab", name: "Bambu Lab X1E", shortWheelName: "Bambu X1E", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "bambu-x1", brand: "Bambu Lab", name: "Bambu Lab X1", shortWheelName: "Bambu X1", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "bambu-h2d", brand: "Bambu Lab", name: "Bambu Lab H2D", shortWheelName: "Bambu H2D", bedWidthMM: 350, bedDepthMM: 320, bedHeightMM: 325, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),

        // MARK: Creality
        Printer3DModel(id: "creality-k1", brand: "Creality", name: "Creality K1", shortWheelName: "Creality K1", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: true),
        Printer3DModel(id: "creality-k1c", brand: "Creality", name: "Creality K1C", shortWheelName: "Creality K1C", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-k1-se", brand: "Creality", name: "Creality K1 SE", shortWheelName: "K1 SE", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-k1-max", brand: "Creality", name: "Creality K1 Max", shortWheelName: "K1 Max", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 300, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: true),
        Printer3DModel(id: "creality-k2-plus", brand: "Creality", name: "Creality K2 Plus", shortWheelName: "K2 Plus", bedWidthMM: 350, bedDepthMM: 350, bedHeightMM: 350, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-hi", brand: "Creality", name: "Creality Hi", shortWheelName: "Creality Hi", bedWidthMM: 260, bedDepthMM: 260, bedHeightMM: 300, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-ender3-v3", brand: "Creality", name: "Creality Ender-3 V3", shortWheelName: "Ender-3 V3", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-ender3-v3-ke", brand: "Creality", name: "Creality Ender-3 V3 KE", shortWheelName: "Ender-3 KE", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 240, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-ender3-v3-se", brand: "Creality", name: "Creality Ender-3 V3 SE", shortWheelName: "Ender-3 SE", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "creality-ender3-v3-plus", brand: "Creality", name: "Creality Ender-3 V3 Plus", shortWheelName: "Ender-3 V3+", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 330, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-ender3-s1-pro", brand: "Creality", name: "Creality Ender-3 S1 Pro", shortWheelName: "Ender-3 S1P", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 270, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "creality-ender3-s1", brand: "Creality", name: "Creality Ender-3 S1", shortWheelName: "Ender-3 S1", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 270, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "creality-ender3-s1-plus", brand: "Creality", name: "Creality Ender-3 S1 Plus", shortWheelName: "Ender-3 S1+", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 300, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "creality-ender3-v2", brand: "Creality", name: "Creality Ender-3 V2", shortWheelName: "Ender-3 V2", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "creality-ender3", brand: "Creality", name: "Creality Ender-3", shortWheelName: "Ender-3", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "creality-ender5-s1", brand: "Creality", name: "Creality Ender-5 S1", shortWheelName: "Ender-5 S1", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 280, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "creality-ender5-max", brand: "Creality", name: "Creality Ender-5 Max", shortWheelName: "Ender-5 Max", bedWidthMM: 400, bedDepthMM: 400, bedHeightMM: 400, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-cr10-se", brand: "Creality", name: "Creality CR-10 SE", shortWheelName: "CR-10 SE", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 265, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "creality-cr10-smart-pro", brand: "Creality", name: "Creality CR-10 Smart Pro", shortWheelName: "CR-10 Smart", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 400, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),

        // MARK: Flashforge
        Printer3DModel(id: "flashforge-creator-5", brand: "Flashforge", name: "Flashforge Creator 5", shortWheelName: "Creator 5", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge Creator 5 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-creator-5-pro", brand: "Flashforge", name: "Flashforge Creator 5 Pro", shortWheelName: "Creator 5P", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge Creator 5 Pro 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-adv5m-pro", brand: "Flashforge", name: "Flashforge Adventurer 5M Pro", shortWheelName: "Adv 5M Pro", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 220, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge Adventurer 5M Pro 0.4 Nozzle", showInWheel: true),
        Printer3DModel(id: "flashforge-adv5m", brand: "Flashforge", name: "Flashforge Adventurer 5M", shortWheelName: "Adv 5M", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 220, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge Adventurer 5M 0.4 Nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-ad5x", brand: "Flashforge", name: "Flashforge AD5X", shortWheelName: "AD5X", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 220, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge AD5X 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-guider4", brand: "Flashforge", name: "Flashforge Guider 4", shortWheelName: "Guider 4", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 300, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge Guider4 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-guider4-pro", brand: "Flashforge", name: "Flashforge Guider 4 Pro", shortWheelName: "Guider 4P", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 300, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge Guider4 Pro 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-guider3-ultra", brand: "Flashforge", name: "Flashforge Guider 3 Ultra", shortWheelName: "Guider 3U", bedWidthMM: 330, bedDepthMM: 330, bedHeightMM: 600, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Flashforge Guider 3 Ultra 0.4 Nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-guider2s", brand: "Flashforge", name: "Flashforge Guider 2s", shortWheelName: "Guider 2s", bedWidthMM: 280, bedDepthMM: 250, bedHeightMM: 300, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", printerSettingsID: "Flashforge Guider 2s 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-adv4-pro", brand: "Flashforge", name: "Flashforge Adventurer 4 Pro", shortWheelName: "Adv 4 Pro", bedWidthMM: 220, bedDepthMM: 200, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", printerSettingsID: "Flashforge Adventurer 4 Series 0.4 Nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-adv3", brand: "Flashforge", name: "Flashforge Adventurer 3", shortWheelName: "Adv 3", bedWidthMM: 150, bedDepthMM: 150, bedHeightMM: 150, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", printerSettingsID: "Flashforge Adventurer 3 Series 0.4 Nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-artemis", brand: "Flashforge", name: "Flashforge Artemis", shortWheelName: "Artemis", bedWidthMM: 195, bedDepthMM: 195, bedHeightMM: 200, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", printerSettingsID: "Flashforge Artemis 0.4 Nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-creator-4", brand: "Flashforge", name: "Flashforge Creator 4", shortWheelName: "Creator 4", bedWidthMM: 400, bedDepthMM: 350, bedHeightMM: 500, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", printerSettingsID: "Flashforge Creator 4 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-creator-3-pro", brand: "Flashforge", name: "Flashforge Creator 3 Pro", shortWheelName: "Creator 3P", bedWidthMM: 300, bedDepthMM: 250, bedHeightMM: 200, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", printerSettingsID: "Flashforge Creator 3 Pro 0.4 nozzle", showInWheel: false),
        Printer3DModel(id: "flashforge-creator-pro-2", brand: "Flashforge", name: "Flashforge Creator Pro 2", shortWheelName: "Creator P2", bedWidthMM: 200, bedDepthMM: 148, bedHeightMM: 150, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", printerSettingsID: "Flashforge Creator Pro 2 0.4 nozzle", showInWheel: false),

        // MARK: Snapmaker
        Printer3DModel(id: "snapmaker-u1", brand: "Snapmaker", name: "Snapmaker U1", shortWheelName: "Snap U1", bedWidthMM: 270, bedDepthMM: 270, bedHeightMM: 270, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", printerSettingsID: "Snapmaker U1 (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-j1s", brand: "Snapmaker", name: "Snapmaker J1s", shortWheelName: "Snap J1s", bedWidthMM: 300, bedDepthMM: 200, bedHeightMM: 200, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker J1 (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-j1", brand: "Snapmaker", name: "Snapmaker J1", shortWheelName: "Snap J1", bedWidthMM: 324, bedDepthMM: 200, bedHeightMM: 200, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker J1 (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-artisan", brand: "Snapmaker", name: "Snapmaker Artisan", shortWheelName: "Artisan", bedWidthMM: 400, bedDepthMM: 400, bedHeightMM: 400, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker Artisan (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-a350", brand: "Snapmaker", name: "Snapmaker 2.0 A350T / A350", shortWheelName: "Snap A350", bedWidthMM: 320, bedDepthMM: 350, bedHeightMM: 325, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker A350 (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-a350-dual", brand: "Snapmaker", name: "Snapmaker 2.0 A350 Dual", shortWheelName: "A350 Dual", bedWidthMM: 320, bedDepthMM: 350, bedHeightMM: 285, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker A350 Dual (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-a350-qskit", brand: "Snapmaker", name: "Snapmaker 2.0 A350 QSKit", shortWheelName: "A350 QS", bedWidthMM: 320, bedDepthMM: 350, bedHeightMM: 310, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker A350 QSKit (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-a250", brand: "Snapmaker", name: "Snapmaker 2.0 A250T / A250", shortWheelName: "Snap A250", bedWidthMM: 230, bedDepthMM: 250, bedHeightMM: 230, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker A250 (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-a250-dual", brand: "Snapmaker", name: "Snapmaker 2.0 A250 Dual", shortWheelName: "A250 Dual", bedWidthMM: 230, bedDepthMM: 250, bedHeightMM: 190, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker A250 Dual (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-a250-qskit", brand: "Snapmaker", name: "Snapmaker 2.0 A250 QSKit", shortWheelName: "A250 QS", bedWidthMM: 230, bedDepthMM: 250, bedHeightMM: 215, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker A250 QSKit (0.4 nozzle)", showInWheel: false),
        Printer3DModel(id: "snapmaker-a150", brand: "Snapmaker", name: "Snapmaker 2.0 A150", shortWheelName: "Snap A150", bedWidthMM: 160, bedDepthMM: 160, bedHeightMM: 145, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin2", printerSettingsID: "Snapmaker A250 (0.4 nozzle)", showInWheel: false),

        // MARK: Elegoo
        Printer3DModel(id: "elegoo-neptune4-pro", brand: "Elegoo", name: "Elegoo Neptune 4 Pro", shortWheelName: "Neptune 4P", bedWidthMM: 225, bedDepthMM: 225, bedHeightMM: 265, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "elegoo-neptune4", brand: "Elegoo", name: "Elegoo Neptune 4", shortWheelName: "Neptune 4", bedWidthMM: 225, bedDepthMM: 225, bedHeightMM: 265, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "elegoo-neptune4-plus", brand: "Elegoo", name: "Elegoo Neptune 4 Plus", shortWheelName: "Neptune 4+", bedWidthMM: 320, bedDepthMM: 320, bedHeightMM: 385, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "elegoo-neptune4-max", brand: "Elegoo", name: "Elegoo Neptune 4 Max", shortWheelName: "Neptune 4M", bedWidthMM: 420, bedDepthMM: 420, bedHeightMM: 480, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "elegoo-neptune3-pro", brand: "Elegoo", name: "Elegoo Neptune 3 Pro", shortWheelName: "Neptune 3P", bedWidthMM: 225, bedDepthMM: 225, bedHeightMM: 280, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "elegoo-neptune3-plus", brand: "Elegoo", name: "Elegoo Neptune 3 Plus", shortWheelName: "Neptune 3+", bedWidthMM: 320, bedDepthMM: 320, bedHeightMM: 400, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "elegoo-neptune3-max", brand: "Elegoo", name: "Elegoo Neptune 3 Max", shortWheelName: "Neptune 3M", bedWidthMM: 420, bedDepthMM: 420, bedHeightMM: 500, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "elegoo-centauri-carbon", brand: "Elegoo", name: "Elegoo Centauri Carbon", shortWheelName: "Centauri C", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),

        // MARK: Prusa
        Printer3DModel(id: "prusa-mk4", brand: "Prusa", name: "Original Prusa MK4", shortWheelName: "Prusa MK4", bedWidthMM: 250, bedDepthMM: 210, bedHeightMM: 220, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "prusa-mk4s", brand: "Prusa", name: "Original Prusa MK4S", shortWheelName: "Prusa MK4S", bedWidthMM: 250, bedDepthMM: 210, bedHeightMM: 220, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "prusa-core-one", brand: "Prusa", name: "Original Prusa CORE One", shortWheelName: "CORE One", bedWidthMM: 250, bedDepthMM: 220, bedHeightMM: 270, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "prusa-mk3s", brand: "Prusa", name: "Original Prusa i3 MK3S+", shortWheelName: "Prusa MK3S+", bedWidthMM: 250, bedDepthMM: 210, bedHeightMM: 210, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "prusa-mini", brand: "Prusa", name: "Original Prusa MINI+", shortWheelName: "Prusa MINI+", bedWidthMM: 180, bedDepthMM: 180, bedHeightMM: 180, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "prusa-xl", brand: "Prusa", name: "Original Prusa XL", shortWheelName: "Prusa XL", bedWidthMM: 360, bedDepthMM: 360, bedHeightMM: 360, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),

        // MARK: Qidi Tech
        Printer3DModel(id: "qidi-plus-4", brand: "Qidi Tech", name: "Qidi Plus 4", shortWheelName: "Qidi Plus 4", bedWidthMM: 305, bedDepthMM: 305, bedHeightMM: 280, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "qidi-q1-pro", brand: "Qidi Tech", name: "Qidi Q1 Pro", shortWheelName: "Qidi Q1 Pro", bedWidthMM: 245, bedDepthMM: 245, bedHeightMM: 240, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "qidi-x-max-3", brand: "Qidi Tech", name: "Qidi X-Max 3", shortWheelName: "Qidi X-Max3", bedWidthMM: 325, bedDepthMM: 325, bedHeightMM: 315, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "qidi-x-plus-3", brand: "Qidi Tech", name: "Qidi X-Plus 3", shortWheelName: "Qidi X-Plus3", bedWidthMM: 280, bedDepthMM: 280, bedHeightMM: 270, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "qidi-x-smart-3", brand: "Qidi Tech", name: "Qidi X-Smart 3", shortWheelName: "X-Smart 3", bedWidthMM: 175, bedDepthMM: 180, bedHeightMM: 170, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),

        // MARK: Sovol
        Printer3DModel(id: "sovol-sv08", brand: "Sovol", name: "Sovol SV08", shortWheelName: "Sovol SV08", bedWidthMM: 350, bedDepthMM: 350, bedHeightMM: 345, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "sovol-sv06-ace", brand: "Sovol", name: "Sovol SV06 ACE", shortWheelName: "SV06 ACE", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "sovol-sv06", brand: "Sovol", name: "Sovol SV06", shortWheelName: "Sovol SV06", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "sovol-sv06-plus", brand: "Sovol", name: "Sovol SV06 Plus", shortWheelName: "SV06 Plus", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 340, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "sovol-sv07", brand: "Sovol", name: "Sovol SV07", shortWheelName: "Sovol SV07", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "sovol-sv07-plus", brand: "Sovol", name: "Sovol SV07 Plus", shortWheelName: "SV07 Plus", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 350, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),

        // MARK: Artillery
        Printer3DModel(id: "artillery-sw-x4-pro", brand: "Artillery", name: "Artillery Sidewinder X4 Pro", shortWheelName: "SW X4 Pro", bedWidthMM: 240, bedDepthMM: 240, bedHeightMM: 260, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "artillery-sw-x4-plus", brand: "Artillery", name: "Artillery Sidewinder X4 Plus", shortWheelName: "SW X4 Plus", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 400, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "artillery-sw-x2", brand: "Artillery", name: "Artillery Sidewinder X2", shortWheelName: "SW X2", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 400, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),
        Printer3DModel(id: "artillery-genius-pro", brand: "Artillery", name: "Artillery Genius Pro", shortWheelName: "Genius Pro", bedWidthMM: 220, bedDepthMM: 220, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),

        // MARK: Flsun
        Printer3DModel(id: "flsun-s1", brand: "Flsun", name: "Flsun S1", shortWheelName: "Flsun S1", bedWidthMM: 320, bedDepthMM: 320, bedHeightMM: 430, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "flsun-t1", brand: "Flsun", name: "Flsun T1", shortWheelName: "Flsun T1", bedWidthMM: 260, bedDepthMM: 260, bedHeightMM: 330, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "flsun-v400", brand: "Flsun", name: "Flsun V400", shortWheelName: "Flsun V400", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 410, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "flsun-sr", brand: "Flsun", name: "Flsun Super Racer", shortWheelName: "Flsun SR", bedWidthMM: 260, bedDepthMM: 260, bedHeightMM: 330, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false),

        // MARK: Voron
        Printer3DModel(id: "voron-24-350", brand: "Voron", name: "Voron 2.4 350mm", shortWheelName: "Voron 350", bedWidthMM: 350, bedDepthMM: 350, bedHeightMM: 330, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "voron-24-300", brand: "Voron", name: "Voron 2.4 300mm", shortWheelName: "Voron 300", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 280, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "voron-trident-300", brand: "Voron", name: "Voron Trident 300mm", shortWheelName: "Trident 300", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 250, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "voron-02", brand: "Voron", name: "Voron 0.2 120mm", shortWheelName: "Voron 0.2", bedWidthMM: 120, bedDepthMM: 120, bedHeightMM: 120, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),

        // MARK: Two Trees
        Printer3DModel(id: "twotrees-sk1", brand: "Two Trees", name: "Two Trees SK1", shortWheelName: "TwoTrees SK1", bedWidthMM: 256, bedDepthMM: 256, bedHeightMM: 256, nozzleDiameterMM: 0.4, gcodeFlavor: "klipper", showInWheel: false),
        Printer3DModel(id: "twotrees-sp5", brand: "Two Trees", name: "Two Trees Sapphire Plus", shortWheelName: "Sapphire+", bedWidthMM: 300, bedDepthMM: 300, bedHeightMM: 350, nozzleDiameterMM: 0.4, gcodeFlavor: "marlin", showInWheel: false)
    ]

    public static let defaultCatalog: [Printer3DModel] = [
        Printer3DModel(
            id: "anycubic-kobra-x",
            brand: "Anycubic",
            name: "Anycubic Kobra X",
            shortWheelName: "Kobra X",
            bedWidthMM: 260,
            bedDepthMM: 260,
            bedHeightMM: 260,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Anycubic Kobra X 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "anycubic-kobra-3",
            brand: "Anycubic",
            name: "Anycubic Kobra 3",
            shortWheelName: "Kobra 3",
            bedWidthMM: 250,
            bedDepthMM: 250,
            bedHeightMM: 260,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Anycubic Kobra 3 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "bambu-a1-mini",
            brand: "Bambu Lab",
            name: "Bambu Lab A1 mini",
            shortWheelName: "A1 mini",
            bedWidthMM: 180,
            bedDepthMM: 180,
            bedHeightMM: 180,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "marlin",
            printerSettingsID: "Bambu Lab A1 mini 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "bambu-a1",
            brand: "Bambu Lab",
            name: "Bambu Lab A1",
            shortWheelName: "Bambu A1",
            bedWidthMM: 256,
            bedDepthMM: 256,
            bedHeightMM: 256,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "marlin",
            printerSettingsID: "Bambu Lab A1 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "bambu-p1s",
            brand: "Bambu Lab",
            name: "Bambu Lab P1S",
            shortWheelName: "Bambu P1S",
            bedWidthMM: 256,
            bedDepthMM: 256,
            bedHeightMM: 256,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "marlin",
            printerSettingsID: "Bambu Lab P1S 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "bambu-x1c",
            brand: "Bambu Lab",
            name: "Bambu Lab X1 Carbon",
            shortWheelName: "X1 Carbon",
            bedWidthMM: 256,
            bedDepthMM: 256,
            bedHeightMM: 256,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "marlin",
            printerSettingsID: "Bambu Lab X1 Carbon 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "creality-k1",
            brand: "Creality",
            name: "Creality K1",
            shortWheelName: "Creality K1",
            bedWidthMM: 220,
            bedDepthMM: 220,
            bedHeightMM: 250,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Creality K1 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "creality-k1-max",
            brand: "Creality",
            name: "Creality K1 Max",
            shortWheelName: "K1 Max",
            bedWidthMM: 300,
            bedDepthMM: 300,
            bedHeightMM: 300,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Creality K1 Max 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "flashforge-adv5m-pro",
            brand: "Flashforge",
            name: "Flashforge Adventurer 5M Pro",
            shortWheelName: "Adv 5M Pro",
            bedWidthMM: 220,
            bedDepthMM: 220,
            bedHeightMM: 220,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Flashforge Adventurer 5M Pro 0.4 nozzle",
            showInWheel: true
        ),
        Printer3DModel(
            id: "bambu-p1p",
            brand: "Bambu Lab",
            name: "Bambu Lab P1P",
            shortWheelName: "Bambu P1P",
            bedWidthMM: 256,
            bedDepthMM: 256,
            bedHeightMM: 256,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "marlin",
            printerSettingsID: "Bambu Lab P1P 0.4 nozzle",
            showInWheel: false
        ),
        Printer3DModel(
            id: "creality-k2-plus",
            brand: "Creality",
            name: "Creality K2 Plus",
            shortWheelName: "K2 Plus",
            bedWidthMM: 350,
            bedDepthMM: 350,
            bedHeightMM: 350,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Creality K2 Plus 0.4 nozzle",
            showInWheel: false
        ),
        Printer3DModel(
            id: "creality-ender3-v3",
            brand: "Creality",
            name: "Creality Ender-3 V3",
            shortWheelName: "Ender-3 V3",
            bedWidthMM: 220,
            bedDepthMM: 220,
            bedHeightMM: 250,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Creality Ender-3 V3 0.4 nozzle",
            showInWheel: false
        ),
        Printer3DModel(
            id: "flashforge-adv5m",
            brand: "Flashforge",
            name: "Flashforge Adventurer 5M",
            shortWheelName: "Adv 5M",
            bedWidthMM: 220,
            bedDepthMM: 220,
            bedHeightMM: 220,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Flashforge Adventurer 5M 0.4 nozzle",
            showInWheel: false
        ),
        Printer3DModel(
            id: "elegoo-neptune4-pro",
            brand: "Elegoo",
            name: "Elegoo Neptune 4 Pro",
            shortWheelName: "Neptune 4",
            bedWidthMM: 225,
            bedDepthMM: 225,
            bedHeightMM: 265,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "klipper",
            printerSettingsID: "Elegoo Neptune 4 Pro 0.4 nozzle",
            showInWheel: false
        ),
        Printer3DModel(
            id: "prusa-mk4",
            brand: "Prusa",
            name: "Original Prusa MK4",
            shortWheelName: "Prusa MK4",
            bedWidthMM: 250,
            bedDepthMM: 210,
            bedHeightMM: 220,
            nozzleDiameterMM: 0.4,
            gcodeFlavor: "marlin",
            printerSettingsID: "Original Prusa MK4 Input Shaper 0.4 nozzle",
            showInWheel: false
        )
    ]
}

public enum ThreeMFOptimizationPreset: String, CaseIterable, Identifiable, Codable, Equatable {
    case keepOriginal
    case standardQuality
    case detailedFigure
    case fastEconomic
    case strongMechanical

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .keepOriginal: return "Manter Ajustes Originais do Projeto"
        case .standardQuality: return "Padrão Equilibrado (0.20mm · 2 Paredes · 15%)"
        case .detailedFigure: return "Boneco / Alta Qualidade (0.12mm · 3 Paredes)"
        case .fastEconomic: return "Rápido e Econômico (0.24mm · 2 Paredes · 10%)"
        case .strongMechanical: return "Peça Mecânica / Forte (0.20mm · 4 Paredes · 35% Gyroid)"
        }
    }
}

public struct ThreeMFFilamentSlot: Identifiable, Equatable, Codable {
    public var id: Int
    public var type: String
    public var colorHex: String
    public var usedGrams: Double?
    public var usedMeters: Double?

    public init(id: Int, type: String, colorHex: String, usedGrams: Double? = nil, usedMeters: Double? = nil) {
        self.id = id
        self.type = type
        self.colorHex = colorHex
        self.usedGrams = usedGrams
        self.usedMeters = usedMeters
    }
}

public struct ThreeMFProjectInfo: Equatable {
    public var fileName: String = ""
    public var currentPrinterModel: String = "Não identificada"
    public var printerSettingsID: String = ""
    public var nozzleDiameter: String = "0.4"
    public var bedWidthMM: Int = 256
    public var bedDepthMM: Int = 256
    public var bedHeightMM: Int = 256
    public var layerHeight: String = "0.20"
    public var infillDensity: String = "15%"
    public var wallLoops: String = "2"
    public var supportEnabled: Bool = false
    public var plateCount: Int = 1
    public var objectCount: Int = 1
    public var objectNames: [String] = []
    public var filaments: [ThreeMFFilamentSlot] = []
    public var estimatedTimeSeconds: Int = 0
    public var totalWeightGrams: Double = 0
    public var thumbnail: NSImage? = nil
    public var slicerApplication: String = ""

    public init() {}
}

public struct FileToolOptions: Equatable {
    public var metadataFields: [MetadataField] = []
    public var removeAllMetadata: Bool = true
    public var compressionTargetMode: CompressionTargetMode = .preset
    public var targetVideoEncoding: TargetVideoEncoding = .accurate
    public var targetSizeText: String = "5"
    public var targetSizeUnit: String = "MB"
    public var compressionReductionPercentage: Double = 50
    public var imageCompression = ImageCompressionOptions()
    public var imageAdjustments = ImageAdjustments()
    public var annotations: [ImageAnnotation] = []
    public var imageFrame = FrameImageOptions()
    public var videoCompression = VideoCompressionOptions()
    public var normalizationTargetLoudness: Double = -16.0
    public var normalizationLoudnessRange: Double = 11.0
    public var normalizationTruePeak: Double = -1.5
    public var trimStartSeconds: Double = 0
    public var trimDurationSeconds: Double = 10
    public var cropSelection = CropSelection()
    public var cropSelections: [URL: CropSelection] = [:]
    public var useSharedCropForAllImages: Bool = true
    public var playbackSpeed: Double = 1.5
    public var snapshotTimes: [Double] = [0]
    public var splitTimes: [Double] = []
    public var splitRemovedClips: Set<Int> = []
    public var splitExportMode: SplitExportMode = .clips
    public var audioVisualization: AudioVisualizationStyle = .waveform
    public var staticImageURL: URL?
    public var videoCanvas: MediaCanvas = .landscape
    public var autoTrimSilence: Bool = false
    public var silenceThresholdDB: Double = -40
    public var audioChannelCount: Int = 2
    public var audioLeftVolume: Double = 1.0
    public var audioRightVolume: Double = 1.0
    public var collage = CollageOptions()
    public var redactions: [RedactionRectangle] = []
    public var redactionStyle: RedactionStyle = .solid
    public var bleepRanges: [RedactionTimeRange] = []
    public var pdfPageOrder: [Int] = []
    public var pdfPageRotations: [Int: Int] = [:]
    public var equalizePDFPageWidths: Bool = false
    public var target3MFPrinterID: String = "anycubic-kobra-x"
    public var threeMFPreset: ThreeMFOptimizationPreset = .keepOriginal
    public var recenter3MFOnBed: Bool = true
    public var preserve3MFFilaments: Bool = true

    public init() {}
}

public struct ConversionTaskRecord: Identifiable, Equatable {
    public let id = UUID()
    public let sourceName: String
    public let targetTitle: String
}

public final class ConversionTaskStore: ObservableObject {
    @Published public var activeTasks: [ConversionTaskRecord] = []
    public var onChange: (() -> Void)?

    public init() {}

    public func addTask(sourceName: String, targetTitle: String) -> UUID {
        let record = ConversionTaskRecord(sourceName: sourceName, targetTitle: targetTitle)
        DispatchQueue.main.async {
            self.activeTasks.append(record)
            self.onChange?()
        }
        return record.id
    }

    public func removeTask(id: UUID) {
        DispatchQueue.main.async {
            self.activeTasks.removeAll { $0.id == id }
            self.onChange?()
        }
    }
}

public enum ConversionError: LocalizedError {
    case unsupportedPair(String, String)
    case missingTool(String)
    case processFailed(String)
    case encodingFailed(String)
    case fileToolUnavailable(String)
    case invalidFileToolOptions(String)
    case unsupportedSource(String)
    case outputMissing
    case sourceCannotBeRead

    public var errorDescription: String? {
        switch self {
        case .unsupportedPair(let src, let dst):
            return "Conversion from \(src) to \(dst) is unavailable."
        case .missingTool(let tool):
            return "\(tool) is required for this conversion."
        case .processFailed(let msg):
            return msg.isEmpty ? "The conversion process failed." : msg
        case .encodingFailed(let msg):
            return msg
        case .fileToolUnavailable(let tool):
            return "\(tool) is unavailable for this file type."
        case .invalidFileToolOptions(let msg):
            return msg
        case .unsupportedSource(let name):
            return "Unsupported file type: \(name)"
        case .outputMissing:
            return "The converter finished without creating an output file."
        case .sourceCannotBeRead:
            return "The source file could not be read."
        }
    }
}
