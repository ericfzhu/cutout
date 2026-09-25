import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ImageFiles {
    static func exportPNG(from sourceURL: URL, crop: CGRect) throws -> Data {
        if crop == CropGeometry.full { return try Data(contentsOf: sourceURL) }
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let cropped = image.cropping(to: CropGeometry.pixels(crop, size: CGSize(width: image.width, height: image.height))) else {
            throw CutoutError.message("Couldn’t crop this image. Reset the crop and try again.")
        }
        let data = NSMutableData()
        guard let output = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw CutoutError.message("Couldn’t create the cropped PNG.")
        }
        CGImageDestinationAddImage(output, cropped, nil)
        guard CGImageDestinationFinalize(output) else {
            throw CutoutError.message("Couldn’t save the cropped PNG.")
        }
        return data as Data
    }

    /// Decode orientation and color profile once, before preview and inference.
    static func normalize(_ data: Data, to destination: URL) throws -> (Int, Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else {
            throw CutoutError.message("This file couldn’t be read as an image. Try a JPEG, PNG, HEIC, TIFF or WebP file.")
        }
        guard width <= 40_000_000 / height else {
            throw CutoutError.message("This image is larger than 40 megapixels. Please resize it before opening it.")
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height,
                  bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CutoutError.message("This image couldn’t be decoded.")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let normalized = context.makeImage(),
              let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CutoutError.message("Couldn’t prepare this image for background removal.")
        }
        CGImageDestinationAddImage(output, normalized, nil)
        guard CGImageDestinationFinalize(output) else {
            throw CutoutError.message("Couldn’t write the prepared image.")
        }
        return (image.width, image.height)
    }
}
