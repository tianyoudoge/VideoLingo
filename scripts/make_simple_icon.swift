import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let uiDir = root.appendingPathComponent("app/Assets/UI")
let iconsetDir = root.appendingPathComponent("app/Assets/AppIcon.iconset")
let pngURL = uiDir.appendingPathComponent("app-icon.png")

try FileManager.default.createDirectory(at: uiDir, withIntermediateDirectories: true)
try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024

    color(0.045, 0.055, 0.075).setFill()
    roundedRect(bounds.insetBy(dx: 54 * scale, dy: 54 * scale), 216 * scale).fill()

    color(0.08, 0.10, 0.14).setFill()
    roundedRect(bounds.insetBy(dx: 78 * scale, dy: 78 * scale), 192 * scale).fill()

    let videoRect = CGRect(x: 150 * scale, y: 520 * scale, width: 470 * scale, height: 292 * scale)
    color(0.15, 0.44, 0.68).setFill()
    roundedRect(videoRect, 58 * scale).fill()
    color(0.82, 0.94, 1.0, 0.95).setStroke()
    let videoOutline = roundedRect(videoRect.insetBy(dx: 14 * scale, dy: 14 * scale), 44 * scale)
    videoOutline.lineWidth = 22 * scale
    videoOutline.stroke()

    let play = NSBezierPath()
    play.move(to: CGPoint(x: 342 * scale, y: 596 * scale))
    play.line(to: CGPoint(x: 342 * scale, y: 730 * scale))
    play.line(to: CGPoint(x: 470 * scale, y: 663 * scale))
    play.close()
    color(1.0, 1.0, 1.0).setFill()
    play.fill()

    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 438 * scale, y: 476 * scale))
    arrow.curve(to: CGPoint(x: 628 * scale, y: 364 * scale), controlPoint1: CGPoint(x: 506 * scale, y: 454 * scale), controlPoint2: CGPoint(x: 570 * scale, y: 414 * scale))
    color(0.46, 0.76, 0.95).setStroke()
    arrow.lineWidth = 32 * scale
    arrow.lineCapStyle = .round
    arrow.stroke()

    let arrowHead = NSBezierPath()
    arrowHead.move(to: CGPoint(x: 646 * scale, y: 354 * scale))
    arrowHead.line(to: CGPoint(x: 574 * scale, y: 348 * scale))
    arrowHead.line(to: CGPoint(x: 618 * scale, y: 410 * scale))
    arrowHead.close()
    color(0.46, 0.76, 0.95).setFill()
    arrowHead.fill()

    let translateRect = CGRect(x: 458 * scale, y: 176 * scale, width: 416 * scale, height: 310 * scale)
    color(0.96, 0.70, 0.28).setFill()
    roundedRect(translateRect, 72 * scale).fill()
    color(1.0, 0.95, 0.84, 0.96).setFill()
    roundedRect(translateRect.insetBy(dx: 34 * scale, dy: 44 * scale), 42 * scale).fill()

    let primaryAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 118 * scale, weight: .heavy),
        .foregroundColor: color(0.08, 0.10, 0.14)
    ]
    let secondaryAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 72 * scale, weight: .bold),
        .foregroundColor: color(0.15, 0.44, 0.68)
    ]
    ("文" as NSString).draw(in: CGRect(x: 548 * scale, y: 282 * scale, width: 118 * scale, height: 132 * scale), withAttributes: primaryAttributes)
    ("A" as NSString).draw(in: CGRect(x: 682 * scale, y: 286 * scale, width: 84 * scale, height: 96 * scale), withAttributes: secondaryAttributes)

    color(0.08, 0.10, 0.14, 0.22).setFill()
    roundedRect(CGRect(x: 548 * scale, y: 248 * scale, width: 216 * scale, height: 18 * scale), 9 * scale).fill()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixels: Int) throws {
    let target = NSImage(size: NSSize(width: pixels, height: pixels))
    target.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    target.unlockFocus()

    guard
        let tiff = target.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "Icon", code: 1)
    }
    try png.write(to: url)
}

let master = drawIcon(size: 1024)
try writePNG(master, to: pngURL, pixels: 1024)

for size in [16, 32, 128, 256, 512] {
    try writePNG(master, to: iconsetDir.appendingPathComponent("icon_\(size)x\(size).png"), pixels: size)
    try writePNG(master, to: iconsetDir.appendingPathComponent("icon_\(size)x\(size)@2x.png"), pixels: size * 2)
}

print("Wrote \(pngURL.path)")
print("Wrote \(iconsetDir.path)")
