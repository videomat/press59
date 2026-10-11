#!/usr/bin/env swift
// Renders the background of the DMG install window (the "drag to Applications" window) into
// app/Distribution/dmg-background.tiff, with 1x and 2x images for Retina screens.
// Run from the repo root: `swift scripts/render-dmg-background.swift`.
// The layout matches the window and icon positions in scripts/package.

import AppKit

let size = CGSize(width: 560, height: 340)
let appIconCenter = CGPoint(x: 150, y: 160)        // Top-left origin, as in create-dmg.
let applicationsCenter = CGPoint(x: 410, y: 160)

let ground = NSColor(srgbRed: 0.949, green: 0.945, blue: 0.933, alpha: 1)   // #F2F1EE
let line = NSColor(srgbRed: 0.725, green: 0.714, blue: 0.686, alpha: 1)     // #B9B6AF
let muted = NSColor(srgbRed: 0.333, green: 0.341, blue: 0.369, alpha: 1)    // #55575E
let faint = NSColor(srgbRed: 0.541, green: 0.549, blue: 0.573, alpha: 1)    // #8A8C92

func draw(in context: CGContext) {
    // Flip to a top-left origin so coordinates match create-dmg's icon positions.
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

    context.setFillColor(ground.cgColor)
    context.fill(CGRect(origin: .zero, size: size))

    // Dashed arrow from the app to Applications, between the two 112pt icons.
    let start = CGPoint(x: appIconCenter.x + 76, y: appIconCenter.y)
    let end = CGPoint(x: applicationsCenter.x - 76, y: applicationsCenter.y)
    context.setStrokeColor(line.cgColor)
    context.setLineWidth(2.5)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineDash(phase: 0, lengths: [1, 8])
    context.move(to: start)
    context.addLine(to: CGPoint(x: end.x - 4, y: end.y))
    context.strokePath()
    context.setLineDash(phase: 0, lengths: [])
    context.move(to: CGPoint(x: end.x - 10, y: end.y - 9))
    context.addLine(to: end)
    context.addLine(to: CGPoint(x: end.x - 10, y: end.y + 9))
    context.strokePath()

    func drawCentered(_ text: String, y: CGFloat, font: NSFont, color: NSColor, kern: CGFloat = 0) {
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .kern: kern])
        let textSize = string.size()
        string.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: y))
    }

    drawCentered("HOLD CAPS LOCK. PRESS A LETTER.", y: 34,
                 font: .monospacedSystemFont(ofSize: 10, weight: .semibold), color: faint, kern: 1.2)
    drawCentered("Drag Press59 to Applications", y: 262,
                 font: .systemFont(ofSize: 13, weight: .semibold), color: muted)
}

func renderPNG(scale: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(size.width) * scale, pixelsHigh: Int(size.height) * scale,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    NSGraphicsContext.saveGraphicsState()
    draw(in: context)
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("app/Distribution/dmg-background.tiff")
let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("press59-dmg-background")
try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
let oneX = scratch.appendingPathComponent("background.png")
let twoX = scratch.appendingPathComponent("background@2x.png")
try renderPNG(scale: 1, to: oneX)
try renderPNG(scale: 2, to: twoX)

// Combine both resolutions into one TIFF, which Finder picks from on Retina screens.
let tiffutil = Process()
tiffutil.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiffutil.arguments = ["-cathidpicheck", oneX.path, twoX.path, "-out", output.path]
try tiffutil.run()
tiffutil.waitUntilExit()
guard tiffutil.terminationStatus == 0 else { fatalError("tiffutil failed") }

print("Rendered \(output.path)")
