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

    color(0.055, 0.22, 0.12).setFill()
    roundedRect(bounds.insetBy(dx: 54 * scale, dy: 54 * scale), 216 * scale).fill()

    color(0.34, 0.86, 0.18).setFill()
    roundedRect(bounds.insetBy(dx: 74 * scale, dy: 74 * scale), 196 * scale).fill()

    color(0.48, 1.0, 0.26, 0.95).setFill()
    roundedRect(CGRect(x: 112 * scale, y: 560 * scale, width: 800 * scale, height: 268 * scale), 134 * scale).fill()

    let videoRect = CGRect(x: 176 * scale, y: 282 * scale, width: 672 * scale, height: 404 * scale)
    color(0.03, 0.12, 0.11).setFill()
    roundedRect(videoRect, 74 * scale).fill()

    color(1, 1, 1, 0.96).setStroke()
    let videoOutline = roundedRect(videoRect.insetBy(dx: 16 * scale, dy: 16 * scale), 58 * scale)
    videoOutline.lineWidth = 28 * scale
    videoOutline.stroke()

    color(1, 1, 1, 0.20).setFill()
    for i in 0..<3 {
        let x = CGFloat(232 + i * 94) * scale
        let topSlot = CGRect(x: x, y: 618 * scale, width: 52 * scale, height: 20 * scale)
        let bottomSlot = CGRect(x: x, y: 330 * scale, width: 52 * scale, height: 20 * scale)
        roundedRect(topSlot, 10 * scale).fill()
        roundedRect(bottomSlot, 10 * scale).fill()
    }

    let play = NSBezierPath()
    play.move(to: CGPoint(x: 444 * scale, y: 386 * scale))
    play.line(to: CGPoint(x: 444 * scale, y: 582 * scale))
    play.line(to: CGPoint(x: 628 * scale, y: 484 * scale))
    play.close()
    color(1.0, 1.0, 1.0).setFill()
    play.fill()

    let bubbleRects = [
        CGRect(x: 164 * scale, y: 168 * scale, width: 214 * scale, height: 146 * scale),
        CGRect(x: 405 * scale, y: 126 * scale, width: 214 * scale, height: 146 * scale),
        CGRect(x: 646 * scale, y: 168 * scale, width: 214 * scale, height: 146 * scale)
    ]
    let bubbleColors = [
        color(1.0, 1.0, 1.0),
        color(0.10, 0.88, 0.95),
        color(1.0, 0.92, 0.18)
    ]
    let labels = ["A", "あ", "中"]

    for index in 0..<bubbleRects.count {
        bubbleColors[index].setFill()
        roundedRect(bubbleRects[index], 46 * scale).fill()

        let font = NSFont.systemFont(ofSize: 78 * scale, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color(0.04, 0.16, 0.12)
        ]
        let text = labels[index] as NSString
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: bubbleRects[index].midX - textSize.width / 2,
            y: bubbleRects[index].midY - textSize.height / 2 - 4 * scale,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect, withAttributes: attributes)
    }

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
