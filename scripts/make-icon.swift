// Draws the app icon at 1024 px. Run: swift scripts/make-icon.swift out.png
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Squircle plate.
let plate = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1), NSColor(red: 0.80, green: 0.88, blue: 0.99, alpha: 1)])!
    .draw(in: plate, angle: -90)

// Folder: back tab and front body.
let back = NSBezierPath(roundedRect: NSRect(x: 230, y: 300, width: 564, height: 420), xRadius: 60, yRadius: 60)
back.append(NSBezierPath(roundedRect: NSRect(x: 230, y: 640, width: 240, height: 110), xRadius: 50, yRadius: 50))
NSColor(red: 0.36, green: 0.58, blue: 0.97, alpha: 1).setFill()
back.fill()
let front = NSBezierPath(roundedRect: NSRect(x: 230, y: 270, width: 564, height: 380), xRadius: 60, yRadius: 60)
NSGradient(colors: [NSColor(red: 0.64, green: 0.81, blue: 1.0, alpha: 1), NSColor(red: 0.42, green: 0.64, blue: 0.99, alpha: 1)])!
    .draw(in: front, angle: -90)

// Spark.
let config = NSImage.SymbolConfiguration(pointSize: 230, weight: .semibold).applying(.init(paletteColors: [.white]))
if let spark = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let s = spark.size
    spark.draw(in: NSRect(x: 512 - s.width / 2, y: 460 - s.height / 2, width: s.width, height: s.height))
}
_ = ctx
image.unlockFocus()

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
