// Generates Resources/AppIcon.icns (shield + eye). Run: swift scripts/make_icon.swift
import AppKit

let amber = NSColor(red: 0.91, green: 0.64, blue: 0.24, alpha: 1)
let bg = NSColor(red: 0.055, green: 0.063, blue: 0.075, alpha: 1)
let panel = NSColor(red: 0.078, green: 0.090, blue: 0.106, alpha: 1)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    bg.setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s), xRadius: s * 0.22, yRadius: s * 0.22).fill()

    // Shield occupies the middle 62%; y is flipped (AppKit origin bottom-left).
    let box = NSRect(x: s * 0.19, y: s * 0.17, width: s * 0.62, height: s * 0.66)
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: box.minX + x * box.width, y: box.maxY - y * box.height) }
    let shield = NSBezierPath()
    shield.move(to: pt(0.5, 0))
    shield.line(to: pt(0.93, 0.12))
    shield.curve(to: pt(0.5, 1), controlPoint1: pt(0.93, 0.62), controlPoint2: pt(0.70, 0.85))
    shield.curve(to: pt(0.07, 0.12), controlPoint1: pt(0.30, 0.85), controlPoint2: pt(0.07, 0.62))
    shield.close()
    panel.setFill(); shield.fill()
    amber.setStroke(); shield.lineWidth = s * 0.028; shield.stroke()

    let eye = NSBezierPath()
    let l = pt(0.23, 0.45), r = pt(0.77, 0.45)
    eye.move(to: l)
    eye.curve(to: r, controlPoint1: pt(0.37, 0.45 - 0.26 * 4 / 3 * 0.5 * 2), controlPoint2: pt(0.63, 0.45 - 0.26 * 4 / 3 * 0.5 * 2))
    eye.curve(to: l, controlPoint1: pt(0.63, 0.45 + 0.26 * 4 / 3 * 0.5 * 2), controlPoint2: pt(0.37, 0.45 + 0.26 * 4 / 3 * 0.5 * 2))
    eye.close()
    eye.lineWidth = s * 0.022; eye.stroke()

    let c = pt(0.5, 0.45)
    amber.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - s * 0.055, y: c.y - s * 0.055, width: s * 0.11, height: s * 0.11)).fill()
    panel.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - s * 0.02, y: c.y - s * 0.02, width: s * 0.04, height: s * 0.04)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let set = "Resources/AppIcon.iconset"
try? fm.removeItem(atPath: set)
try fm.createDirectory(atPath: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
    try render(base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set, "-o", "Resources/AppIcon.icns"]
try p.run(); p.waitUntilExit()
try? fm.removeItem(atPath: set)
print("Wrote Resources/AppIcon.icns")
