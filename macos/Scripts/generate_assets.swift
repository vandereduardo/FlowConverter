import AppKit
import CoreGraphics
import Foundation

// 1. Generate FlowConverter AppIcon.icns (Parallel 42 Flow Pro dark radial wheel aesthetic)
func drawFlowConverterIcon(size: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }

    let s = CGFloat(size)
    let center = CGPoint(x: s * 0.5, y: s * 0.5)
    let pad = s * 0.08
    let bgRect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let cornerRadius = s * 0.21

    // Dark obsidian cockpit squircle background
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1.0),
        CGColor(red: 0.09, green: 0.13, blue: 0.22, alpha: 1.0)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: bgRect.minX, y: bgRect.maxY),
            end: CGPoint(x: bgRect.maxX, y: bgRect.minY),
            options: []
        )
    }

    // Subtle radial cyan glow in the center
    let glowColors = [
        CGColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 0.22),
        CGColor(red: 0.36, green: 0.38, blue: 0.81, alpha: 0.0)
    ] as CFArray
    if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            glow,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: s * 0.42,
            options: []
        )
    }
    ctx.restoreGState()

    // Outer subtle border
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 0.35))
    ctx.setLineWidth(max(1.5, s * 0.014))
    ctx.strokePath()
    ctx.restoreGState()

    // Draw 8 segmented radial wheel petals (Flow Pro style)
    let segmentCount = 8
    let innerR = s * 0.17
    let outerR = s * 0.36
    let gapAngle = 0.075 // radians gap between segments
    let sweep = (2.0 * CGFloat.pi / CGFloat(segmentCount)) - gapAngle

    for i in 0..<segmentCount {
        let startA = CGFloat(i) * (2.0 * CGFloat.pi / CGFloat(segmentCount)) + gapAngle * 0.5
        let endA = startA + sweep

        let path = CGMutablePath()
        path.addArc(center: center, radius: outerR, startAngle: startA, endAngle: endA, clockwise: false)
        path.addArc(center: center, radius: innerR, startAngle: endA, endAngle: startA, clockwise: true)
        path.closeSubpath()

        ctx.saveGState()
        ctx.addPath(path)

        // Highlight active segment at top-right in glowing Electric Cyan, others in sleek gradient
        if i == 1 || i == 2 {
            ctx.setFillColor(CGColor(red: 0.0, green: 0.90, blue: 1.0, alpha: i == 1 ? 0.95 : 0.75))
            ctx.fillPath()
        } else if i == 5 || i == 6 {
            ctx.setFillColor(CGColor(red: 0.42, green: 0.36, blue: 0.91, alpha: 0.72))
            ctx.fillPath()
        } else {
            ctx.setFillColor(CGColor(red: 0.16, green: 0.23, blue: 0.36, alpha: 0.85))
            ctx.fillPath()
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.38))
            ctx.setLineWidth(max(1.0, s * 0.008))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    // Center hub circle with glowing cyan ring
    let hubR = s * 0.115
    let hubRect = CGRect(x: center.x - hubR, y: center.y - hubR, width: hubR * 2, height: hubR * 2)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1.0))
    ctx.fillEllipse(in: hubRect)
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 0.95))
    ctx.setLineWidth(max(1.5, s * 0.018))
    ctx.strokeEllipse(in: hubRect)
    ctx.restoreGState()

    // Central "//" Flow slash accent inside the hub
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0))
    ctx.setLineWidth(max(1.5, s * 0.022))
    ctx.setLineCap(.round)
    let slashH = hubR * 0.48
    let slashW = hubR * 0.22
    let offset = hubR * 0.20
    ctx.move(to: CGPoint(x: center.x - offset - slashW * 0.5, y: center.y - slashH))
    ctx.addLine(to: CGPoint(x: center.x - offset + slashW * 0.5, y: center.y + slashH))
    ctx.move(to: CGPoint(x: center.x + offset - slashW * 0.5, y: center.y - slashH))
    ctx.addLine(to: CGPoint(x: center.x + offset + slashW * 0.5, y: center.y + slashH))
    ctx.strokePath()
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// 2. Generate clean UI tick/chime WAV (44.1 kHz, 16-bit mono, 55 ms soft harmonic click)
func generateHighlightWav(at url: URL) throws {
    let sampleRate = 44100
    let duration = 0.055
    let numSamples = Int(Double(sampleRate) * duration)
    var pcmData = Data(capacity: numSamples * 2)

    for i in 0..<numSamples {
        let t = Double(i) / Double(sampleRate)
        let env = exp(-t * 68.0) * sin(min(1.0, t / 0.004) * (.pi * 0.5))
        let wave = 0.65 * sin(2.0 * .pi * 1046.5 * t) + 0.35 * sin(2.0 * .pi * 1567.98 * t)
        let sample = Int16(max(-1.0, min(1.0, wave * env * 0.28)) * 32767.0)
        var le = sample.littleEndian
        pcmData.append(Data(bytes: &le, count: 2))
    }

    var wav = Data()
    let dataSize = UInt32(pcmData.count)
    let fileSize = 36 + dataSize
    wav.append("RIFF".data(using: .ascii)!)
    var fsLE = fileSize.littleEndian
    wav.append(Data(bytes: &fsLE, count: 4))
    wav.append("WAVEfmt ".data(using: .ascii)!)
    var fmtSize: UInt32 = 16; wav.append(Data(bytes: &fmtSize, count: 4))
    var audioFormat: UInt16 = 1; wav.append(Data(bytes: &audioFormat, count: 2))
    var numChannels: UInt16 = 1; wav.append(Data(bytes: &numChannels, count: 2))
    var sr: UInt32 = UInt32(sampleRate); wav.append(Data(bytes: &sr, count: 4))
    var byteRate: UInt32 = UInt32(sampleRate * 2); wav.append(Data(bytes: &byteRate, count: 4))
    var blockAlign: UInt16 = 2; wav.append(Data(bytes: &blockAlign, count: 2))
    var bitsPerSample: UInt16 = 16; wav.append(Data(bytes: &bitsPerSample, count: 2))
    wav.append("data".data(using: .ascii)!)
    var dsLE = dataSize.littleEndian
    wav.append(Data(bytes: &dsLE, count: 4))
    wav.append(pcmData)

    try wav.write(to: url, options: .atomic)
}

let args = CommandLine.arguments
let resourcesDir = args.count > 1
    ? URL(fileURLWithPath: args[1])
    : URL(fileURLWithPath: "/Users/vander/DEV/Clone Tagerine/FlowConverter/macos/Resources")

let fm = FileManager.default
try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

let iconsetDir = fm.temporaryDirectory.appendingPathComponent("FlowConverter-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: iconsetDir) }

let iconSpecs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in iconSpecs {
    if let png = drawFlowConverterIcon(size: px) {
        try png.write(to: iconsetDir.appendingPathComponent(filename))
    }
}

let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try proc.run()
proc.waitUntilExit()

let wavURL = resourcesDir.appendingPathComponent("HighlightSound.wav")
try generateHighlightWav(at: wavURL)
print("Generated clean-room AppIcon.icns and HighlightSound.wav in \(resourcesDir.path)")
