import AppKit

// Render the launcher artwork at the exact sizes declared by the tvOS
// asset catalog. The front logo floats above an opaque black back layer.
let catalog = URL(fileURLWithPath: CommandLine.arguments[1])
let fm = FileManager.default
let files = fm.enumerator(at: catalog, includingPropertiesForKeys: nil)!
while let file = files.nextObject() as? URL {
    guard file.pathExtension == "json", file.lastPathComponent == "Contents.json",
          let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any],
          let images = json["images"] as? [[String: Any]] else { continue }
    for image in images {
        guard let name = image["filename"] as? String, name.hasSuffix(".png") else { continue }
        let output = file.deletingLastPathComponent().appendingPathComponent(name)
        guard let original = NSImage(contentsOf: output) else { continue }
        let size = original.size
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let rect = NSRect(origin: .zero, size: size)
        let isFront = output.path.contains("Front.imagestacklayer")
        let isMiddle = output.path.contains("Middle.imagestacklayer")
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        if !isFront && !isMiddle {
            NSColor(calibratedWhite: 0.025, alpha: 1).setFill()
            rect.fill()
        }
        if isFront || !output.path.contains(".imagestack/") {
            let side = size.height * 0.78
            let box = NSRect(x: (size.width-side)/2, y: (size.height-side)/2, width: side, height: side)
            let tile = NSBezierPath(roundedRect: box, xRadius: side*0.22, yRadius: side*0.22)
            NSColor(calibratedWhite: 0.045, alpha: 1).setFill()
            tile.fill()
            NSColor(calibratedRed: 0.96, green: 0.26, blue: 0.20, alpha: 1).setStroke()
            tile.lineWidth = side*0.025
            tile.stroke()
            // Z silhouette, in normalized coordinates with a top-left origin.
            let z = NSBezierPath()
            let points: [(CGFloat, CGFloat)] = [(0.30,0.22),(0.73,0.22),(0.76,0.27),
                (0.75,0.33),(0.43,0.66),(0.70,0.66),(0.70,0.79),
                (0.28,0.79),(0.24,0.75),(0.25,0.69),(0.57,0.36),(0.30,0.36)]
            for (index,p) in points.enumerated() {
                let point = NSPoint(x: box.minX+p.0*side, y: box.maxY-p.1*side)
                if index == 0 { z.move(to: point) } else { z.line(to: point) }
            }
            z.close()
            NSColor(calibratedRed: 0.96, green: 0.26, blue: 0.20, alpha: 1).setFill()
            z.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        try bitmap.representation(using: .png, properties: [:])!.write(to: output)
        print("ZPlay icon: \(name) \(Int(size.width))x\(Int(size.height))")
    }
}
