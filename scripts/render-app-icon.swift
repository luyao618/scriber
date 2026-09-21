import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Native vector artwork. The six bar heights follow docs/media/scriber-mark.svg.
// Draw each representation at its own size to keep the small marks legible.
guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift scripts/render-app-icon.swift OUTPUT_DIRECTORY")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = output.appendingPathComponent("Scriber.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func render(_ pixels: Int, to url: URL) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: pixels, height: pixels,
                            bitsPerComponent: 8, bytesPerRow: pixels * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    let tile = CGPath(roundedRect: CGRect(x: 92, y: 92, width: 840, height: 840),
                      cornerWidth: 188, cornerHeight: 188, transform: nil)

    // A restrained edge and shadow give the tile a native, tactile surface.
    context.saveGState()
    // Quartz shadows use device pixels rather than the scaled drawing space.
    context.setShadow(offset: CGSize(width: 0, height: -14 * scale), blur: 26 * scale,
                      color: color(0x25203F, alpha: 0.24))
    context.addPath(tile)
    context.setFillColor(color(0x7067CF))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tile)
    context.clip()
    let face = CGGradient(colorsSpace: space,
                          colors: [color(0xA398EE), color(0x7A6ED9), color(0x6055B4)] as CFArray,
                          locations: [0, 0.48, 1])!
    context.drawLinearGradient(face, start: CGPoint(x: 180, y: 980), end: CGPoint(x: 770, y: 60),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()

    context.addPath(tile)
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.32))
    context.setLineWidth(2)
    context.strokePath()

    // No letters, record-status dot or extra frame: one recognizable waveform.
    let centers: [CGFloat] = [272, 368, 464, 560, 656, 752]
    let heights: [CGFloat] = [110, 330, 495, 193, 330, 110]
    let barWidth: CGFloat = pixels <= 32 ? 68 : 58
    let waveform = CGMutablePath()
    for (x, height) in zip(centers, heights) {
        let center = pixels <= 32 ? (x * scale).rounded() / scale : x
        waveform.addRoundedRect(in: CGRect(x: center - barWidth / 2, y: 512 - height / 2,
                                           width: barWidth, height: height),
                                 cornerWidth: barWidth / 2, cornerHeight: barWidth / 2)
    }
    context.saveGState()
    if pixels > 32 {
        context.setShadow(offset: CGSize(width: 0, height: -8 * scale), blur: 12 * scale,
                          color: color(0x2E255F, alpha: 0.27))
    }
    context.addPath(waveform)
    context.setFillColor(color(0xF5F3FF))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(waveform)
    context.clip()
    let bars = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF), color(0xE9E5FF)] as CFArray,
                          locations: [0, 1])!
    context.drawLinearGradient(bars, start: CGPoint(x: 0, y: 760), end: CGPoint(x: 0, y: 260), options: [])
    context.restoreGState()

    let image = context.makeImage()!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

for size in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let suffix = factor == 2 ? "@2x" : ""
        try render(size * factor, to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
try render(1024, to: output.appendingPathComponent("Scriber-1024.png"))
let encoder = Process()
encoder.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
encoder.arguments = ["--convert", "icns", "--output", output.appendingPathComponent("AppIcon.icns").path, iconset.path]
try encoder.run()
encoder.waitUntilExit()
guard encoder.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
print(iconset.path)
