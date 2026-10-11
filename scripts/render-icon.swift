#!/usr/bin/env swift
// Renders the Press59 logo — an orange "59" keycap — into the app's AppIcon set,
// the menu bar template icon, the website's icons and its link preview card. Run from the repo root: `swift scripts/render-icon.swift`.

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

/// Draws the 1200×630 link preview card (Open Graph image) shown when press59.win is shared in
/// Slack, iMessage and elsewhere: the headline on the left, the keycap logo on the right.
let cardSize = CGSize(width: 1200, height: 630)

func drawSocialCard(in context: CGContext) {
    let ground = NSColor(srgbRed: 0.949, green: 0.945, blue: 0.933, alpha: 1)  // #F2F1EE
    let muted = NSColor(srgbRed: 0.333, green: 0.341, blue: 0.369, alpha: 1)   // #55575E
    let line = NSColor(srgbRed: 0.835, green: 0.827, blue: 0.808, alpha: 1)    // #D5D3CE
    let capShadow = NSColor(srgbRed: 0.788, green: 0.776, blue: 0.749, alpha: 1) // #C9C6BF

    context.setFillColor(ground.cgColor)
    context.fill(CGRect(origin: .zero, size: cardSize))

    // Logo on the right, drawn by the same code as the app icon.
    let iconSide: CGFloat = 380
    context.saveGState()
    context.translateBy(x: cardSize.width - iconSide - 60, y: (cardSize.height - iconSide) / 2)
    context.scaleBy(x: iconSide / 1024, y: iconSide / 1024)
    drawIcon(in: context)
    context.restoreGState()

    // Everything else is laid out top-down, so flip to a top-left origin.
    context.saveGState()
    context.translateBy(x: 0, y: cardSize.height)
    context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

    let left: CGFloat = 80
    let maxWidth: CGFloat = 640

    func text(_ string: String, font: NSFont, color: NSColor, kern: CGFloat = 0) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color, .kern: kern])
    }

    text("PRESS59 · FOR MAC", font: .monospacedSystemFont(ofSize: 20, weight: .bold), color: muted, kern: 2)
        .draw(at: CGPoint(x: left, y: 82))

    // Largest heavy headline that fits beside the logo.
    let lines = ["Hold Caps Lock.", "Press C.", "You’re in Chrome."]
    var fontSize: CGFloat = 84
    while fontSize > 40, lines.contains(where: {
        text($0, font: .systemFont(ofSize: fontSize, weight: .heavy), color: ink, kern: -fontSize * 0.03).size().width > maxWidth
    }) {
        fontSize -= 2
    }
    var y: CGFloat = 132
    for headline in lines {
        let string = text(headline, font: .systemFont(ofSize: fontSize, weight: .heavy), color: ink, kern: -fontSize * 0.03)
        string.draw(at: CGPoint(x: left, y: y))
        y += fontSize * 1.08
    }

    // ⇪ + C keycaps, like the homepage hero.
    func keycap(_ rect: CGRect, fill: NSColor, edge: NSColor, lip: NSColor) {
        let lipRect = rect.offsetBy(dx: 0, dy: 5)
        context.addPath(CGPath(roundedRect: lipRect, cornerWidth: 12, cornerHeight: 12, transform: nil))
        context.setFillColor(lip.cgColor)
        context.fillPath()
        let face = CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)
        context.addPath(face)
        context.setFillColor(fill.cgColor)
        context.fillPath()
        context.addPath(face)
        context.setStrokeColor(edge.cgColor)
        context.setLineWidth(1.5)
        context.strokePath()
    }
    let keysTop: CGFloat = 470
    let capsRect = CGRect(x: left, y: keysTop, width: 190, height: 76)
    keycap(capsRect, fill: accent, edge: accentDark, lip: accentDark)
    let capsSymbol = text("⇪", font: .systemFont(ofSize: 30, weight: .semibold), color: ink)
    capsSymbol.draw(at: CGPoint(x: capsRect.minX + 18, y: capsRect.midY - capsSymbol.size().height / 2))
    let capsLabel = text("caps lock", font: .monospacedSystemFont(ofSize: 17, weight: .bold), color: ink)
    capsLabel.draw(at: CGPoint(x: capsRect.maxX - 20 - capsLabel.size().width, y: capsRect.midY - 11))

    let plus = text("+", font: .systemFont(ofSize: 40, weight: .light), color: muted)
    plus.draw(at: CGPoint(x: capsRect.maxX + 22, y: capsRect.midY - plus.size().height / 2))

    let letterRect = CGRect(x: capsRect.maxX + 72, y: keysTop, width: 76, height: 76)
    keycap(letterRect, fill: .white, edge: line, lip: capShadow)
    let letter = text("C", font: .monospacedSystemFont(ofSize: 32, weight: .bold), color: ink)
    letter.draw(at: CGPoint(x: letterRect.midX - letter.size().width / 2, y: letterRect.midY - letter.size().height / 2))

    text("press59.win", font: .systemFont(ofSize: 24, weight: .semibold), color: muted)
        .draw(at: CGPoint(x: letterRect.maxX + 36, y: letterRect.midY - 15))

    NSGraphicsContext.restoreGraphicsState()
    context.restoreGState()
}

func writeSocialCard(to url: URL) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(cardSize.width), pixelsHigh: Int(cardSize.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    context.interpolationQuality = .high
    drawSocialCard(in: context)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
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
try writeSocialCard(to: web.appendingPathComponent("og-image.png"))

print("Rendered app icons, web icons and the link preview card")
