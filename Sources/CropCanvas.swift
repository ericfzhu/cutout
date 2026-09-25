import AppKit
import SwiftUI

struct CropCanvas: NSViewRepresentable {
    let image: NSImage
    let editing: Bool
    let crop: CGRect
    let onChange: (CGRect) -> Void

    func makeNSView(context: Context) -> CropImageView { CropImageView() }
    func updateNSView(_ view: CropImageView, context: Context) {
        view.configure(image: image, editing: editing, crop: crop, onChange: onChange)
    }
}

final class CropImageView: NSView {
    private var sourceImage: NSImage?
    private var sourcePixels: CGImage?
    private var displayedImage: NSImage?
    private var editing = false
    private var crop = CropGeometry.full
    private var onChange: ((CGRect) -> Void)?
    private var dragOrigin: CGPoint?
    private var initialCrop = CropGeometry.full
    private var mode = (horizontal: 0, vertical: 0, creating: false)
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func configure(image: NSImage, editing: Bool, crop: CGRect, onChange: @escaping (CGRect) -> Void) {
        let changed = sourceImage !== image || self.crop != crop || self.editing != editing
        if sourceImage !== image {
            sourceImage = image
            sourcePixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        self.editing = editing
        self.crop = crop
        self.onChange = onChange
        if changed, let sourcePixels {
            let pixels = editing ? sourcePixels : sourcePixels.cropping(to: CropGeometry.pixels(
                crop, size: CGSize(width: sourcePixels.width, height: sourcePixels.height)))
            if let pixels {
                displayedImage = NSImage(cgImage: pixels, size: NSSize(width: pixels.width, height: pixels.height))
            }
        }
        setAccessibilityLabel(editing ? "Crop image. Drag the corners or edges to resize, or drag inside to move." : "Image preview")
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    private var imageRect: CGRect {
        guard let image = displayedImage else { return .zero }
        let available = bounds.insetBy(dx: editing ? 20 : 12, dy: editing ? 20 : 12)
        let scale = max(0, min(available.width / image.size.width, available.height / image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func screenRect(_ unit: CGRect) -> CGRect {
        let frame = imageRect
        return CGRect(x: frame.minX + unit.minX * frame.width, y: frame.minY + unit.minY * frame.height,
                      width: unit.width * frame.width, height: unit.height * frame.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image = displayedImage else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        guard editing else { return }
        let selection = screenRect(crop)
        let shade = NSBezierPath(rect: imageRect)
        shade.append(NSBezierPath(rect: selection))
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        shade.fill()
        let border = NSBezierPath(rect: selection)
        NSColor.black.withAlphaComponent(0.6).setStroke()
        border.lineWidth = 3
        border.stroke()
        NSColor.white.setStroke()
        border.lineWidth = 1
        border.stroke()
        let grid = NSBezierPath()
        for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
            grid.move(to: CGPoint(x: selection.minX + selection.width * fraction, y: selection.minY))
            grid.line(to: CGPoint(x: selection.minX + selection.width * fraction, y: selection.maxY))
            grid.move(to: CGPoint(x: selection.minX, y: selection.minY + selection.height * fraction))
            grid.line(to: CGPoint(x: selection.maxX, y: selection.minY + selection.height * fraction))
        }
        NSColor.white.withAlphaComponent(0.4).setStroke()
        grid.lineWidth = 0.5
        grid.stroke()
        for (point, _, _) in handles {
            let handle = NSBezierPath(roundedRect: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8), xRadius: 2, yRadius: 2)
            NSColor.white.setFill()
            handle.fill()
            NSColor.black.withAlphaComponent(0.5).setStroke()
            handle.lineWidth = 1
            handle.stroke()
        }
    }

    private var handles: [(CGPoint, Int, Int)] {
        let rect = screenRect(crop)
        return [(-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (0, 1), (-1, 0), (1, 0)].map { x, y in
            (CGPoint(x: x < 0 ? rect.minX : x > 0 ? rect.maxX : rect.midX,
                     y: y < 0 ? rect.minY : y > 0 ? rect.maxY : rect.midY), x, y)
        }
    }

    override func resetCursorRects() {
        guard editing else { return }
        addCursorRect(imageRect, cursor: .crosshair)
        addCursorRect(screenRect(crop).insetBy(dx: 10, dy: 10), cursor: .openHand)
        for (point, x, y) in handles {
            addCursorRect(CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16),
                          cursor: x == 0 ? .resizeUpDown : y == 0 ? .resizeLeftRight : .crosshair)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard editing else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard imageRect.insetBy(dx: -10, dy: -10).contains(point) else { return }
        window?.makeFirstResponder(self)
        initialCrop = crop
        dragOrigin = point
        if let handle = handles.first(where: { hypot($0.0.x - point.x, $0.0.y - point.y) <= 12 }) {
            mode = (handle.1, handle.2, false)
        } else if screenRect(crop).contains(point) {
            mode = (0, 0, false)
        } else {
            mode = (0, 0, true)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard editing, let origin = dragOrigin, imageRect.width > 0, imageRect.height > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        let frame = imageRect
        let delta = CGSize(width: (point.x - origin.x) / frame.width, height: (point.y - origin.y) / frame.height)
        let next: CGRect
        if mode.creating {
            let x1 = min(max((origin.x - frame.minX) / frame.width, 0), 1)
            let y1 = min(max((origin.y - frame.minY) / frame.height, 0), 1)
            let x2 = min(max((point.x - frame.minX) / frame.width, 0), 1)
            let y2 = min(max((point.y - frame.minY) / frame.height, 0), 1)
            next = CGRect(x: min(x1, x2), y: min(y1, y2), width: abs(x2 - x1), height: abs(y2 - y1))
            guard next.width * frame.width >= 8, next.height * frame.height >= 8 else { return }
        } else if mode.horizontal == 0 && mode.vertical == 0 {
            next = CropGeometry.moved(initialCrop, by: delta)
        } else {
            next = CropGeometry.resized(initialCrop, by: delta, horizontal: mode.horizontal, vertical: mode.vertical,
                minimum: CGSize(width: min(initialCrop.width, 8 / frame.width), height: min(initialCrop.height, 8 / frame.height)))
        }
        onChange?(next)
    }

    override func mouseUp(with event: NSEvent) { dragOrigin = nil }
}
