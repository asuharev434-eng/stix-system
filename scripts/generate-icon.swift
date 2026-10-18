import AppKit
import Foundation
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
let rect = NSRect(x: 72, y: 72, width: 880, height: 880)
let shape = NSBezierPath(roundedRect: rect, xRadius: 208, yRadius: 208)
let gradient = NSGradient(starting: NSColor(srgbRed: 0.29, green: 0.48, blue: 0.98, alpha: 1), ending: NSColor(srgbRed: 0.13, green: 0.24, blue: 0.62, alpha: 1))!
gradient.draw(in: shape, angle: -90)
let wave = NSBezierPath()
wave.move(to: NSPoint(x: 240, y: 490))
wave.line(to: NSPoint(x: 355, y: 490))
wave.line(to: NSPoint(x: 420, y: 660))
wave.line(to: NSPoint(x: 530, y: 355))
wave.line(to: NSPoint(x: 620, y: 555))
wave.line(to: NSPoint(x: 680, y: 490))
wave.line(to: NSPoint(x: 785, y: 490))
wave.lineWidth = 51; wave.lineJoinStyle = .round; wave.lineCapStyle = .round
NSColor.white.setStroke(); wave.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
