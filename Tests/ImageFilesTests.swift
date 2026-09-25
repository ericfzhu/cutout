import AppKit
import ImageIO
import UniformTypeIdentifiers

@main
struct ImageFilesTests {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("CutoutImageTests-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let output = folder.appendingPathComponent("normalized.png")
        let color = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8,
                                bytesPerRow: 0, space: color,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        let image = context.makeImage()!
        let data = NSMutableData()
        let encoder = CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(encoder, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
        precondition(CGImageDestinationFinalize(encoder))
        let size = try ImageFiles.normalize(data as Data, to: output)
        precondition(size.0 == 20 && size.1 == 40, "EXIF orientation was not applied")
        let source = CGImageSourceCreateWithURL(output as CFURL, nil)!
        let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        precondition(decoded.alphaInfo != .none, "Input transparency was lost")
        do {
            _ = try ImageFiles.normalize(Data("not an image".utf8), to: output)
            fatalError("Invalid file was accepted")
        } catch { }
        print("PASS: orientation, transparency, invalid input")

        let sample = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 6,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<6 {
            for x in 0..<8 {
                sample.setColor(NSColor(calibratedRed: CGFloat(x) / 8, green: CGFloat(y) / 6,
                    blue: 0.4, alpha: y == 0 ? 0.5 : 1), atX: x, y: y)
            }
        }
        let sampleURL = folder.appendingPathComponent("crop-source.png")
        let sampleData = sample.representation(using: .png, properties: [:])!
        try sampleData.write(to: sampleURL)
        let cropped = try ImageFiles.exportPNG(from: sampleURL, crop: CGRect(x: 0.25, y: 0, width: 0.5, height: 0.5))
        let actual = NSBitmapImageRep(data: cropped)!
        let original = NSBitmapImageRep(data: sampleData)!
        precondition(actual.pixelsWide == 4 && actual.pixelsHigh == 3)
        for y in 0..<3 {
            for x in 0..<4 {
                let expected = original.colorAt(x: x + 2, y: y)!.usingColorSpace(.deviceRGB)!
                let found = actual.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                precondition(abs(expected.redComponent - found.redComponent) < 0.01)
                precondition(abs(expected.greenComponent - found.greenComponent) < 0.01,
                             "Crop used the wrong vertical origin")
                precondition(abs(expected.alphaComponent - found.alphaComponent) < 0.01,
                             "Cropping changed soft transparency")
            }
        }
        let fullExport = try ImageFiles.exportPNG(from: sampleURL, crop: CropGeometry.full)
        precondition(fullExport == sampleData, "Reset must preserve the full original PNG")
        let bounded = CropGeometry.moved(CGRect(x: 0.2, y: 0.3, width: 0.5, height: 0.4),
                                         by: CGSize(width: 2, height: -2))
        precondition(bounded == CGRect(x: 0.5, y: 0, width: 0.5, height: 0.4))
        let resized = CropGeometry.resized(CropGeometry.full, by: CGSize(width: 2, height: 2),
            horizontal: -1, vertical: -1, minimum: CGSize(width: 0.1, height: 0.1))
        precondition(abs(resized.width - 0.1) < 0.0001 && abs(resized.height - 0.1) < 0.0001)
        print("PASS: crop pixel coordinates, soft alpha, full-image reset and bounded crop gestures")
    }
}
