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

    let outer = roundedRect(bounds.insetBy(dx: 54 * scale, dy: 54 * scale), 216 * scale)
    NSGradient(colors: [
        color(0.040, 0.055, 0.095),
        color(0.070, 0.125, 0.185),
        color(0.135, 0.090, 0.175)
    ])?.draw(in: outer, angle: -35)

    color(0.25, 0.55, 0.82, 0.22).setFill()
    roundedRect(CGRect(x: 90 * scale, y: 584 * scale, width: 512 * scale, height: 286 * scale), 142 * scale).fill()

    color(0.98, 0.70, 0.32, 0.18).setFill()
    roundedRect(CGRect(x: 430 * scale, y: 112 * scale, width: 494 * scale, height: 326 * scale), 160 * scale).fill()

    color(1, 1, 1, 0.06).setFill()
    roundedRect(CGRect(x: 120 * scale, y: 140 * scale, width: 784 * scale, height: 744 * scale), 176 * scale).fill()

    let sheen = NSBezierPath()
    sheen.move(to: CGPoint(x: 170 * scale, y: 842 * scale))
    sheen.curve(to: CGPoint(x: 842 * scale, y: 628 * scale), controlPoint1: CGPoint(x: 342 * scale, y: 912 * scale), controlPoint2: CGPoint(x: 664 * scale, y: 838 * scale))
    color(1, 1, 1, 0.055).setStroke()
    sheen.lineWidth = 18 * scale
    sheen.lineCapStyle = .round
    sheen.stroke()

    color(0.02, 0.03, 0.05, 0.18).setFill()
    roundedRect(CGRect(x: 170 * scale, y: 132 * scale, width: 724 * scale, height: 130 * scale), 65 * scale).fill()


    let videoRect = CGRect(x: 148 * scale, y: 548 * scale, width: 430 * scale, height: 284 * scale)
    NSGradient(colors: [
        color(0.21, 0.55, 0.78),
        color(0.13, 0.35, 0.58)
    ])?.draw(in: roundedRect(videoRect, 72 * scale), angle: -20)

    color(1, 1, 1, 0.22).setFill()
    roundedRect(CGRect(x: 202 * scale, y: 772 * scale, width: 86 * scale, height: 18 * scale), 9 * scale).fill()
    roundedRect(CGRect(x: 318 * scale, y: 772 * scale, width: 86 * scale, height: 18 * scale), 9 * scale).fill()
    roundedRect(CGRect(x: 434 * scale, y: 772 * scale, width: 86 * scale, height: 18 * scale), 9 * scale).fill()

    let play = NSBezierPath()
    play.move(to: CGPoint(x: 318 * scale, y: 618 * scale))
    play.line(to: CGPoint(x: 318 * scale, y: 730 * scale))
    play.line(to: CGPoint(x: 428 * scale, y: 674 * scale))
    play.close()
    color(1.0, 1.0, 1.0, 0.96).setFill()
    play.fill()

    color(1, 1, 1, 0.82).setFill()
    roundedRect(CGRect(x: 246 * scale, y: 592 * scale, width: 286 * scale, height: 22 * scale), 11 * scale).fill()
    color(1, 1, 1, 0.58).setFill()
    roundedRect(CGRect(x: 284 * scale, y: 558 * scale, width: 210 * scale, height: 18 * scale), 9 * scale).fill()

    let bridge = NSBezierPath()
    bridge.move(to: CGPoint(x: 442 * scale, y: 526 * scale))
    bridge.line(to: CGPoint(x: 558 * scale, y: 464 * scale))
    color(0.58, 0.76, 0.92, 0.70).setStroke()
    bridge.lineWidth = 26 * scale
    bridge.lineCapStyle = .round
    bridge.stroke()

    let bubbleRect = CGRect(x: 458 * scale, y: 160 * scale, width: 426 * scale, height: 332 * scale)
    color(0.96, 0.72, 0.34).setFill()
    roundedRect(bubbleRect, 84 * scale).fill()

    let tail = NSBezierPath()
    tail.move(to: CGPoint(x: 548 * scale, y: 184 * scale))
    tail.line(to: CGPoint(x: 474 * scale, y: 116 * scale))
    tail.line(to: CGPoint(x: 618 * scale, y: 164 * scale))
    tail.close()
    color(0.96, 0.72, 0.34).setFill()
    tail.fill()

    let inner = CGRect(x: 516 * scale, y: 232 * scale, width: 310 * scale, height: 196 * scale)
    color(0.995, 0.965, 0.900).setFill()
    roundedRect(inner, 52 * scale).fill()

    color(0.075, 0.095, 0.135).setFill()
    roundedRect(CGRect(x: 572 * scale, y: 356 * scale, width: 196 * scale, height: 28 * scale), 14 * scale).fill()
    roundedRect(CGRect(x: 552 * scale, y: 306 * scale, width: 236 * scale, height: 26 * scale), 13 * scale).fill()
    color(0.075, 0.095, 0.135, 0.62).setFill()
    roundedRect(CGRect(x: 594 * scale, y: 262 * scale, width: 152 * scale, height: 22 * scale), 11 * scale).fill()

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
