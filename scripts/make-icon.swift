import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
            pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let p = CGFloat(pixels)
        let inset = p * 0.07
        let rect = NSRect(x: inset, y: inset, width: p - inset * 2, height: p - inset * 2)
        NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: p * 0.20, yRadius: p * 0.20).fill()
        // A solid cut paper shape lifted away from a transparency tile.
        NSGraphicsContext.saveGraphicsState()
        let tile = NSBezierPath(roundedRect: NSRect(x: p * 0.38, y: p * 0.20,
            width: p * 0.42, height: p * 0.50), xRadius: p * 0.04, yRadius: p * 0.04)
        tile.addClip()
        NSColor(calibratedWhite: 0.87, alpha: 1).setFill()
        tile.fill()
        NSColor(calibratedWhite: 0.74, alpha: 1).setFill()
        let cell = p * 0.07
        for row in 0..<8 {
            for column in 0..<6 where (row + column).isMultiple(of: 2) {
                NSRect(x: p * 0.38 + CGFloat(column) * cell,
                       y: p * 0.20 + CGFloat(row) * cell, width: cell, height: cell).fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let sheet = NSBezierPath()
        sheet.move(to: NSPoint(x: p * 0.23, y: p * 0.34))
        sheet.line(to: NSPoint(x: p * 0.23, y: p * 0.79))
        sheet.line(to: NSPoint(x: p * 0.49, y: p * 0.79))
        sheet.line(to: NSPoint(x: p * 0.65, y: p * 0.63))
        sheet.line(to: NSPoint(x: p * 0.65, y: p * 0.34))
        sheet.close()
        NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
        sheet.fill()
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: p * 0.49, y: p * 0.77))
        fold.line(to: NSPoint(x: p * 0.49, y: p * 0.63))
        fold.line(to: NSPoint(x: p * 0.63, y: p * 0.63))
        fold.close()
        NSColor(calibratedWhite: 0.43, alpha: 1).setFill()
        fold.fill()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
    }
}
