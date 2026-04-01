#!/usr/bin/env swift
import AppKit

struct Palette {
    static let mint = NSColor(calibratedRed: 0.43, green: 0.93, blue: 0.78, alpha: 1)
    static let teal = NSColor(calibratedRed: 0.06, green: 0.55, blue: 0.58, alpha: 1)
    static let deep = NSColor(calibratedRed: 0.03, green: 0.11, blue: 0.22, alpha: 1)
    static let navy = NSColor(calibratedRed: 0.06, green: 0.15, blue: 0.30, alpha: 1)
    static let coral = NSColor(calibratedRed: 0.99, green: 0.56, blue: 0.42, alpha: 1)
    static let cream = NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.95, alpha: 1)
    static let haze = NSColor(calibratedRed: 0.90, green: 0.97, blue: 0.95, alpha: 0.24)
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesDir = projectRoot.appendingPathComponent("macos/Resources")
let assetDir = resourcesDir.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
let icnsURL = resourcesDir.appendingPathComponent("AppIcon.icns")

let iconSpecs: [(filename: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func roundedRectPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ color: NSColor, path: NSBezierPath) {
    color.setFill()
    path.fill()
}

func stroke(_ color: NSColor, path: NSBezierPath, width: CGFloat) {
    color.setStroke()
    path.lineWidth = width
    path.stroke()
}

func addInnerShadow(path: NSBezierPath, color: NSColor, blur: CGFloat, offset: NSSize) {
    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    context.addPath(path.cgPath)
    context.clip()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = offset
    shadow.set()
    let expanded = path.bounds.insetBy(dx: -80, dy: -80)
    NSBezierPath(rect: expanded).fill()
    context.restoreGState()
}

func drawScopeMark(in rect: NSRect) {
    let ringWidth = rect.width * 0.12
    let outerRing = NSBezierPath(ovalIn: rect)
    stroke(Palette.cream.withAlphaComponent(0.94), path: outerRing, width: ringWidth)

    let middleInset = rect.width * 0.19
    let middleRing = NSBezierPath(ovalIn: rect.insetBy(dx: middleInset, dy: middleInset))
    stroke(Palette.mint.withAlphaComponent(0.58), path: middleRing, width: rect.width * 0.025)

    let innerInset = rect.width * 0.32
    let core = NSBezierPath(ovalIn: rect.insetBy(dx: innerInset, dy: innerInset))
    let coreGradient = NSGradient(colors: [
        Palette.mint.withAlphaComponent(0.85),
        Palette.teal.withAlphaComponent(0.92),
        Palette.deep.withAlphaComponent(0.98),
    ])!
    coreGradient.draw(in: core, relativeCenterPosition: NSPoint(x: -0.2, y: 0.7))

    let cx = rect.midX
    let cy = rect.midY
    let crosshair = NSBezierPath()
    crosshair.move(to: NSPoint(x: rect.minX + rect.width * 0.08, y: cy))
    crosshair.line(to: NSPoint(x: rect.maxX - rect.width * 0.08, y: cy))
    crosshair.move(to: NSPoint(x: cx, y: rect.minY + rect.height * 0.08))
    crosshair.line(to: NSPoint(x: cx, y: rect.maxY - rect.height * 0.08))
    stroke(Palette.cream.withAlphaComponent(0.28), path: crosshair, width: rect.width * 0.018)

    let sweep = NSBezierPath()
    sweep.lineWidth = rect.width * 0.05
    sweep.appendArc(withCenter: NSPoint(x: cx, y: cy),
                    radius: rect.width * 0.47,
                    startAngle: 22,
                    endAngle: 72,
                    clockwise: false)
    stroke(Palette.coral, path: sweep, width: sweep.lineWidth)

    let dotSize = rect.width * 0.12
    let dotRect = NSRect(x: rect.maxX - dotSize * 1.15, y: rect.midY + rect.height * 0.16, width: dotSize, height: dotSize)
    let dot = NSBezierPath(ovalIn: dotRect)
    let glow = NSShadow()
    glow.shadowColor = Palette.coral.withAlphaComponent(0.6)
    glow.shadowBlurRadius = dotSize * 0.45
    glow.shadowOffset = .zero
    glow.set()
    fill(Palette.coral, path: dot)
}

func drawProgressPanel(in rect: NSRect) {
    let panel = roundedRectPath(rect, radius: rect.height * 0.28)
    let panelGradient = NSGradient(colors: [
        Palette.haze,
        Palette.cream.withAlphaComponent(0.18),
    ])!
    panelGradient.draw(in: panel, angle: 90)
    stroke(Palette.cream.withAlphaComponent(0.12), path: panel, width: rect.height * 0.04)

    let leftLabelWidth = rect.width * 0.18
    let barHeight = rect.height * 0.18
    let trackWidth = rect.width - leftLabelWidth - rect.width * 0.16
    let rowGap = rect.height * 0.18
    let firstY = rect.maxY - rect.height * 0.32 - barHeight

    for (index, row) in [("5H", 0.68, Palette.mint), ("7D", 0.42, Palette.coral)].enumerated() {
        let y = firstY - CGFloat(index) * (barHeight + rowGap)
        let labelRect = NSRect(x: rect.minX + rect.width * 0.08, y: y - rect.height * 0.025, width: leftLabelWidth, height: barHeight * 1.5)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: rect.height * 0.12, weight: .bold),
            .foregroundColor: Palette.cream.withAlphaComponent(0.95),
            .paragraphStyle: paragraph,
        ]
        NSAttributedString(string: row.0, attributes: attrs).draw(in: labelRect)

        let trackRect = NSRect(x: labelRect.maxX + rect.width * 0.04, y: y, width: trackWidth, height: barHeight)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        fill(Palette.cream.withAlphaComponent(0.16), path: track)

        let fillRect = NSRect(x: trackRect.minX, y: trackRect.minY, width: trackRect.width * row.1, height: trackRect.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        let gradient = NSGradient(colors: [row.2.withAlphaComponent(0.95), row.2.withAlphaComponent(0.68)])!
        gradient.draw(in: fillPath, angle: 0)
    }
}

func drawIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let canvas = NSRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    NSColor.clear.setFill()
    canvas.fill()

    let inset = canvas.width * 0.035
    let shellRect = canvas.insetBy(dx: inset, dy: inset)
    let shellRadius = shellRect.width * 0.23
    let shell = roundedRectPath(shellRect, radius: shellRadius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = canvas.width * 0.055
    shadow.shadowOffset = NSSize(width: 0, height: -canvas.width * 0.022)
    shadow.set()

    let bgGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.71, blue: 0.69, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.36, blue: 0.45, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.30, alpha: 1),
    ])!
    bgGradient.draw(in: shell, angle: -42)

    let clip = shell.copy() as! NSBezierPath
    clip.addClip()

    let warmGlow = NSBezierPath(ovalIn: NSRect(x: shellRect.maxX - shellRect.width * 0.62,
                                               y: shellRect.maxY - shellRect.height * 0.54,
                                               width: shellRect.width * 0.78,
                                               height: shellRect.height * 0.78))
    let warmGradient = NSGradient(colors: [
        Palette.coral.withAlphaComponent(0.46),
        Palette.coral.withAlphaComponent(0.0),
    ])!
    warmGradient.draw(in: warmGlow, relativeCenterPosition: NSPoint(x: 0.15, y: 0.2))

    let coolGlow = NSBezierPath(ovalIn: NSRect(x: shellRect.minX - shellRect.width * 0.1,
                                               y: shellRect.minY + shellRect.height * 0.16,
                                               width: shellRect.width * 0.75,
                                               height: shellRect.height * 0.75))
    let coolGradient = NSGradient(colors: [
        Palette.mint.withAlphaComponent(0.24),
        Palette.mint.withAlphaComponent(0.0),
    ])!
    coolGradient.draw(in: coolGlow, relativeCenterPosition: NSPoint(x: -0.25, y: 0.1))

    let rim = roundedRectPath(shellRect.insetBy(dx: canvas.width * 0.006, dy: canvas.width * 0.006),
                              radius: shellRadius * 0.96)
    stroke(Palette.cream.withAlphaComponent(0.12), path: rim, width: canvas.width * 0.008)
    addInnerShadow(path: shell, color: NSColor.black.withAlphaComponent(0.22), blur: canvas.width * 0.03, offset: NSSize(width: 0, height: -canvas.width * 0.015))

    let scopeSize = shellRect.width * 0.5
    let scopeRect = NSRect(x: shellRect.midX - scopeSize / 2,
                           y: shellRect.minY + shellRect.height * 0.34,
                           width: scopeSize,
                           height: scopeSize)
    drawScopeMark(in: scopeRect)

    let panelRect = NSRect(x: shellRect.minX + shellRect.width * 0.16,
                           y: shellRect.minY + shellRect.height * 0.11,
                           width: shellRect.width * 0.68,
                           height: shellRect.height * 0.2)
    drawProgressPanel(in: panelRect)

    return image
}

func pngData(for image: NSImage, size: Int) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    rep.size = NSSize(width: size, height: size)
    return rep.representation(using: .png, properties: [:])
}

let fm = FileManager.default
try fm.createDirectory(at: assetDir, withIntermediateDirectories: true)

for spec in iconSpecs {
    let image = drawIcon(size: spec.size)
    let fileURL = assetDir.appendingPathComponent(spec.filename)
    guard let data = pngData(for: image, size: spec.size) else {
        fatalError("Failed to encode \(spec.filename)")
    }
    try data.write(to: fileURL)
    print("Wrote \(fileURL.path)")
}

let iconsetDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("claudescope.iconset")
try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
for spec in iconSpecs {
    let src = assetDir.appendingPathComponent(spec.filename)
    let dst = iconsetDir.appendingPathComponent(spec.filename)
    try? fm.removeItem(at: dst)
    try fm.copyItem(at: src, to: dst)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(iconutil.terminationStatus)")
}

print("Wrote \(icnsURL.path)")
