// Draws the app icon at 1024 px: three outlined cards fanned out on a white tile.
// Run: swift scripts/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let ink = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)

// Tile.
let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor.white, NSColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)])!.draw(in: tile, angle: -90)
ink.withAlphaComponent(0.08).setStroke()
tile.lineWidth = 4
tile.stroke()

// One card, rotated about the bottom center of the tile.
func card(_ color: NSColor, angle: CGFloat, dx: CGFloat, dy: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: 512 + dx, y: 300 + dy)
    ctx.rotate(by: angle * .pi / 180)
    let rect = NSRect(x: -150, y: 0, width: 300, height: 400)
    let body = NSBezierPath(roundedRect: rect, xRadius: 52, yRadius: 52)
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.16).cgColor)
    color.setFill()
    body.fill()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ink.setStroke()
    body.lineWidth = 18
    body.stroke()
    // A white label strip near the bottom of the card.
    let strip = NSBezierPath(roundedRect: NSRect(x: -100, y: 56, width: 150, height: 34), xRadius: 17, yRadius: 17)
    NSColor.white.setFill()
    strip.fill()
    strip.lineWidth = 10
    strip.stroke()
    ctx.restoreGState()
}

card(NSColor(red: 0.776, green: 0.714, blue: 1.0, alpha: 1), angle: 16, dx: -120, dy: 20)
card(NSColor(red: 0.431, green: 0.616, blue: 0.969, alpha: 1), angle: -16, dx: 120, dy: 20)
card(NSColor(red: 1.0, green: 0.784, blue: 0.239, alpha: 1), angle: 0, dx: 0, dy: 40)

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
