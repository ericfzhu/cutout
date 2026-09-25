import Foundation

enum CropGeometry {
    static let full = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Normalized top-left coordinates → integral source pixels, without scaling.
    static func pixels(_ crop: CGRect, size: CGSize) -> CGRect {
        let clipped = crop.standardized.intersection(full)
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return .zero }
        let x = floor(clipped.minX * size.width)
        let y = floor(clipped.minY * size.height)
        return CGRect(x: x, y: y,
                      width: min(size.width, ceil(clipped.maxX * size.width)) - x,
                      height: min(size.height, ceil(clipped.maxY * size.height)) - y)
    }

    static func moved(_ rect: CGRect, by delta: CGSize) -> CGRect {
        CGRect(x: min(max(0, rect.minX + delta.width), 1 - rect.width),
               y: min(max(0, rect.minY + delta.height), 1 - rect.height),
               width: rect.width, height: rect.height)
    }

    static func resized(_ rect: CGRect, by delta: CGSize, horizontal: Int, vertical: Int,
                        minimum: CGSize) -> CGRect {
        var left = rect.minX, right = rect.maxX, top = rect.minY, bottom = rect.maxY
        if horizontal < 0 { left = min(max(0, left + delta.width), right - minimum.width) }
        if horizontal > 0 { right = max(min(1, right + delta.width), left + minimum.width) }
        if vertical < 0 { top = min(max(0, top + delta.height), bottom - minimum.height) }
        if vertical > 0 { bottom = max(min(1, bottom + delta.height), top + minimum.height) }
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
