// Draws the app icon: an isometric cube with the standard colours and the amber turn
// arrow the app is built around. Run with `swift Icon/make_icon.swift`.
import AppKit

let colors: [String: NSColor] = [
    "white":  NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.96, alpha: 1),
    "green":  NSColor(calibratedRed: 0.00, green: 0.62, blue: 0.30, alpha: 1),
    "red":    NSColor(calibratedRed: 0.80, green: 0.11, blue: 0.14, alpha: 1),
    "amber":  NSColor(calibratedRed: 1.00, green: 0.72, blue: 0.10, alpha: 1)
]

/// Isometric projection of a unit cube corner onto the image plane.
func project(_ x: Double, _ y: Double, _ z: Double, scale: Double, origin: CGPoint) -> CGPoint {
    let sx = (x - z) * cos(.pi / 6)
    let sy = (x + z) * sin(.pi / 6) - y
    return CGPoint(x: origin.x + sx * scale, y: origin.y - sy * scale)
}

func drawIcon(size: Int) -> NSImage {
    let side = CGFloat(size)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    let radius = side * 0.2237   // matches the macOS squircle closely enough
    let background = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
                                  xRadius: radius, yRadius: radius)
    NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.12, alpha: 1).setFill()
    background.fill()

    let scale = Double(side) * 0.24
    let origin = CGPoint(x: side / 2, y: side * 0.54)
    let n = 3

    func tile(_ corners: [(Double, Double, Double)], color: NSColor) {
        let path = NSBezierPath()
        for (index, corner) in corners.enumerated() {
            let point = project(corner.0, corner.1, corner.2, scale: scale, origin: origin)
            index == 0 ? path.move(to: point) : path.line(to: point)
        }
        path.close()
        color.setFill()
        path.fill()
        NSColor(calibratedWhite: 0.07, alpha: 1).setStroke()
        path.lineWidth = max(1, side * 0.012)
        path.stroke()
    }

    let step = 1.0 / Double(n)
    for i in 0..<n {
        for j in 0..<n {
            let a = Double(i) * step, b = Double(j) * step
            // Top face (y = 1)
            tile([(a, 1, b), (a + step, 1, b), (a + step, 1, b + step), (a, 1, b + step)],
                 color: colors["white"]!)
            // Left face (z = 1), seen from the front-left
            tile([(a, b, 1), (a + step, b, 1), (a + step, b + step, 1), (a, b + step, 1)],
                 color: colors["green"]!)
            // Right face (x = 1)
            tile([(1, b, a), (1, b, a + step), (1, b + step, a + step), (1, b + step, a)],
                 color: colors["red"]!)
        }
    }

    // The turn arrow, curving over the top face.
    let arrowCentre = CGPoint(x: side * 0.5, y: side * 0.735)
    let arrowRadius = side * 0.20
    let arc = NSBezierPath()
    arc.appendArc(withCenter: arrowCentre, radius: arrowRadius,
                  startAngle: 200, endAngle: 340, clockwise: false)
    colors["amber"]!.setStroke()
    arc.lineWidth = side * 0.055
    arc.lineCapStyle = .round
    arc.stroke()

    let tipAngle = 340.0 * .pi / 180
    let tip = CGPoint(x: arrowCentre.x + cos(tipAngle) * Double(arrowRadius),
                      y: arrowCentre.y + sin(tipAngle) * Double(arrowRadius))
    let head = NSBezierPath()
    let headSize = Double(side) * 0.075
    let direction = tipAngle + .pi / 2
    head.move(to: CGPoint(x: tip.x + cos(direction) * headSize,
                          y: tip.y + sin(direction) * headSize))
    head.line(to: CGPoint(x: tip.x + cos(direction - 2.4) * headSize,
                          y: tip.y + sin(direction - 2.4) * headSize))
    head.line(to: CGPoint(x: tip.x + cos(direction + 2.4) * headSize,
                          y: tip.y + sin(direction + 2.4) * headSize))
    head.close()
    colors["amber"]!.setFill()
    head.fill()

    image.unlockFocus()
    return image
}

let iconset = "Icon/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for (size, name) in [(16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"),
                     (64, "icon_32x32@2x"), (128, "icon_128x128"), (256, "icon_128x128@2x"),
                     (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
                     (1024, "icon_512x512@2x")] {
    let image = drawIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
print("wrote \(iconset)")
