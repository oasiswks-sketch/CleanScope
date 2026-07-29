import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"
let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to create graphics context")
}

context.setAllowsAntialiasing(true)
let fullRect = NSRect(origin: .zero, size: canvasSize)
let outer = NSBezierPath(roundedRect: fullRect.insetBy(dx: 34, dy: 34), xRadius: 220, yRadius: 220)
NSGradient(
    colors: [
        NSColor(calibratedRed: 0.055, green: 0.078, blue: 0.11, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.18, alpha: 1)
    ]
)?.draw(in: outer, angle: -45)

context.saveGState()
outer.addClip()
let glow = NSBezierPath(ovalIn: NSRect(x: 390, y: 510, width: 760, height: 760))
NSGradient(
    colors: [
        NSColor(calibratedRed: 0.38, green: 0.86, blue: 0.72, alpha: 0.34),
        NSColor(calibratedRed: 0.38, green: 0.86, blue: 0.72, alpha: 0)
    ]
)?.draw(in: glow, relativeCenterPosition: .zero)
context.restoreGState()

let center = NSPoint(x: 512, y: 512)
let ringRect = NSRect(x: 206, y: 206, width: 612, height: 612)
let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = 54
NSColor(calibratedRed: 0.38, green: 0.85, blue: 0.71, alpha: 0.95).setStroke()
ring.stroke()

let innerRing = NSBezierPath(ovalIn: ringRect.insetBy(dx: 112, dy: 112))
innerRing.lineWidth = 26
NSColor(calibratedRed: 0.42, green: 0.74, blue: 0.92, alpha: 0.7).setStroke()
innerRing.stroke()

let vertical = NSBezierPath()
vertical.move(to: NSPoint(x: center.x, y: 270))
vertical.line(to: NSPoint(x: center.x, y: 754))
vertical.lineWidth = 22
vertical.lineCapStyle = .round
NSColor(calibratedWhite: 1, alpha: 0.68).setStroke()
vertical.stroke()

let horizontal = NSBezierPath()
horizontal.move(to: NSPoint(x: 270, y: center.y))
horizontal.line(to: NSPoint(x: 754, y: center.y))
horizontal.lineWidth = 22
horizontal.lineCapStyle = .round
horizontal.stroke()

let dot = NSBezierPath(ovalIn: NSRect(x: 464, y: 464, width: 96, height: 96))
NSColor(calibratedWhite: 0.05, alpha: 1).setFill()
dot.fill()
let dotInner = NSBezierPath(ovalIn: NSRect(x: 483, y: 483, width: 58, height: 58))
NSColor(calibratedRed: 0.39, green: 0.86, blue: 0.72, alpha: 1).setFill()
dotInner.fill()

let sparkle = NSBezierPath()
sparkle.move(to: NSPoint(x: 750, y: 742))
sparkle.curve(
    to: NSPoint(x: 800, y: 792),
    controlPoint1: NSPoint(x: 770, y: 762),
    controlPoint2: NSPoint(x: 780, y: 782)
)
sparkle.curve(
    to: NSPoint(x: 850, y: 742),
    controlPoint1: NSPoint(x: 820, y: 782),
    controlPoint2: NSPoint(x: 830, y: 762)
)
sparkle.curve(
    to: NSPoint(x: 800, y: 692),
    controlPoint1: NSPoint(x: 830, y: 722),
    controlPoint2: NSPoint(x: 820, y: 702)
)
sparkle.curve(
    to: NSPoint(x: 750, y: 742),
    controlPoint1: NSPoint(x: 780, y: 702),
    controlPoint2: NSPoint(x: 770, y: 722)
)
NSColor(calibratedRed: 0.97, green: 0.79, blue: 0.36, alpha: 1).setFill()
sparkle.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}
try png.write(to: URL(fileURLWithPath: outputPath))
