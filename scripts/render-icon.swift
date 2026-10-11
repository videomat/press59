#!/usr/bin/env swift
// Renders the Press59 logo — an orange "59" keycap — into the app's AppIcon set,
// the menu bar template icon and the website's icons. Run from the repo root: `swift scripts/render-icon.swift`.

import AppKit

let accent = NSColor(srgbRed: 1.00, green: 0.42, blue: 0.17, alpha: 1)      // #FF6B2C
let accentLight = NSColor(srgbRed: 1.00, green: 0.55, blue: 0.33, alpha: 1) // #FF8C54
let accentDark = NSColor(srgbRed: 0.76, green: 0.25, blue: 0.05, alpha: 1)  // #C2410C
let ink = NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1)         // #141518

/// Draws the icon on a 1024×1024 canvas, following the macOS icon grid (824pt body).
func drawIcon(in context: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let radius: CGFloat = 185

    // Soft drop shadow under the whole key.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    context.addPath(CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(accentDark.cgColor)
    context.fillPath()
    context.restoreGState()

    // Top face, leaving the darker lip visible at the bottom so it reads as a keycap.
    let face = CGRect(x: body.minX, y: body.minY + 64, width: body.width, height: body.height - 64)
    context.addPath(CGPath(roundedRect: face, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.setFillColor(accent.cgColor)
    context.fillPath()

    // Slightly lighter dish where a finger lands.
    let dish = face.insetBy(dx: 64, dy: 56)
    context.saveGState()
    context.addPath(CGPath(roundedRect: dish, cornerWidth: 130, cornerHeight: 130, transform: nil))
    context.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [accentLight.cgColor, accent.cgColor] as CFArray,
                              locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: dish.maxY), end: CGPoint(x: 0, y: dish.minY), options: [])
    context.restoreGState()

    // "59" legend.
    let font = NSFont.monospacedSystemFont(ofSize: 380, weight: .heavy)
    let legend = NSAttributedString(string: "59", attributes: [.font: font, .foregroundColor: ink, .kern: -12])
    let size = legend.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    legend.draw(at: CGPoint(x: dish.midX - size.width / 2, y: dish.midY - size.height / 2 + 10))
    NSGraphicsContext.restoreGraphicsState()
}

/// Draws the menu bar version on an 18×18pt canvas: a solid keycap with "59" cut out.
/// Only the alpha matters — it ships as a template image that macOS tints for the menu bar.
func drawMenuBarIcon(in context: CGContext) {
    let key = CGRect(x: 1, y: 1, width: 16, height: 16)
    context.addPath(CGPath(roundedRect: key, cornerWidth: 4, cornerHeight: 4, transform: nil))
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()

    let font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .heavy)
    let legend = NSAttributedString(string: "59", attributes: [.font: font, .foregroundColor: NSColor.black, .kern: -0.4])
    let size = legend.size()
    context.setBlendMode(.destinationOut)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    legend.draw(at: CGPoint(x: key.midX - size.width / 2, y: key.midY - size.height / 2 + 0.3))
    NSGraphicsContext.restoreGraphicsState()
}

func writePNG(pixels: Int, canvas: CGFloat = 1024, draw: (CGContext) -> Void = drawIcon, to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    let scale = CGFloat(pixels) / canvas
    context.scaleBy(x: scale, y: scale)
    context.interpolationQuality = .high
    draw(context)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconSet = root.appendingPathComponent("app/Press59/Assets.xcassets/AppIcon.appiconset")
let menuBarSet = root.appendingPathComponent("app/Press59/Assets.xcassets/MenuBarIcon.imageset")
let web = root.appendingPathComponent("web/assets")

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try writePNG(pixels: points * scale, to: iconSet.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconSet.appendingPathComponent("Contents.json"))
try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!
    .write(to: iconSet.deletingLastPathComponent().appendingPathComponent("Contents.json"))

for scale in [1, 2] {
    try writePNG(pixels: 18 * scale, canvas: 18, draw: drawMenuBarIcon,
                 to: menuBarSet.appendingPathComponent("menubar\(scale == 2 ? "@2x" : "").png"))
}
let menuBarContents: [String: Any] = [
    "images": [
        ["idiom": "universal", "scale": "1x", "filename": "menubar.png"],
        ["idiom": "universal", "scale": "2x", "filename": "menubar@2x.png"],
    ],
    "info": ["author": "xcode", "version": 1],
    "properties": ["template-rendering-intent": "template"],
]
try JSONSerialization.data(withJSONObject: menuBarContents, options: [.prettyPrinted, .sortedKeys])
    .write(to: menuBarSet.appendingPathComponent("Contents.json"))

try writePNG(pixels: 32, to: web.appendingPathComponent("favicon-32.png"))
try writePNG(pixels: 180, to: web.appendingPathComponent("apple-touch-icon.png"))
try writePNG(pixels: 512, to: web.appendingPathComponent("icon-512.png"))

print("Rendered app and web icons")
