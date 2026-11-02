import Foundation
import AppKit
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

public final class ToolExecutionEngine {
    public static let shared = ToolExecutionEngine()

    public init() {}

    public func execute(tool: FileTool, urls: [URL], options: FileToolOptions, taskStore: ConversionTaskStore) {
        let progressWC = OperationProgressWindowController(title: tool.title, itemCount: urls.count)
        progressWC.show()

        DispatchQueue.global(qos: .userInitiated).async {
            var outputs: [URL] = []
            var failures: [String] = []

            let taskID = taskStore.addTask(sourceName: urls.first?.lastPathComponent ?? "Batch", targetTitle: tool.title)
            defer { taskStore.removeTask(id: taskID) }

            do {
                switch tool {
                case .createArchive:
                    let out = try ArchiveConverter.packItems(urls: urls, targetFormat: .zip)
                    outputs.append(out)
                    UnlockStore.shared.recordUsage(count: 1)
                case .mergePDF:
                    let out = try self.mergePDFs(urls: urls)
                    outputs.append(out)
                case .createPDF:
                    let out = try self.createPDFFromImages(urls: urls)
                    outputs.append(out)
                case .createCollage:
                    let out = try self.createCollage(urls: urls, options: options.collage)
                    outputs.append(out)
                case .joinVideos:
                    let out = try self.joinVideos(urls: urls)
                    outputs.append(out)
                default:
                    for (idx, url) in urls.enumerated() {
                        progressWC.update(
                            progress: Double(idx) / Double(max(urls.count, 1)),
                            status: "\(tool.title): \(url.lastPathComponent)"
                        )
                        do {
                            let fileOuts = try self.executeSingle(tool: tool, url: url, options: options)
                            outputs.append(contentsOf: fileOuts)
                            UnlockStore.shared.recordUsage(count: 1)
                        } catch {
                            failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                failures.append(error.localizedDescription)
            }

            progressWC.finish(outputs: outputs, failures: failures)
        }
    }

    private func executeSingle(tool: FileTool, url: URL, options: FileToolOptions) throws -> [URL] {
        let dir = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        switch tool {
        case .removeMetadata:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Cleaned", ext: ext)
            try removeMetadata(srcURL: url, outURL: outURL, options: options)
            return [outURL]

        case .compress:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Compressed", ext: ext)
            try compressFile(srcURL: url, outURL: outURL, options: options)
            return [outURL]

        case .editImage:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Edited", ext: ext.isEmpty ? "png" : ext)
            guard let img = NSImage(contentsOf: url) else { throw ConversionError.sourceCannotBeRead }
            let edited = Self.applyCoreImageAdjustments(to: img, adjustments: options.imageAdjustments)
            try Self.saveNSImage(edited, to: outURL)
            return [outURL]

        case .frameImage:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Framed", ext: "png")
            guard let img = NSImage(contentsOf: url) else { throw ConversionError.sourceCannotBeRead }
            let framed = try renderFramedImage(img, frameOptions: options.imageFrame)
            try Self.saveNSImage(framed, to: outURL)
            return [outURL]

        case .cropImage:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Cropped", ext: ext.isEmpty ? "png" : ext)
            let chosenCrop = (!options.useSharedCropForAllImages ? options.cropSelections[url] : nil) ?? options.cropSelection
            try cropImage(srcURL: url, outURL: outURL, crop: chosenCrop)
            return [outURL]

        case .annotateImage:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Annotated", ext: "png")
            guard let img = NSImage(contentsOf: url) else { throw ConversionError.sourceCannotBeRead }
            let annotated = renderAnnotations(on: img, annotations: options.annotations)
            try Self.saveNSImage(annotated, to: outURL)
            return [outURL]

        case .redactImage:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Redacted", ext: "png")
            guard let img = NSImage(contentsOf: url) else { throw ConversionError.sourceCannotBeRead }
            let redacted = renderRedactions(on: img, rectangles: options.redactions, style: options.redactionStyle)
            try Self.saveNSImage(redacted, to: outURL)
            return [outURL]

        case .organizePDF:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Organized", ext: "pdf")
            try organizePDF(srcURL: url, outURL: outURL, options: options)
            return [outURL]

        case .splitPDF:
            return try splitPDF(srcURL: url)

        case .extractArchive:
            let outDir = UniqueOutputURL.make(in: dir, baseName: base, ext: "")
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            try ArchiveConverter.extract(archiveURL: url, to: outDir)
            return [outDir]

        case .muteVideo:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Muted", ext: ext)
            try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: ["-y", "-i", url.path, "-c:v", "copy", "-an", outURL.path])
            return [outURL]

        case .trimVideo, .trimAudio:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Trimmed", ext: ext)
            let start = String(format: "%.3f", options.trimStartSeconds)
            let dur = String(format: "%.3f", options.trimDurationSeconds)
            try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: ["-y", "-ss", start, "-i", url.path, "-t", dur, outURL.path])
            return [outURL]

        case .changeVideoSpeed:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) \(String(format: "%gx", options.playbackSpeed))", ext: ext)
            let spd = max(min(options.playbackSpeed, 4.0), 0.25)
            let vFilter = "setpts=(PTS-STARTPTS)/\(spd)"
            let aFilter = "atempo=\(min(max(spd, 0.5), 2.0))"
            try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
                "-y", "-i", url.path,
                "-vf", vFilter, "-af", aFilter,
                "-c:v", "h264_videotoolbox", "-q:v", "72", "-c:a", "aac", "-b:a", "192k",
                outURL.path
            ])
            return [outURL]

