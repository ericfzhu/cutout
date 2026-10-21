import SwiftUI

/// Zoom is relative to the fitted image, not its source-pixel resolution.
final class CanvasViewport: ObservableObject {
    @Published private(set) var zoom: CGFloat = 1
    @Published var offset = CGPoint.zero

    func fit() {
        zoom = 1
        offset = .zero
    }

    func magnify(by factor: CGFloat, anchor: CGPoint = .zero) {
        guard factor.isFinite, factor > 0 else { return }
        let next = min(max(zoom * factor, 1), 16)
        let ratio = next / zoom
        offset = CGPoint(x: anchor.x + (offset.x - anchor.x) * ratio,
                         y: anchor.y + (offset.y - anchor.y) * ratio)
        zoom = next
        if zoom == 1 { offset = .zero }
    }

    static func fittingBounds(in canvas: CGRect) -> CGRect {
        CGRect(x: canvas.minX, y: canvas.minY + 12,
               width: canvas.width, height: max(0, canvas.height - 148))
    }

    static func imageRect(size: CGSize, bounds: CGRect, zoom: CGFloat, offset: CGPoint, inset: CGFloat = 12) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let available = bounds.insetBy(dx: inset, dy: inset)
        let scale = max(0, min(available.width / size.width, available.height / size.height)) * zoom
        let width = size.width * scale
        let height = size.height * scale
        // Keep small axes centred and prevent panning the image off the canvas.
        let limitX = max(0, (width - available.width) / 2)
        let limitY = max(0, (height - available.height) / 2)
        return CGRect(x: bounds.midX - width / 2 + min(max(offset.x, -limitX), limitX),
                      y: bounds.midY - height / 2 + min(max(offset.y, -limitY), limitY),
                      width: width, height: height)
    }
}
