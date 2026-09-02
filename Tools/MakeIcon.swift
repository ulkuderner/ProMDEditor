#!/usr/bin/env swift
// MarkPad uygulama ikonunu Core Graphics ile uretir.
// Kullanim: swift Tools/MakeIcon.swift <cikti_klasoru>

import AppKit
import Foundation

// MARK: - Renkler

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: a)
}

let bgTop    = rgb(0x3E4557)
let bgBottom = rgb(0x191C24)
let inkWhite = rgb(0xF4F1EC)
let amber    = rgb(0xE0A860)

// MARK: - Squircle yolu (macOS ikon gridi)

func squircle(in rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// MARK: - Tek boyut cizimi

func drawIcon(size s: CGFloat) -> NSBitmapImageRep {
    let px = Int(s)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext

    // macOS ikon gridi: 1024 tuvalde 824 govde, 100 kenar bosluk
    let inset = s * (100.0 / 1024.0)
    let body = CGRect(x: inset, y: inset + s * 0.012,
                      width: s - inset * 2, height: s - inset * 2)
    let radius = body.width * 0.2245

    // Golge
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                  blur: s * 0.030,
                  color: rgb(0x000000, 0.32))
    ctx.addPath(squircle(in: body, radius: radius))
    ctx.setFillColor(rgb(0x000000))
    ctx.fillPath()
    ctx.restoreGState()

    // Gradyan govde
    ctx.saveGState()
    ctx.addPath(squircle(in: body, radius: radius))
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: space,
                          colors: [bgTop, bgBottom] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: body.minX, y: body.maxY),
                           end: CGPoint(x: body.maxX, y: body.minY),
                           options: [])

    // Ust parlaklik
    let gloss = CGGradient(colorsSpace: space,
                           colors: [rgb(0xFFFFFF, 0.14), rgb(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawLinearGradient(gloss,
                           start: CGPoint(x: body.midX, y: body.maxY),
                           end: CGPoint(x: body.midX, y: body.midY),
                           options: [])
    ctx.restoreGState()

    // Ince ic kenar
    ctx.saveGState()
    ctx.addPath(squircle(in: body.insetBy(dx: s * 0.0025, dy: s * 0.0025),
                         radius: radius - s * 0.0025))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.13))
    ctx.setLineWidth(s * 0.005)
    ctx.strokePath()
    ctx.restoreGState()

    // MARK: Glif — "M" + asagi ok, altinda h1 cizgisi

    let fontSize = body.width * 0.46
    let descriptor = NSFont.systemFont(ofSize: fontSize, weight: .black)
        .fontDescriptor.withDesign(.rounded)
    let font = descriptor.flatMap { NSFont(descriptor: $0, size: fontSize) }
        ?? NSFont.systemFont(ofSize: fontSize, weight: .black)

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(cgColor: inkWhite)!
    ]
    let mString = NSAttributedString(string: "M", attributes: attrs)
    let mSize = mString.size()

    let chevW = body.width * 0.215
    let gap = body.width * 0.045
    let groupW = mSize.width + gap + chevW
    let groupX = body.midX - groupW / 2
    let baselineY = body.minY + body.height * 0.345

    mString.draw(at: NSPoint(x: groupX, y: baselineY))

    // Asagi ok (chevron)
    let cx = groupX + mSize.width + gap + chevW / 2
    let cy = baselineY + mSize.height * 0.44
    ctx.saveGState()
    ctx.setStrokeColor(amber)
    ctx.setLineWidth(body.width * 0.070)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: cx - chevW / 2, y: cy + chevW * 0.28))
    ctx.addLine(to: CGPoint(x: cx, y: cy - chevW * 0.32))
    ctx.addLine(to: CGPoint(x: cx + chevW / 2, y: cy + chevW * 0.28))
    ctx.strokePath()
    ctx.restoreGState()

    // Baslik alti cizgisi (markdown h1 border-bottom)
    let ruleW = groupW * 1.02
    let ruleH = body.height * 0.040
    let ruleRect = CGRect(x: body.midX - ruleW / 2,
                          y: body.minY + body.height * 0.245,
                          width: ruleW, height: ruleH)
    ctx.addPath(CGPath(roundedRect: ruleRect,
                       cornerWidth: ruleH / 2, cornerHeight: ruleH / 2,
                       transform: nil))
    ctx.setFillColor(rgb(0xFFFFFF, 0.30))
    ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// MARK: - Yazma

func write(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
}

let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for (name, size) in variants {
    write(drawIcon(size: size), to: iconset.appendingPathComponent("\(name).png"))
}

// MARK: - Asset catalog (Mac App Store bunu zorunlu tutuyor)

let assets = outDir.appendingPathComponent("Assets.xcassets")
let appicon = assets.appendingPathComponent("AppIcon.appiconset")
try? FileManager.default.createDirectory(at: appicon, withIntermediateDirectories: true)

for (name, size) in variants {
    write(drawIcon(size: size), to: appicon.appendingPathComponent("\(name).png"))
}

let catalogRoot = #"""
{
  "info" : { "author" : "xcode", "version" : 1 }
}
"""#
try? catalogRoot.write(to: assets.appendingPathComponent("Contents.json"),
                       atomically: true, encoding: .utf8)

// idiom "mac": 16/32/128/256/512 pt, her biri 1x ve 2x
let images = variants.map { name, _ -> String in
    let base = name.replacingOccurrences(of: "@2x", with: "")
    let pt = base.replacingOccurrences(of: "icon_", with: "")
    let scale = name.hasSuffix("@2x") ? "2x" : "1x"
    return """
        {
          "filename" : "\(name).png",
          "idiom" : "mac",
          "scale" : "\(scale)",
          "size" : "\(pt)"
        }
    """
}.joined(separator: ",\n")

let catalogContents = """
{
  "images" : [
\(images)
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try? catalogContents.write(to: appicon.appendingPathComponent("Contents.json"),
                           atomically: true, encoding: .utf8)

print("Uretildi: \(iconset.path)")
print("Uretildi: \(appicon.path)")