        case .cropVideo:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Cropped", ext: ext)
            let c = options.cropSelection
            let vf = "crop=trunc(iw*\(c.width)/2)*2:trunc(ih*\(c.height)/2)*2:trunc(iw*\(c.x)/2)*2:trunc(ih*\(c.y)/2)*2"
            try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
                "-y", "-i", url.path,
                "-vf", vf,
                "-c:v", "h264_videotoolbox", "-q:v", "72", "-c:a", "copy",
                outURL.path
            ])
            return [outURL]

        case .normalizeAudio:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Normalized", ext: ext)
            let af = "loudnorm=I=\(options.normalizationTargetLoudness):LRA=\(options.normalizationLoudnessRange):TP=\(options.normalizationTruePeak)"
            try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: ["-y", "-i", url.path, "-af", af, outURL.path])
            return [outURL]

        case .audioChannels:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Channels", ext: ext)
            let af: String
            if options.audioChannelCount == 1 {
                af = "aformat=channel_layouts=mono"
            } else {
                af = "aformat=channel_layouts=stereo,pan=stereo|c0=\(options.audioLeftVolume)*c0|c1=\(options.audioRightVolume)*c1"
            }
            try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: ["-y", "-i", url.path, "-af", af, outURL.path])
            return [outURL]

        case .audioToVideo:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Visualizer", ext: "mp4")
            let size = options.videoCanvas.dimensions
            let w = Int(size.width)
            let h = Int(size.height)
            if options.audioVisualization == .staticImage, let imgURL = options.staticImageURL {
                let vf = "scale=\(w):\(h):force_original_aspect_ratio=decrease:force_divisible_by=2,pad=\(w):\(h):(ow-iw)/2:(oh-ih)/2,setsar=1,fps=30,format=yuv420p"
                try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
                    "-y", "-loop", "1", "-i", imgURL.path, "-i", url.path,
                    "-vf", vf,
                    "-map", "0:v:0", "-map", "1:a:0",
                    "-c:v", "h264_videotoolbox", "-q:v", "72",
                    "-c:a", "aac", "-b:a", "192k", "-shortest",
                    outURL.path
                ])
            } else {
                let filter = "color=c=0x121214:s=\(w)x\(h):r=30[bg];[0:a]showwaves=s=\(w)x\(h):mode=cline:rate=30:colors=0xff5200:scale=sqrt,format=yuva420p[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2:shortest=1,format=yuv420p[v]"
                try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
                    "-y", "-i", url.path,
                    "-filter_complex", filter,
                    "-map", "[v]", "-map", "0:a:0",
                    "-c:v", "h264_videotoolbox", "-q:v", "72",
                    "-c:a", "aac", "-b:a", "192k", "-shortest",
                    outURL.path
                ])
            }
            return [outURL]

        case .videoSnapshots:
            var outs: [URL] = []
            for (idx, t) in options.snapshotTimes.enumerated() {
                let outURL = UniqueOutputURL.make(in: dir, baseName: String(format: "%@ - Frame %03d (%.2fs)", base, idx + 1, t), ext: "png")
                try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
                    "-y", "-ss", String(format: "%.3f", t), "-i", url.path, "-frames:v", "1", outURL.path
                ])
                outs.append(outURL)
            }
            return outs

        case .splitVideo:
            let pts = [0.0] + options.splitTimes.sorted()
            var outs: [URL] = []
            for i in 0..<pts.count {
                let start = pts[i]
                let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Part \(i + 1)", ext: ext)
                var args = ["-y", "-ss", String(format: "%.3f", start), "-i", url.path]
                if i + 1 < pts.count {
                    let dur = max(pts[i + 1] - start, 0.1)
                    args += ["-t", String(format: "%.3f", dur)]
                }
                args += ["-c:v", "h264_videotoolbox", "-q:v", "72", "-c:a", "aac", outURL.path]
                try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: args)
                outs.append(outURL)
            }
            return outs

        case .redactVideo:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Redacted", ext: ext)
            if options.redactions.isEmpty {
                try FileManager.default.copyItem(at: url, to: outURL)
                return [outURL]
            }
            if options.redactionStyle == .blur {
                var chain: [String] = []
                var currentLabel = "0:v"
                for (idx, r) in options.redactions.enumerated() {
                    let rx = String(format: "%.4f", max(0.0, min(r.x, 0.98)))
                    let ry = String(format: "%.4f", max(0.0, min(r.y, 0.98)))
                    let rw = String(format: "%.4f", max(0.02, min(r.width, 1.0 - r.x)))
                    let rh = String(format: "%.4f", max(0.02, min(r.height, 1.0 - r.y)))
                    let boxLabel = "blur\(idx)"
                    let nextLabel = "v\(idx + 1)"
                    chain.append("[0:v]crop=iw*\(rw):ih*\(rh):iw*\(rx):ih*\(ry),gblur=sigma=24[\(boxLabel)]")
                    if let tr = r.timeRange {
                        let s = String(format: "%.3f", tr.start)
                        let e = String(format: "%.3f", tr.end)
                        chain.append("[\(currentLabel)][\(boxLabel)]overlay=x=W*\(rx):y=H*\(ry):enable='between(t,\(s),\(e))'[\(nextLabel)]")
                    } else {
                        chain.append("[\(currentLabel)][\(boxLabel)]overlay=x=W*\(rx):y=H*\(ry)[\(nextLabel)]")
                    }
                    currentLabel = nextLabel
                }
                let fc = chain.joined(separator: ";")
                try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
                    "-y", "-i", url.path,
                    "-filter_complex", fc,
                    "-map", "[\(currentLabel)]", "-map", "0:a?",
                    "-c:v", "h264_videotoolbox", "-q:v", "72", "-c:a", "copy",
                    outURL.path
                ])
            } else {
                var filters: [String] = []
                for r in options.redactions {
                    let rx = String(format: "%.4f", max(0.0, min(r.x, 0.99)))
                    let ry = String(format: "%.4f", max(0.0, min(r.y, 0.99)))
                    let rw = String(format: "%.4f", max(0.01, min(r.width, 1.0 - r.x)))
                    let rh = String(format: "%.4f", max(0.01, min(r.height, 1.0 - r.y)))
                    var box = "drawbox=x=iw*\(rx):y=ih*\(ry):w=iw*\(rw):h=ih*\(rh):color=black@1:t=fill"
                    if let tr = r.timeRange {
                        box += ":enable='between(t,\(String(format: "%.3f", tr.start)),\(String(format: "%.3f", tr.end)))'"
                    }
                    filters.append(box)
                }
                let vf = filters.isEmpty ? "null" : filters.joined(separator: ",")
                try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
                    "-y", "-i", url.path,
                    "-vf", vf,
                    "-c:v", "h264_videotoolbox", "-q:v", "72", "-c:a", "copy",
                    outURL.path
                ])
            }
            return [outURL]

        case .redactAudio:
            let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) Bleeped", ext: ext)
            let ranges = options.bleepRanges.isEmpty ? [RedactionTimeRange(start: 0, end: 1.5)] : options.bleepRanges
            let conds = ranges.map { "between(t,\($0.start),\($0.end))" }.joined(separator: "+")
            let af = "asetpts=PTS-STARTPTS,aeval=exprs='if(gt(\(conds),0),0.18*sin(2*PI*1000*t),val(ch))':c=same"
            try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: ["-y", "-i", url.path, "-af", af, outURL.path])
            return [outURL]

        case .convert3MF:
            let printers = FlowConverterSettingsModel.shared.printers3D
            let targetPrinter = printers.first(where: { $0.id == options.target3MFPrinterID })
                ?? Printer3DModel.defaultCatalog.first(where: { $0.id == options.target3MFPrinterID })
                ?? printers.first
                ?? Printer3DModel.defaultCatalog[0]
            let outURL = try ThreeMFConverterEngine.convert(srcURL: url, targetPrinter: targetPrinter, options: options)
            return [outURL]

        default:
            throw ConversionError.fileToolUnavailable(tool.title)
        }
    }

    // MARK: - Native Metadata Removal (ImageIO / PDFKit / FFmpeg)

    private func removeMetadata(srcURL: URL, outURL: URL, options: FileToolOptions) throws {
        let fmt = ConversionFormat.detect(from: srcURL)
        if fmt?.group == .images,
           let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
           let cgImg = CGImageSourceCreateImageAtIndex(src, 0, nil),
           let type = CGImageSourceGetType(src),
           let dst = CGImageDestinationCreateWithURL(outURL as CFURL, type, 1, nil) {
            CGImageDestinationAddImage(dst, cgImg, nil)
            if CGImageDestinationFinalize(dst) {
                return
            }
        }
        if fmt == .pdf, let pdf = PDFDocument(url: srcURL) {
            pdf.documentAttributes = [:]
            if pdf.write(to: outURL) {
                return
            }
        }
        try FileManager.default.copyItem(at: srcURL, to: outURL)
        let tempOut = outURL.deletingLastPathComponent().appendingPathComponent(".flowconverter-meta-\(UUID().uuidString).\(srcURL.pathExtension)")
        defer { try? FileManager.default.removeItem(at: tempOut) }
        try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: ["-y", "-i", srcURL.path, "-map_metadata", "-1", "-c", "copy", tempOut.path])
        _ = try? FileManager.default.replaceItemAt(outURL, withItemAt: tempOut)
    }

    // MARK: - Compression

    private func compressFile(srcURL: URL, outURL: URL, options: FileToolOptions) throws {
        let fmt = ConversionFormat.detect(from: srcURL)
        if fmt == .pdf {
            guard let pdf = PDFDocument(url: srcURL), pdf.write(to: outURL) else {
                throw ConversionError.encodingFailed("Could not create the compressed PDF.")
            }
            return
        }
        if fmt?.group == .images {
            guard let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil),
                  let cgImg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                throw ConversionError.sourceCannotBeRead
            }
            let quality: Double = (options.imageCompression.strength == .strong) ? 0.52 : 0.74
            guard let dst = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw ConversionError.encodingFailed("ImageIO could not create the compressed image.")
            }
            var props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
            if let maxEdge = options.imageCompression.size.maxLongestEdge {
                props[kCGImageDestinationImageMaxPixelSize] = maxEdge
            }
            CGImageDestinationAddImage(dst, cgImg, props as CFDictionary)
            guard CGImageDestinationFinalize(dst) else {
                throw ConversionError.encodingFailed("ImageIO could not finish the compressed image.")
            }
            return
        }
        // Video/Audio compression via FFmpeg (Hardware VideoToolbox H.264)
        let qv = (options.videoCompression.strength == .strong) ? "48" : "65"
        try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
            "-y", "-i", srcURL.path, "-c:v", "h264_videotoolbox", "-q:v", qv, "-c:a", "aac", "-b:a", "128k", outURL.path
        ])
    }

    // MARK: - CoreImage Photo Adjustments

    public static func applyCoreImageAdjustments(to image: NSImage, adjustments: ImageAdjustments) -> NSImage {
        guard let cgImg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        var ci = CIImage(cgImage: cgImg)

        if adjustments.exposure != 0, let f = CIFilter(name: "CIExposureAdjust") {
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(adjustments.exposure, forKey: kCIInputEVKey)
            if let out = f.outputImage { ci = out }
        }

        if adjustments.brightness != 0 || adjustments.contrast != 0 || adjustments.saturation != 0,
           let f = CIFilter(name: "CIColorControls") {
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
            f.setValue(1.0 + adjustments.contrast, forKey: kCIInputContrastKey)
            f.setValue(1.0 + adjustments.saturation, forKey: kCIInputSaturationKey)
            if let out = f.outputImage { ci = out }
        }

        if adjustments.sharpness > 0, let f = CIFilter(name: "CISharpenLuminance") {
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(adjustments.sharpness, forKey: kCIInputSharpnessKey)
            if let out = f.outputImage { ci = out }
        }

        if adjustments.vignette > 0, let f = CIFilter(name: "CIVignette") {
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(adjustments.vignette, forKey: kCIInputIntensityKey)
            f.setValue(1.5, forKey: kCIInputRadiusKey)
            if let out = f.outputImage { ci = out }
        }

        if adjustments.blur > 0, let f = CIFilter(name: "CIGaussianBlur") {
            let extent = ci.extent
            f.setValue(ci.clampedToExtent(), forKey: kCIInputImageKey)
            f.setValue(adjustments.blur, forKey: kCIInputRadiusKey)
            if let out = f.outputImage?.cropped(to: extent) { ci = out }
        }

        let ctx = CIContext()
        guard let outCG = ctx.createCGImage(ci, from: ci.extent) else { return image }
        return NSImage(cgImage: outCG, size: image.size)
    }

    // MARK: - Frame Image, Crop, Annotate, Redact, Collage

    private func renderFramedImage(_ image: NSImage, frameOptions: FrameImageOptions) throws -> NSImage {
        let pad = CGFloat(frameOptions.padding)
        let imgW = max(image.size.width, 64)
        let imgH = max(image.size.height, 64)
        var canvasW = imgW + pad * 2
        var canvasH = imgH + pad * 2

        switch frameOptions.canvasRatio {
        case .square:
            let side = max(canvasW, canvasH)
            canvasW = side; canvasH = side
        case .landscape:
            canvasW = max(canvasW, canvasH * 16.0 / 9.0)
        case .portrait:
            canvasH = max(canvasH, canvasW * 16.0 / 9.0)
        case .automatic:
            break
        }

        let targetSize = NSSize(width: canvasW, height: canvasH)
        let out = NSImage(size: targetSize)
        out.lockFocus()
        let rect = NSRect(origin: .zero, size: targetSize)
        let colors = frameOptions.background.previewColors
        if let grad = NSGradient(colors: colors) {
            grad.draw(in: rect, angle: -45)
        }

        let drawRect = NSRect(
            x: (canvasW - imgW) / 2.0,
            y: (canvasH - imgH) / 2.0,
            width: imgW,
            height: imgH
        )

        NSGraphicsContext.saveGraphicsState()
        if frameOptions.shadowRadius > 0 {
            let shadow = NSShadow()
            shadow.shadowBlurRadius = CGFloat(frameOptions.shadowRadius)
            shadow.shadowOffset = NSSize(width: 0, height: -8)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.38)
            shadow.set()
        }
        let clipPath = NSBezierPath(roundedRect: drawRect, xRadius: CGFloat(frameOptions.cornerRadius), yRadius: CGFloat(frameOptions.cornerRadius))
        clipPath.addClip()
        image.draw(in: drawRect)
        NSGraphicsContext.restoreGraphicsState()
        out.unlockFocus()
        return out
    }

    private func cropImage(srcURL: URL, outURL: URL, crop: CropSelection) throws {
        let orientedCG: CGImage? = {
            if let ci = CIImage(contentsOf: srcURL, options: [.applyOrientationProperty: true]) {
                let ctx = CIContext(options: nil)
                let extent = ci.extent
                if extent.width > 0 && extent.height > 0, let cg = ctx.createCGImage(ci, from: extent) {
                    return cg
                }
            }
            if let src = CGImageSourceCreateWithURL(srcURL as CFURL, nil) {
                return CGImageSourceCreateImageAtIndex(src, 0, nil)
            }
            return nil
        }()
        guard let cg = orientedCG else {
            throw ConversionError.sourceCannotBeRead
        }
        let w = Double(cg.width)
        let h = Double(cg.height)
        let x = max(0, min(crop.x * w, w - 2))
        let y = max(0, min(crop.y * h, h - 2))
        let cropW = max(2, min(crop.width * w, w - x))
        let cropH = max(2, min(crop.height * h, h - y))
        let rect = CGRect(
            x: round(x),
            y: round(y),
            width: round(cropW),
            height: round(cropH)
        )
        guard let cropped = cg.cropping(to: rect) else {
            throw ConversionError.encodingFailed("Could not create the cropped image.")
        }
        let nsImg = NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
        try Self.saveNSImage(nsImg, to: outURL)
    }

    private func renderAnnotations(on image: NSImage, annotations: [ImageAnnotation]) -> NSImage {
        let out = NSImage(size: image.size)
        out.lockFocus()
        let w = image.size.width
        let h = image.size.height
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))

        for ann in annotations {
            let color = NSColor(srgbRed: ann.red, green: ann.green, blue: ann.blue, alpha: 1.0)
            color.set()
            let rect = NSRect(
                x: CGFloat(ann.x) * w,
                y: (1.0 - CGFloat(ann.y) - 0.15) * h,
                width: max(80, w * 0.25),
                height: max(50, h * 0.15)
            )
            switch ann.kind {
            case .rectangle:
                let path = NSBezierPath(rect: rect)
                path.lineWidth = 4
                path.stroke()
            case .ellipse:
                let path = NSBezierPath(ovalIn: rect)
                path.lineWidth = 4
                path.stroke()
            case .text:
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: CGFloat(ann.fontSize)),
                    .foregroundColor: color
                ]
                (ann.text as NSString).draw(at: rect.origin, withAttributes: attrs)
            default:
                let path = NSBezierPath()
                path.lineWidth = 4
                path.move(to: rect.origin)
                path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
                path.stroke()
            }
        }
        out.unlockFocus()
        return out
    }

    private func renderRedactions(on image: NSImage, rectangles: [RedactionRectangle], style: RedactionStyle) -> NSImage {
        if style == .blur, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let baseCI = CIImage(cgImage: cg)
            let extent = baseCI.extent
            var composited = baseCI
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(baseCI.clampedToExtent(), forKey: kCIInputImageKey)
                blurFilter.setValue(24.0, forKey: kCIInputRadiusKey)
                if let blurredFull = blurFilter.outputImage?.cropped(to: extent) {
                    for r in rectangles {
                        let cropRect = CGRect(
                            x: CGFloat(r.x) * extent.width,
                            y: (1.0 - CGFloat(r.y) - CGFloat(r.height)) * extent.height,
                            width: CGFloat(r.width) * extent.width,
                            height: CGFloat(r.height) * extent.height
                        ).intersection(extent)
                        if !cropRect.isEmpty {
                            let patch = blurredFull.cropped(to: cropRect)
                            composited = patch.composited(over: composited)
                        }
                    }
                }
            }
            let ctx = CIContext(options: nil)
            if let outCG = ctx.createCGImage(composited, from: extent) {
                return NSImage(cgImage: outCG, size: image.size)
            }
        }

        let out = NSImage(size: image.size)
        out.lockFocus()
        let w = image.size.width
        let h = image.size.height
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))

        NSColor.black.setFill()
        for r in rectangles {
            let rect = NSRect(
                x: CGFloat(r.x) * w,
                y: (1.0 - CGFloat(r.y) - CGFloat(r.height)) * h,
                width: CGFloat(r.width) * w,
                height: CGFloat(r.height) * h
            )
            rect.fill()
        }
        out.unlockFocus()
        return out
    }

    private func createCollage(urls: [URL], options: CollageOptions) throws -> URL {
        guard let first = urls.first else { throw ConversionError.sourceCannotBeRead }
        let outURL = UniqueOutputURL.make(in: first.deletingLastPathComponent(), baseName: "Collage", ext: "png")
        let images = urls.compactMap { NSImage(contentsOf: $0) }
        guard !images.isEmpty else { throw ConversionError.sourceCannotBeRead }

        let cols = max(options.columns, 1)
        let rows = Int(ceil(Double(images.count) / Double(cols)))
        let canvasW = CGFloat(options.width)
        let cellW = (canvasW - CGFloat(options.padding * 2) - CGFloat(cols - 1) * CGFloat(options.spacing)) / CGFloat(cols)
        let cellH = cellW / CGFloat(max(options.aspectRatio, 0.5))
        let canvasH = CGFloat(options.padding * 2) + CGFloat(rows) * cellH + CGFloat(max(rows - 1, 0)) * CGFloat(options.spacing)

        let out = NSImage(size: NSSize(width: canvasW, height: canvasH))
        out.lockFocus()
        switch options.background {
        case .white:
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: canvasW, height: canvasH).fill()
        case .black:
            NSColor.black.setFill()
            NSRect(x: 0, y: 0, width: canvasW, height: canvasH).fill()
        case .transparent:
            break
        }

        for (idx, img) in images.enumerated() {
            let r = idx / cols
            let c = idx % cols
            let x = CGFloat(options.padding) + CGFloat(c) * (cellW + CGFloat(options.spacing))
            let y = canvasH - CGFloat(options.padding) - CGFloat(r + 1) * cellH - CGFloat(r) * CGFloat(options.spacing)
            let cellRect = NSRect(x: x, y: y, width: cellW, height: cellH)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: cellRect, xRadius: CGFloat(options.cornerRadius), yRadius: CGFloat(options.cornerRadius)).addClip()
            img.draw(in: cellRect)
            NSGraphicsContext.restoreGraphicsState()
        }
        out.unlockFocus()
        try Self.saveNSImage(out, to: outURL)
        return outURL
    }

    // MARK: - PDF & Video Batch Tools

    private func mergePDFs(urls: [URL]) throws -> URL {
        guard let first = urls.first else { throw ConversionError.sourceCannotBeRead }
        let outURL = UniqueOutputURL.make(in: first.deletingLastPathComponent(), baseName: "\(first.deletingPathExtension().lastPathComponent) Merged", ext: "pdf")
        let combined = PDFDocument()
        var insertIdx = 0
        for url in urls {
            if let doc = PDFDocument(url: url) {
                for i in 0..<doc.pageCount {
                    if let page = doc.page(at: i) {
                        combined.insert(page, at: insertIdx)
                        insertIdx += 1
                    }
                }
            }
        }
        guard combined.write(to: outURL) else {
            throw ConversionError.encodingFailed("PDFKit could not write the combined PDF.")
        }
        return outURL
    }

    private func createPDFFromImages(urls: [URL]) throws -> URL {
        guard let first = urls.first else { throw ConversionError.sourceCannotBeRead }
        let outURL = UniqueOutputURL.make(in: first.deletingLastPathComponent(), baseName: "\(first.deletingPathExtension().lastPathComponent) Document", ext: "pdf")
        let pdf = PDFDocument()
        for (idx, url) in urls.enumerated() {
            if let img = NSImage(contentsOf: url), let page = PDFPage(image: img) {
                pdf.insert(page, at: idx)
            }
        }
        guard pdf.write(to: outURL) else {
            throw ConversionError.encodingFailed("Could not create the PDF.")
        }
        return outURL
    }

    private func organizePDF(srcURL: URL, outURL: URL, options: FileToolOptions) throws {
        guard let srcDoc = PDFDocument(url: srcURL) else {
            throw ConversionError.encodingFailed("This PDF cannot be read or is password-protected.")
        }
        let outDoc = PDFDocument()
        let order = options.pdfPageOrder.isEmpty ? Array(0..<srcDoc.pageCount) : options.pdfPageOrder
        for (newIdx, origIdx) in order.enumerated() {
            if let page = srcDoc.page(at: origIdx)?.copy() as? PDFPage {
                if let rot = options.pdfPageRotations[origIdx] {
                    page.rotation = rot
                }
                outDoc.insert(page, at: newIdx)
            }
        }
        guard outDoc.write(to: outURL) else {
            throw ConversionError.encodingFailed("PDFKit could not write the organized PDF.")
        }
    }

    private func splitPDF(srcURL: URL) throws -> [URL] {
        guard let doc = PDFDocument(url: srcURL) else {
            throw ConversionError.encodingFailed("This PDF cannot be read or is password-protected.")
        }
        let dir = srcURL.deletingLastPathComponent()
        let base = srcURL.deletingPathExtension().lastPathComponent
        var outs: [URL] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i)?.copy() as? PDFPage {
                let single = PDFDocument()
                single.insert(page, at: 0)
                let outURL = UniqueOutputURL.make(in: dir, baseName: "\(base) - Page \(i + 1)", ext: "pdf")
                if single.write(to: outURL) {
                    outs.append(outURL)
                }
            }
        }
        return outs
    }

    private func joinVideos(urls: [URL]) throws -> URL {
        guard urls.count >= 2, let first = urls.first else {
            throw ConversionError.invalidFileToolOptions("Select at least two videos to join.")
        }
        let outURL = UniqueOutputURL.make(in: first.deletingLastPathComponent(), baseName: "\(first.deletingPathExtension().lastPathComponent) Joined", ext: "mp4")
        let listFile = FileManager.default.temporaryDirectory.appendingPathComponent("flowconverter-join-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: listFile) }
        let listContent = urls.map { "file '\($0.path.replacingOccurrences(of: "'", with: "'\\''"))'" }.joined(separator: "\n")
        try listContent.write(to: listFile, atomically: true, encoding: .utf8)

        try ProcessRunner.run(executable: BundledResources.ffmpegPath, arguments: [
            "-y", "-f", "concat", "-safe", "0", "-i", listFile.path, "-c", "copy", outURL.path
        ])
        return outURL
    }

    public static func saveNSImage(_ image: NSImage, to url: URL) throws {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw ConversionError.encodingFailed("Could not create the output image.")
        }
        let ext = url.pathExtension.lowercased()
        if ext == "heic", let cg = rep.cgImage,
           let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dst, cg, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
            if CGImageDestinationFinalize(dst) { return }
        }
        if ext == "webp" {
            let tempPNG = FileManager.default.temporaryDirectory.appendingPathComponent("flowconverter-webp-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: tempPNG) }
            if let pngData = rep.representation(using: .png, properties: [:]) {
                try pngData.write(to: tempPNG)
                try ProcessRunner.run(executable: BundledResources.cwebpPath, arguments: ["-q", "88", tempPNG.path, "-o", url.path])
                return
            }
        }
        let type: NSBitmapImageRep.FileType = {
            switch ext {
            case "jpg", "jpeg": return .jpeg
            case "bmp": return .bmp
            case "tif", "tiff": return .tiff
            case "gif": return .gif
            default: return .png
            }
        }()
        let props: [NSBitmapImageRep.PropertyKey: Any] = (type == .jpeg) ? [.compressionFactor: 0.9] : [:]
        guard let data = rep.representation(using: type, properties: props) else {
            throw ConversionError.encodingFailed("Could not save the output image.")
        }
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - 3MF Inspector & Cross-Printer Converter Engine (Cordeiro Flow Style)

public enum ThreeMFConverterEngine {

    public static func inspect(url: URL) -> ThreeMFProjectInfo {
        var info = ThreeMFProjectInfo()
        info.fileName = url.lastPathComponent

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("flowconverter-3mf-inspect-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try ProcessRunner.run(executable: "/usr/bin/unzip", arguments: ["-q", "-o", url.path, "-d", tempDir.path])
        } catch {
            return info
        }

        // 1. Parse Metadata/project_settings.config (JSON)
        let projectSettingsURL = tempDir.appendingPathComponent("Metadata/project_settings.config")
        var filamentTypes: [String] = []
        var filamentColors: [String] = []

        if let data = try? Data(contentsOf: projectSettingsURL),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {

            if let pm = Self.stringValue(json["printer_model"]), !pm.isEmpty {
                info.currentPrinterModel = pm
            } else if let ps = Self.stringValue(json["printer_settings_id"]), !ps.isEmpty {
                info.currentPrinterModel = ps
            }
            if let ps = Self.stringValue(json["printer_settings_id"]) {
                info.printerSettingsID = ps
            }
            if let nozzle = Self.firstStringValue(json["nozzle_diameter"]) ?? Self.stringValue(json["printer_variant"]), !nozzle.isEmpty {
                info.nozzleDiameter = nozzle
            }
            if let lh = Self.firstStringValue(json["layer_height"]), !lh.isEmpty {
                info.layerHeight = lh
            }
            if let infill = Self.firstStringValue(json["sparse_infill_density"]), !infill.isEmpty {
                info.infillDensity = infill.hasSuffix("%") ? infill : "\(infill)%"
            }
            if let walls = Self.firstStringValue(json["wall_loops"]), !walls.isEmpty {
                info.wallLoops = walls
            }
            if let sup = Self.firstStringValue(json["enable_support"]) {
                info.supportEnabled = (sup == "1" || sup.lowercased() == "true")
            }
            if let heightStr = Self.firstStringValue(json["printable_height"]), let hDouble = Double(heightStr), Int(hDouble) > 0 {
                info.bedHeightMM = Int(hDouble)
            }
            if let area = json["printable_area"] as? [String], !area.isEmpty {
                let (w, d) = Self.parsePrintableArea(area)
                if w > 0 && d > 0 {
                    info.bedWidthMM = w
                    info.bedDepthMM = d
                }
            }

            filamentTypes = Self.stringArray(json["filament_type"])
            filamentColors = Self.stringArray(json["filament_colour"])
        }

        // 2. Parse Metadata/slice_info.config (XML)
        let sliceInfoURL = tempDir.appendingPathComponent("Metadata/slice_info.config")
        var sliceFilaments: [ThreeMFFilamentSlot] = []
        if let xmlData = try? Data(contentsOf: sliceInfoURL),
           let xmlDoc = try? XMLDocument(data: xmlData, options: []) {
            if let plates = try? xmlDoc.nodes(forXPath: "//plate"), !plates.isEmpty {
                info.plateCount = plates.count
            }
            if info.currentPrinterModel == "Não identificada",
               let pmNode = (try? xmlDoc.nodes(forXPath: "//metadata[@key='printer_model_id']/@value"))?.first,
               let val = pmNode.stringValue, !val.isEmpty {
                info.currentPrinterModel = val
            }
            if let predNodes = try? xmlDoc.nodes(forXPath: "//metadata[@key='prediction']/@value") {
                let totalSec = predNodes.compactMap { Double($0.stringValue ?? "") }.reduce(0, +)
                info.estimatedTimeSeconds = Int(round(totalSec))
            }
            if let weightNodes = try? xmlDoc.nodes(forXPath: "//metadata[@key='weight']/@value") {
                let totalW = weightNodes.compactMap { Double($0.stringValue ?? "") }.reduce(0, +)
                info.totalWeightGrams = totalW
            }
            if let filNodes = try? xmlDoc.nodes(forXPath: "//filament") {
                for (idx, node) in filNodes.enumerated() {
                    guard let el = node as? XMLElement else { continue }
                    let id = Int(el.attribute(forName: "id")?.stringValue ?? "") ?? (idx + 1)
                    let type = el.attribute(forName: "type")?.stringValue ?? (idx < filamentTypes.count ? filamentTypes[idx] : "PLA")
                    let color = Self.normalizeHexColor(el.attribute(forName: "color")?.stringValue ?? (idx < filamentColors.count ? filamentColors[idx] : "#00E5FF"))
                    let usedG = Double(el.attribute(forName: "used_g")?.stringValue ?? "")
                    let usedM = Double(el.attribute(forName: "used_m")?.stringValue ?? "")
                    sliceFilaments.append(ThreeMFFilamentSlot(id: id, type: type, colorHex: color, usedGrams: usedG, usedMeters: usedM))
                }
            }
            if let objNodes = try? xmlDoc.nodes(forXPath: "//object/@name") {
                let names = objNodes.compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !names.isEmpty {
                    info.objectNames = Array(NSOrderedSet(array: names)) as? [String] ?? names
                    info.objectCount = info.objectNames.count
                }
            }
        }

        // Build filament slots from project_settings if slice_info didn't have used filaments
        if !sliceFilaments.isEmpty {
            info.filaments = sliceFilaments
        } else {
            let count = max(filamentTypes.count, filamentColors.count)
            if count > 0 {
                for i in 0..<count {
                    let t = i < filamentTypes.count ? filamentTypes[i] : "PLA"
                    let c = Self.normalizeHexColor(i < filamentColors.count ? filamentColors[i] : "#00E5FF")
                    info.filaments.append(ThreeMFFilamentSlot(id: i + 1, type: t, colorHex: c))
                }
            }
        }

        // 3. Parse Metadata/model_settings.config (XML)
        let modelSettingsURL = tempDir.appendingPathComponent("Metadata/model_settings.config")
        if let xmlData = try? Data(contentsOf: modelSettingsURL),
           let xmlDoc = try? XMLDocument(data: xmlData, options: []) {
            if let plates = try? xmlDoc.nodes(forXPath: "//plate"), !plates.isEmpty {
                info.plateCount = max(info.plateCount, plates.count)
            }
            if info.objectNames.isEmpty,
               let nameNodes = try? xmlDoc.nodes(forXPath: "/config/object/metadata[@key='name']/@value") {
                let names = nameNodes.compactMap { $0.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !names.isEmpty {
                    info.objectNames = names
                    info.objectCount = names.count
                }
            }
        }

        // 4. Parse 3D/3dmodel.model (XML) for Application metadata & build item counts
        let model3DURL = tempDir.appendingPathComponent("3D/3dmodel.model")
        if let xmlData = try? Data(contentsOf: model3DURL),
           let xmlDoc = try? XMLDocument(data: xmlData, options: []) {
            if let appNode = (try? xmlDoc.nodes(forXPath: "//*[local-name()='metadata'][@name='Application']"))?.first,
               let appStr = appNode.stringValue, !appStr.isEmpty {
                info.slicerApplication = appStr
            }
            if let items = try? xmlDoc.nodes(forXPath: "//*[local-name()='build']/*[local-name()='item']"), !items.isEmpty {
                info.objectCount = max(info.objectCount, items.count)
            }
        }

        // 5. Load Plate Thumbnail Image if present
        let thumbCandidates = [
            "Metadata/plate_1.png",
            "Metadata/plate_1_small.png",
            "Metadata/top_1.png",
            "Metadata/thumbnail.png",
            "Metadata/model_thumbnail.png"
        ]
        for rel in thumbCandidates {
            let candidateURL = tempDir.appendingPathComponent(rel)
            if let img = NSImage(contentsOf: candidateURL) {
                info.thumbnail = img
                break
            }
        }

        return info
    }

    public static func convert(srcURL: URL, targetPrinter: Printer3DModel, options: FileToolOptions) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("flowconverter-3mf-convert-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tempDir) }

        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try ProcessRunner.run(executable: "/usr/bin/unzip", arguments: ["-q", "-o", srcURL.path, "-d", tempDir.path])

        let metadataDir = tempDir.appendingPathComponent("Metadata")
        if !fm.fileExists(atPath: metadataDir.path) {
            try fm.createDirectory(at: metadataDir, withIntermediateDirectories: true)
        }

        // 1. Read & Update Metadata/project_settings.config
        let projectSettingsURL = metadataDir.appendingPathComponent("project_settings.config")
        var settingsDict: [String: Any] = [:]
        var oldBedW = 256
        var oldBedD = 256

        if let existingData = try? Data(contentsOf: projectSettingsURL),
           let parsed = (try? JSONSerialization.jsonObject(with: existingData)) as? [String: Any] {
            settingsDict = parsed
            if let area = parsed["printable_area"] as? [String], !area.isEmpty {
                let (w, d) = Self.parsePrintableArea(area)
                if w > 0 && d > 0 {
                    oldBedW = w
                    oldBedD = d
                }
            }
        }

        let nozzleStr = String(format: "%.1f", targetPrinter.nozzleDiameterMM)
        let origTypes = Self.stringArray(settingsDict["filament_type"])
        let origColors = Self.stringArray(settingsDict["filament_colour"])
        let filamentCount = options.preserve3MFFilaments ? max(origTypes.count, origColors.count, 1) : 1

        var resolvedTypes: [String] = []
        var resolvedColors: [String] = []
        if options.preserve3MFFilaments {
            for i in 0..<filamentCount {
                let t = (i < origTypes.count && !origTypes[i].isEmpty) ? origTypes[i] : (origTypes.first ?? "PLA")
                let c = (i < origColors.count && !origColors[i].isEmpty) ? Self.normalizeHexColor(origColors[i]) : Self.normalizeHexColor(origColors.first ?? "#00E5FF")
                resolvedTypes.append(t)
                resolvedColors.append(c)
            }
        } else {
            resolvedTypes = ["PLA"]
            resolvedColors = ["#00E5FF"]
        }

        let origSettingsDict = settingsDict
        let origDiffs = Self.stringArray(origSettingsDict["different_settings_to_system"])
        let origModifiedProcessKeys: [String] = (origDiffs.first ?? "")
            .split(separator: ";")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var origModifiedFilamentKeysPerSlot: [[String]] = []
        if origDiffs.count > 2 {
            for i in 2..<origDiffs.count {
                let fKeys = origDiffs[i]
                    .split(separator: ";")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                origModifiedFilamentKeysPerSlot.append(fKeys)
            }
        }

        // Intentional print geometry, speed, support, adhesion & multi-color settings from original project
        let preservedScalarIntentKeys: [String] = [
            "layer_height", "initial_layer_print_height",
            "wall_loops", "top_shell_layers", "bottom_shell_layers",
            "top_shell_thickness", "bottom_shell_thickness",
            "sparse_infill_density", "sparse_infill_pattern",
            "top_surface_pattern", "bottom_surface_pattern", "internal_solid_infill_pattern",
            "inner_wall_speed", "outer_wall_speed", "sparse_infill_speed", "internal_solid_infill_speed",
            "top_surface_speed", "initial_layer_speed", "initial_layer_infill_speed",
            "bridge_speed", "gap_infill_speed", "support_speed", "support_interface_speed",
            "small_perimeter_speed", "overhang_1_4_speed", "overhang_2_4_speed", "overhang_3_4_speed", "overhang_4_4_speed",
            "outer_wall_line_width", "inner_wall_line_width", "sparse_infill_line_width",
            "initial_layer_line_width", "top_surface_line_width", "internal_solid_infill_line_width",
            "enable_support", "support_type", "support_style",
            "support_on_build_plate_only", "support_threshold_angle", "support_remove_small_overhang",
            "support_interface_top_layers", "support_interface_bottom_layers",
            "support_top_z_distance", "support_bottom_z_distance",
            "brim_type", "brim_width", "brim_object_gap", "skirt_loops",
            "seam_position", "seam_gap", "detect_thin_wall", "wall_generator", "wall_sequence", "spiral_mode",
            "elefant_foot_compensation", "xy_contour_compensation", "xy_hole_compensation",
            "fuzzy_skin", "fuzzy_skin_thickness", "fuzzy_skin_point_distance",
            "ironing_type", "ironing_flow", "ironing_speed", "ironing_spacing",
            "enable_prime_tower", "prime_tower_width", "prime_tower_brim_width",
            "wipe_tower_no_sparse_layers", "flush_into_infill", "flush_into_objects", "flush_into_support",
            "only_one_wall_top", "only_one_wall_first_layer", "avoid_crossing_wall",
            "ensure_vertical_shell_thickness"
        ]

        let allCandidateProcessKeys = Set(origModifiedProcessKeys).union(preservedScalarIntentKeys)
        let isAnycubicTarget = targetPrinter.brand.lowercased().contains("anycubic") || targetPrinter.name.lowercased().contains("anycubic")

        // Resolve official machine + process + filament profile for the target printer
        var targetProcessDefaults: [String: Any] = [:]
        var targetFilamentKeys: Set<String> = []
        if let officialResult = Self.buildOfficialPrinterSettings(
            for: targetPrinter,
            nozzleStr: nozzleStr,
            filamentTypes: resolvedTypes,
            filamentColors: resolvedColors
        ) {
            settingsDict = officialResult.combined
            targetProcessDefaults = officialResult.processProfile
            targetFilamentKeys = officialResult.filamentKeys
        }

        // Apply preserved project print intent & author-modified settings if preset is keepOriginal
        var modifiedProcessKeySet = Set<String>()
        let excludedProcessMetaKeys: Set<String> = [
            "name", "from", "type", "inherits", "setting_id", "instantiation", "version",
            "compatible_printers", "compatible_printers_condition", "print_settings_id",
            "default_print_profile", "filename_format"
        ]

        if options.threeMFPreset == .keepOriginal {
            for k in allCandidateProcessKeys {
                guard !excludedProcessMetaKeys.contains(k) else { continue }
                // Only apply keys supported by the target slicer's process schema (prevents unknown key warnings)
                if !targetProcessDefaults.isEmpty && targetProcessDefaults[k] == nil {
                    continue
                }
                guard let rawOrigVal = origSettingsDict[k] else { continue }
                let wasExplicitlyModifiedInOrig = origModifiedProcessKeys.contains(k)

                if let targetDefault = targetProcessDefaults[k], targetDefault is [Any] {
                    let arr = Self.stringArray(rawOrigVal)
                    if !arr.isEmpty {
                        settingsDict[k] = arr
                        if wasExplicitlyModifiedInOrig || arr != Self.stringArray(targetDefault) {
                            modifiedProcessKeySet.insert(k)
                        }
                    }
                } else if let strVal = Self.firstStringValue(rawOrigVal), !strVal.isEmpty {
                    let sanitized = Self.sanitizeScalarValue(key: k, rawValue: strVal, isAnycubic: isAnycubicTarget)
                    let defaultStr = Self.firstStringValue(targetProcessDefaults[k]) ?? ""
                    // Avoid overriding target printer's stock speeds/accelerations unless explicitly modified in the source 3MF
                    let isSpeedOrAccel = k.hasSuffix("_speed") || k.hasSuffix("_acceleration") || k.hasSuffix("_jerk")
                    if isSpeedOrAccel && !wasExplicitlyModifiedInOrig {
                        continue
                    }
                    settingsDict[k] = sanitized
                    if wasExplicitlyModifiedInOrig || (!defaultStr.isEmpty && sanitized != defaultStr) {
                        modifiedProcessKeySet.insert(k)
                    }
                }
            }
        }

        // Preserve multi-color purge arrays & per-slot filament overrides
        let preservedArrayKeys: [String] = [
            "flush_volumes_matrix", "flush_volumes_vector", "wiping_volumes_extruders"
        ]
        if options.preserve3MFFilaments {
            for k in preservedArrayKeys {
                let arr = Self.stringArray(origSettingsDict[k])
                if !arr.isEmpty {
                    settingsDict[k] = arr
                }
            }
        }

        var modifiedFilamentDiffs: [String] = Array(repeating: "", count: filamentCount)
        if options.preserve3MFFilaments && !origModifiedFilamentKeysPerSlot.isEmpty {
            let safeFilamentOverrideKeys: Set<String> = [
                "nozzle_temperature", "nozzle_temperature_initial_layer",
                "hot_plate_temp", "hot_plate_temp_initial_layer",
                "textured_plate_temp", "textured_plate_temp_initial_layer",
                "cool_plate_temp", "cool_plate_temp_initial_layer",
                "filament_flow_ratio", "filament_max_volumetric_speed",
                "enable_pressure_advance", "pressure_advance",
                "fan_max_speed", "fan_min_speed", "overhang_fan_speed",
                "slow_down_for_layer_cooling", "slow_down_layer_time", "slow_down_min_speed"
            ]
            for slotIdx in 0..<min(filamentCount, origModifiedFilamentKeysPerSlot.count) {
                var slotAppliedKeys: [String] = []
                for fk in origModifiedFilamentKeysPerSlot[slotIdx] {
                    guard safeFilamentOverrideKeys.contains(fk),
                          targetFilamentKeys.isEmpty || targetFilamentKeys.contains(fk) else { continue }
                    let origArr = Self.stringArray(origSettingsDict[fk])
                    guard slotIdx < origArr.count else { continue }
                    var currentArr = Self.stringArray(settingsDict[fk])
                    if currentArr.count == filamentCount {
                        currentArr[slotIdx] = origArr[slotIdx]
                        settingsDict[fk] = currentArr
                        slotAppliedKeys.append(fk)
                    }
                }
                modifiedFilamentDiffs[slotIdx] = slotAppliedKeys.sorted().joined(separator: ";")
            }
        }

        // Ensure core target printer geometry & identifiers are set
        let cleanModelName = Self.canonicalPrinterModelName(for: targetPrinter)
        let resolvedMachineID = (settingsDict["printer_settings_id"] as? String).flatMap({ $0.isEmpty ? nil : $0 }) ?? targetPrinter.printerSettingsID
        settingsDict["printer_model"] = cleanModelName
        settingsDict["printer_settings_id"] = resolvedMachineID
        settingsDict["printer_variant"] = nozzleStr
        settingsDict["nozzle_diameter"] = [nozzleStr]
        settingsDict["printable_area"] = [
            "0x0",
            "\(targetPrinter.bedWidthMM)x0",
            "\(targetPrinter.bedWidthMM)x\(targetPrinter.bedDepthMM)",
            "0x\(targetPrinter.bedDepthMM)"
        ]
        settingsDict["printable_height"] = "\(targetPrinter.bedHeightMM)"
        settingsDict["bed_exclude_area"] = [String]()
        settingsDict["gcode_flavor"] = targetPrinter.gcodeFlavor
        settingsDict["compatible_printers"] = [resolvedMachineID]
        settingsDict["compatible_printers_condition"] = ""
        settingsDict["inherits"] = ""
        settingsDict["from"] = "project"
        settingsDict["name"] = "project_settings"
        settingsDict["filament_type"] = resolvedTypes
        settingsDict["filament_colour"] = resolvedColors

        // Apply optional Cordeiro-style Optimization Preset
        switch options.threeMFPreset {
        case .keepOriginal:
            break
        case .standardQuality:
            settingsDict["layer_height"] = "0.2"
            settingsDict["initial_layer_print_height"] = "0.2"
            settingsDict["wall_loops"] = "2"
            settingsDict["sparse_infill_density"] = "15%"
            settingsDict["sparse_infill_pattern"] = "grid"
            modifiedProcessKeySet.formUnion(["layer_height", "initial_layer_print_height", "wall_loops", "sparse_infill_density", "sparse_infill_pattern"])
        case .detailedFigure:
            settingsDict["layer_height"] = "0.12"
            settingsDict["initial_layer_print_height"] = "0.2"
            settingsDict["wall_loops"] = "3"
            settingsDict["sparse_infill_density"] = "18%"
            settingsDict["sparse_infill_pattern"] = "gyroid"
            settingsDict["enable_support"] = "1"
            settingsDict["support_type"] = "tree(auto)"
            modifiedProcessKeySet.formUnion(["layer_height", "initial_layer_print_height", "wall_loops", "sparse_infill_density", "sparse_infill_pattern", "enable_support", "support_type"])
        case .fastEconomic:
            settingsDict["layer_height"] = "0.24"
            settingsDict["initial_layer_print_height"] = "0.24"
            settingsDict["wall_loops"] = "2"
            settingsDict["sparse_infill_density"] = "10%"
            settingsDict["sparse_infill_pattern"] = "lightning"
            modifiedProcessKeySet.formUnion(["layer_height", "initial_layer_print_height", "wall_loops", "sparse_infill_density", "sparse_infill_pattern"])
        case .strongMechanical:
            settingsDict["layer_height"] = "0.2"
            settingsDict["initial_layer_print_height"] = "0.2"
            settingsDict["wall_loops"] = "4"
            settingsDict["top_shell_layers"] = "5"
            settingsDict["bottom_shell_layers"] = "5"
            settingsDict["sparse_infill_density"] = "35%"
            settingsDict["sparse_infill_pattern"] = "gyroid"
            modifiedProcessKeySet.formUnion(["layer_height", "initial_layer_print_height", "wall_loops", "top_shell_layers", "bottom_shell_layers", "sparse_infill_density", "sparse_infill_pattern"])
        }

        // Sanitize all scalar/array & enum differences across Bambu Studio / AnycubicSlicerNext / OrcaSlicer
        Self.sanitizeCrossSlicerSettings(&settingsDict, targetPrinter: targetPrinter, filamentCount: filamentCount)

        // Populate different_settings_to_system so AnycubicSlicerNext / OrcaSlicer / Bambu Studio preserve custom overrides
        var diffToSystem: [String] = [
            modifiedProcessKeySet.sorted().joined(separator: ";"),
            "" // Machine profile uses clean target system profile
        ]
        for slotIdx in 0..<filamentCount {
            let fDiff = slotIdx < modifiedFilamentDiffs.count ? modifiedFilamentDiffs[slotIdx] : ""
            diffToSystem.append(fDiff)
        }
        settingsDict["different_settings_to_system"] = diffToSystem

        let updatedJSONData = try JSONSerialization.data(withJSONObject: settingsDict, options: [.prettyPrinted, .sortedKeys])
        try updatedJSONData.write(to: projectSettingsURL, options: .atomic)

        // 2. Update Metadata/slice_info.config & Metadata/model_settings.config XML metadata
        let sliceInfoURL = metadataDir.appendingPathComponent("slice_info.config")
        if fm.fileExists(atPath: sliceInfoURL.path),
           let xmlData = try? Data(contentsOf: sliceInfoURL),
           let xmlDoc = try? XMLDocument(data: xmlData, options: []) {
            if let pmNodes = try? xmlDoc.nodes(forXPath: "//metadata[@key='printer_model_id']") {
                for node in pmNodes {
                    (node as? XMLElement)?.attribute(forName: "value")?.stringValue = cleanModelName
                }
            }
            if let nzNodes = try? xmlDoc.nodes(forXPath: "//metadata[@key='nozzle_diameters']") {
                for node in nzNodes {
                    (node as? XMLElement)?.attribute(forName: "value")?.stringValue = nozzleStr
                }
            }
            Self.sanitizeXMLMetadataNodes(in: xmlDoc)
            let outXML = xmlDoc.xmlData(options: [.nodePrettyPrint])
            try? outXML.write(to: sliceInfoURL, options: .atomic)
        }

        let modelSettingsURL = metadataDir.appendingPathComponent("model_settings.config")
        if fm.fileExists(atPath: modelSettingsURL.path),
           let xmlData = try? Data(contentsOf: modelSettingsURL),
           let xmlDoc = try? XMLDocument(data: xmlData, options: []) {
            Self.sanitizeXMLMetadataNodes(in: xmlDoc)
            let outXML = xmlDoc.xmlData(options: [.nodePrettyPrint])
            try? outXML.write(to: modelSettingsURL, options: .atomic)
        }

        // 3. Auto-Recenter Build Items on Target Bed if Dimensions Differ
        if options.recenter3MFOnBed && (oldBedW != targetPrinter.bedWidthMM || oldBedD != targetPrinter.bedDepthMM) {
            let dx = Double(targetPrinter.bedWidthMM - oldBedW) * 0.5
            let dy = Double(targetPrinter.bedDepthMM - oldBedD) * 0.5
            let model3DURL = tempDir.appendingPathComponent("3D/3dmodel.model")
            if let xmlData = try? Data(contentsOf: model3DURL),
               let xmlDoc = try? XMLDocument(data: xmlData, options: []) {
                if let itemNodes = try? xmlDoc.nodes(forXPath: "//*[local-name()='build']/*[local-name()='item']") {
                    for node in itemNodes {
                        guard let el = node as? XMLElement,
                              let tfAttr = el.attribute(forName: "transform"),
                              let tfStr = tfAttr.stringValue else { continue }
                        let parts = tfStr.split(separator: " ").compactMap { Double($0) }
                        if parts.count == 12 {
                            var updatedParts = parts
                            let margin = 12.0
                            let maxW = max(margin, Double(targetPrinter.bedWidthMM) - margin)
                            let maxD = max(margin, Double(targetPrinter.bedDepthMM) - margin)
                            updatedParts[9] = min(max(parts[9] + dx, margin), maxW)
                            updatedParts[10] = min(max(parts[10] + dy, margin), maxD)
                            tfAttr.stringValue = updatedParts.map { String(format: "%.4f", $0) }.joined(separator: " ")
                        }
                    }
                    let outXML = xmlDoc.xmlData(options: [])
                    try? outXML.write(to: model3DURL, options: .atomic)
                }
            }
        }

        // 4. Repack .3mf ZIP Archive
        let dir = srcURL.deletingLastPathComponent()
        let base = srcURL.deletingPathExtension().lastPathComponent
        let outURL = UniqueOutputURL.make(
            in: dir,
            baseName: "\(base)_\(targetPrinter.sanitizedFileSuffix)",
            ext: "3mf"
        )
        if fm.fileExists(atPath: outURL.path) {
            try? fm.removeItem(at: outURL)
        }

        let topLevelEntries = try fm.contentsOfDirectory(atPath: tempDir.path)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        proc.currentDirectoryURL = tempDir
        proc.arguments = ["-r", "-q", outURL.path] + topLevelEntries
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0, fm.fileExists(atPath: outURL.path) else {
            throw ConversionError.processFailed("Failed to repackage the converted .3mf file.")
        }

        return outURL
    }

    // MARK: - Helpers

    private static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let n = any as? NSNumber { return n.stringValue }
        return nil
    }

    private static func firstStringValue(_ any: Any?) -> String? {
        if let s = stringValue(any) { return s }
        if let arr = any as? [Any], let first = arr.first {
            return stringValue(first)
        }
        return nil
    }

    private static func stringArray(_ any: Any?) -> [String] {
        if let arr = any as? [Any] {
            return arr.compactMap { stringValue($0) }
        }
        if let s = stringValue(any), !s.isEmpty {
            return [s]
        }
        return []
    }

    private static func parsePrintableArea(_ area: [String]) -> (Int, Int) {
        var maxX = 0
        var maxY = 0
        for pt in area {
            let comps = pt.lowercased().split(separator: "x")
            if comps.count == 2,
               let xDouble = Double(comps[0]),
               let yDouble = Double(comps[1]) {
                maxX = max(maxX, Int(xDouble))
                maxY = max(maxY, Int(yDouble))
            }
        }
        return (maxX, maxY)
    }

    public static func normalizeHexColor(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        if cleaned.count >= 6 {
            return "#" + String(cleaned.prefix(6)).uppercased()
        }
        return "#00E5FF"
    }

    // MARK: - Official Slicer Profile Resolver & Cross-Slicer Sanitizer

    private static func canonicalPrinterModelName(for printer: Printer3DModel) -> String {
        let trimmed = printer.name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "Anycubic Kobra 3 Combo": return "Anycubic Kobra 3"
        case "Anycubic Kobra S1 Combo": return "Anycubic Kobra S1"
        case "Anycubic Kobra": return "Anycubic Kobra 1"
        case "Anycubic Kobra Plus": return "Anycubic Kobra 1 Plus"
        case "Anycubic Kobra Max": return "Anycubic Kobra 1 Max"
        default: return trimmed
        }
    }

    private static func vendorIndexNames(for brand: String) -> [String] {
        switch brand.lowercased() {
        case "anycubic": return ["Anycubic"]
        case "bambu lab", "bambulab", "bbl": return ["BBL"]
        case "creality": return ["Creality"]
        case "flashforge": return ["Flashforge"]
        case "elegoo": return ["Elegoo"]
        case "prusa", "prusa research": return ["Prusa"]
        case "qidi tech", "qidi": return ["Qidi"]
        case "sovol": return ["Sovol"]
        case "artillery": return ["Artillery"]
        case "flsun": return ["FLSun"]
        case "voron": return ["Voron"]
        case "two trees", "twotrees": return ["TwoTrees"]
        default: return [brand, "Anycubic", "BBL"]
        }
    }

    private static func profileBaseDirectories() -> [URL] {
        var dirs: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("profiles") {
            dirs.append(bundled)
        }
        dirs.append(URL(fileURLWithPath: "/Applications/AnycubicSlicerNext.app/Contents/Resources/profiles"))
        dirs.append(URL(fileURLWithPath: "/Applications/OrcaSlicer.app/Contents/Resources/profiles"))
        dirs.append(URL(fileURLWithPath: "/Applications/BambuStudio.app/Contents/Resources/profiles"))
        return dirs
    }

    private static func loadInheritedProfileChain(
        baseDir: URL,
        vendor: String,
        indexDict: [String: Any],
        listKey: String,
        targetName: String
    ) -> [String: Any]? {
        guard let list = indexDict[listKey] as? [[String: Any]] else { return nil }
        var subPathMap: [String: String] = [:]
        for item in list {
            if let n = item["name"] as? String, let sp = item["sub_path"] as? String {
                subPathMap[n] = sp
            }
        }
        guard subPathMap[targetName] != nil else { return nil }

        var chain: [[String: Any]] = []
        var curr = targetName
        var visited = Set<String>()
        while !curr.isEmpty, let sp = subPathMap[curr], !visited.contains(curr) {
            visited.insert(curr)
            let fileURL = baseDir.appendingPathComponent(vendor).appendingPathComponent(sp)
            guard let data = try? Data(contentsOf: fileURL),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                break
            }
            chain.append(json)
            curr = (json["inherits"] as? String) ?? ""
        }
        guard !chain.isEmpty else { return nil }

        var merged: [String: Any] = [:]
        for dict in chain.reversed() {
            for (k, v) in dict {
                merged[k] = v
            }
        }
        return merged
    }

    private static func buildOfficialPrinterSettings(
        for targetPrinter: Printer3DModel,
        nozzleStr: String,
        filamentTypes: [String],
        filamentColors: [String]
    ) -> (combined: [String: Any], processProfile: [String: Any], filamentKeys: Set<String>)? {
        let cleanModel = canonicalPrinterModelName(for: targetPrinter)
        let candidateMachineNames = [
            "\(cleanModel) \(nozzleStr) nozzle",
            targetPrinter.printerSettingsID,
            "\(cleanModel) 0.4 nozzle",
            cleanModel
        ]
        let vendors = vendorIndexNames(for: targetPrinter.brand)
        let baseDirs = profileBaseDirectories()

        var foundBaseDir: URL?
        var foundVendor: String?
        var foundIndex: [String: Any]?
        var foundMachineName: String?
        var machineProfile: [String: Any]?

        outerSearch: for dir in baseDirs {
            for vendor in vendors {
                let indexURL = dir.appendingPathComponent("\(vendor).json")
                guard let idxData = try? Data(contentsOf: indexURL),
                      let idxJSON = (try? JSONSerialization.jsonObject(with: idxData)) as? [String: Any] else {
                    continue
                }
                for cand in candidateMachineNames {
                    if let m = loadInheritedProfileChain(baseDir: dir, vendor: vendor, indexDict: idxJSON, listKey: "machine_list", targetName: cand) {
                        foundBaseDir = dir
                        foundVendor = vendor
                        foundIndex = idxJSON
                        foundMachineName = cand
                        machineProfile = m
                        break outerSearch
                    }
                }
            }
        }

        // Fallback to Anycubic Kobra X 0.4 nozzle as universal schema template if custom printer
        if machineProfile == nil {
            for dir in baseDirs {
                let indexURL = dir.appendingPathComponent("Anycubic.json")
                if let idxData = try? Data(contentsOf: indexURL),
                   let idxJSON = (try? JSONSerialization.jsonObject(with: idxData)) as? [String: Any],
                   let m = loadInheritedProfileChain(baseDir: dir, vendor: "Anycubic", indexDict: idxJSON, listKey: "machine_list", targetName: "Anycubic Kobra X 0.4 nozzle") {
                    foundBaseDir = dir
                    foundVendor = "Anycubic"
                    foundIndex = idxJSON
                    foundMachineName = targetPrinter.printerSettingsID
                    machineProfile = m
                    break
                }
            }
        }

        guard let baseDir = foundBaseDir,
              let vendor = foundVendor,
              let idxJSON = foundIndex,
              let resolvedMachine = machineProfile else {
            return nil
        }

        let machineName = foundMachineName ?? targetPrinter.printerSettingsID
        let defaultProcessName = Self.firstStringValue(resolvedMachine["default_print_profile"]) ?? "0.20mm Standard @\(machineName)"
        var processProfile = loadInheritedProfileChain(
            baseDir: baseDir,
            vendor: vendor,
            indexDict: idxJSON,
            listKey: "process_list",
            targetName: defaultProcessName
        )
        if processProfile == nil, let pList = idxJSON["process_list"] as? [[String: Any]] {
            if let match = pList.first(where: { ($0["name"] as? String)?.contains("@\(machineName)") == true }),
               let name = match["name"] as? String {
                processProfile = loadInheritedProfileChain(baseDir: baseDir, vendor: vendor, indexDict: idxJSON, listKey: "process_list", targetName: name)
            }
        }

        let defaultFilamentNames = Self.stringArray(resolvedMachine["default_filament_profile"])
        let fallbackFilamentName = defaultFilamentNames.first ?? "\(vendor) PLA @\(machineName)"

        // Resolve per-slot filament profiles matching each slot's filament type (PLA, PETG, ABS, ASA, TPU)
        let filamentCount = max(filamentTypes.count, filamentColors.count, 1)
        var slotFilamentProfiles: [[String: Any]] = []
        var slotFilamentIDs: [String] = []
        let fList = (idxJSON["filament_list"] as? [[String: Any]]) ?? []

        for i in 0..<filamentCount {
            let fType = (i < filamentTypes.count ? filamentTypes[i] : "PLA").uppercased()
            let preferredCandidates = [
                "\(vendor) \(fType) @\(machineName)",
                "Generic \(fType) @\(machineName)",
                fallbackFilamentName
            ]
            var loadedFilament: [String: Any]? = nil
            var loadedID: String = fallbackFilamentName
            for cand in preferredCandidates {
                if let fp = loadInheritedProfileChain(baseDir: baseDir, vendor: vendor, indexDict: idxJSON, listKey: "filament_list", targetName: cand) {
                    loadedFilament = fp
                    loadedID = cand
                    break
                }
            }
            if loadedFilament == nil {
                if let match = fList.first(where: {
                    guard let n = $0["name"] as? String else { return false }
                    return n.contains("@\(machineName)") && n.uppercased().contains(fType)
                }), let mName = match["name"] as? String,
                   let fp = loadInheritedProfileChain(baseDir: baseDir, vendor: vendor, indexDict: idxJSON, listKey: "filament_list", targetName: mName) {
                    loadedFilament = fp
                    loadedID = mName
                } else if let match = fList.first(where: { ($0["name"] as? String)?.contains("@\(machineName)") == true }),
                          let mName = match["name"] as? String,
                          let fp = loadInheritedProfileChain(baseDir: baseDir, vendor: vendor, indexDict: idxJSON, listKey: "filament_list", targetName: mName) {
                    loadedFilament = fp
                    loadedID = mName
                }
            }
            if let fp = loadedFilament {
                slotFilamentProfiles.append(fp)
            }
            slotFilamentIDs.append(loadedID)
        }

        var combined: [String: Any] = [:]
        for (k, v) in resolvedMachine {
            combined[k] = v
        }
        if let proc = processProfile {
            for (k, v) in proc {
                combined[k] = v
            }
        }
        if let firstFilament = slotFilamentProfiles.first {
            for (k, v) in firstFilament {
                if v is [Any] {
                    var perSlotValues: [String] = []
                    for slotIdx in 0..<filamentCount {
                        let slotProf = slotIdx < slotFilamentProfiles.count ? slotFilamentProfiles[slotIdx] : firstFilament
                        let val = Self.firstStringValue(slotProf[k]) ?? Self.firstStringValue(v) ?? ""
                        perSlotValues.append(val)
                    }
                    combined[k] = perSlotValues
                } else {
                    combined[k] = v
                }
            }
        }

        // Clean profile-definition metadata keys
        let definitionOnlyKeys = ["type", "instantiation", "setting_id", "filament_id", "is_custom_defined"]
        for k in definitionOnlyKeys {
            combined.removeValue(forKey: k)
        }

        combined["printer_settings_id"] = machineName
        combined["print_settings_id"] = Self.firstStringValue(processProfile?["name"]) ?? defaultProcessName
        combined["default_print_profile"] = Self.firstStringValue(processProfile?["name"]) ?? defaultProcessName
        combined["filament_settings_id"] = slotFilamentIDs
        combined["default_filament_profile"] = [slotFilamentIDs.first ?? fallbackFilamentName]
        combined["filament_type"] = filamentTypes
        combined["filament_colour"] = filamentColors
        combined["default_filament_colour"] = Array(repeating: "", count: filamentCount)

        let fKeys = Set(slotFilamentProfiles.first?.keys.map { $0 } ?? [])
        return (combined: combined, processProfile: processProfile ?? [:], filamentKeys: fKeys)
    }

    private static let scalarSlicerKeys: Set<String> = [
        "enable_overhang_speed",
        "ensure_vertical_shell_thickness",
        "nozzle_type",
        "nozzle_volume",
        "nozzle_height",
        "nozzle_hrc",
        "overhang_speed_classic",
        "bridge_speed",
        "internal_bridge_speed",
        "default_acceleration",
        "gap_infill_speed",
        "initial_layer_acceleration",
        "initial_layer_infill_speed",
        "initial_layer_speed",
        " initial_layer_travel_speed",
        "inner_wall_acceleration",
        "inner_wall_speed",
        "internal_solid_infill_acceleration",
        "internal_solid_infill_speed",
        "outer_wall_acceleration",
        "outer_wall_speed",
        "overhang_1_4_speed",
        "overhang_2_4_speed",
        "overhang_3_4_speed",
        "overhang_4_4_speed",
        "overhang_totally_speed",
        "small_perimeter_speed",
        "small_perimeter_threshold",
        "sparse_infill_acceleration",
        "sparse_infill_speed",
        "support_interface_speed",
        "support_speed",
        "top_surface_acceleration",
        "top_surface_speed",
        "travel_acceleration",
        "travel_speed",
        "travel_speed_z",
        "layer_height",
        "initial_layer_print_height",
        "wall_loops",
        "top_shell_layers",
        "bottom_shell_layers",
        "top_shell_thickness",
        "bottom_shell_thickness",
        "sparse_infill_density",
        "sparse_infill_pattern",
        "top_surface_pattern",
        "bottom_surface_pattern",
        "internal_solid_infill_pattern",
        "enable_support",
        "support_type",
        "support_style",
        "support_on_build_plate_only",
        "support_threshold_angle",
        "support_remove_small_overhang",
        "brim_type",
        "brim_width",
        "skirt_loops",
        "seam_position",
        "detect_thin_wall",
        "wall_generator",
        "spiral_mode",
        "fuzzy_skin",
        "fuzzy_skin_thickness",
        "fuzzy_skin_point_distance",
        "ironing_type",
        "enable_prime_tower",
        "prime_tower_width",
        "prime_tower_brim_width",
        "wipe_tower_no_sparse_layers",
        "printer_model",
        "printer_settings_id",
        "print_settings_id",
        "default_print_profile",
        "printer_variant",
        "printable_height",
        "gcode_flavor",
        "single_extruder_multi_material",
        "auxiliary_fan"
    ]

    private static func sanitizeScalarValue(key: String, rawValue: String, isAnycubic: Bool) -> String {
        var val = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Collapse comma-separated multi-extruder values (e.g. "1,1,1,1,1" or "hardened_steel,hardened_steel,...")
        if val.contains(",") && key != "best_object_pos" {
            val = val.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? val
        }

        switch key {
        case "ensure_vertical_shell_thickness":
            switch val.lowercased() {
            case "enabled", "1", "true", "all", "ensure_all":
                return "ensure_all"
            case "moderate", "critical_only", "ensure_critical_only":
                return "ensure_critical_only"
            case "disabled", "0", "false", "none", "ensure_none":
                return "ensure_none"
            default:
                return "ensure_all"
            }
        case "enable_overhang_speed", "overhang_speed_classic", "enable_support", "support_on_build_plate_only", "detect_thin_wall", "spiral_mode", "enable_prime_tower", "wipe_tower_no_sparse_layers":
            switch val.lowercased() {
            case "1", "true", "enabled", "yes":
                return "1"
            case "0", "false", "disabled", "no":
                return "0"
            default:
                return val == "0" ? "0" : "1"
            }
        case "nozzle_type":
            let lower = val.lowercased()
            if lower.contains("hardened") { return "hardened_steel" }
            if lower.contains("stainless") { return "stainless_steel" }
            if lower.contains("brass") { return "brass" }
            return "hardened_steel"
        case "sparse_infill_pattern":
            let lower = val.lowercased()
            if lower == "zig-zag" { return "rectilinear" }
            if isAnycubic && lower == "crosshatch" { return "gyroid" }
            return lower
        default:
            return val
        }
    }

    private static func sanitizeCrossSlicerSettings(
        _ settingsDict: inout [String: Any],
        targetPrinter: Printer3DModel,
        filamentCount: Int
    ) {
        let isAnycubic = targetPrinter.brand.lowercased().contains("anycubic") || targetPrinter.name.lowercased().contains("anycubic")

        for key in Array(settingsDict.keys) {
            if scalarSlicerKeys.contains(key) {
                if let firstStr = Self.firstStringValue(settingsDict[key]) {
                    settingsDict[key] = sanitizeScalarValue(key: key, rawValue: firstStr, isAnycubic: isAnycubic)
                }
            }
        }

        // Explicitly guarantee the 3 critical keys validated by AnycubicSlicerNext
        let eoh = Self.firstStringValue(settingsDict["enable_overhang_speed"]) ?? "1"
        settingsDict["enable_overhang_speed"] = sanitizeScalarValue(key: "enable_overhang_speed", rawValue: eoh, isAnycubic: isAnycubic)

        let evst = Self.firstStringValue(settingsDict["ensure_vertical_shell_thickness"]) ?? "ensure_all"
        settingsDict["ensure_vertical_shell_thickness"] = sanitizeScalarValue(key: "ensure_vertical_shell_thickness", rawValue: evst, isAnycubic: isAnycubic)

        let nt = Self.firstStringValue(settingsDict["nozzle_type"]) ?? "hardened_steel"
        settingsDict["nozzle_type"] = sanitizeScalarValue(key: "nozzle_type", rawValue: nt, isAnycubic: isAnycubic)
    }

    private static func sanitizeXMLMetadataNodes(in xmlDoc: XMLDocument) {
        guard let metaNodes = try? xmlDoc.nodes(forXPath: "//metadata") else { return }
        for node in metaNodes {
            guard let el = node as? XMLElement,
                  let key = el.attribute(forName: "key")?.stringValue,
                  let valAttr = el.attribute(forName: "value"),
                  let rawVal = valAttr.stringValue else {
                continue
            }
            if scalarSlicerKeys.contains(key) {
                valAttr.stringValue = sanitizeScalarValue(key: key, rawValue: rawVal, isAnycubic: true)
            }
        }
    }
}
