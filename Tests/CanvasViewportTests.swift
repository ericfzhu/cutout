import SwiftUI

@main
struct CanvasViewportTests {
    static func main() {
        let viewport = CanvasViewport()
        viewport.magnify(by: 2, anchor: CGPoint(x: 40, y: 20))
        precondition(viewport.zoom == 2 && viewport.offset == CGPoint(x: -40, y: -20), "Zoom must preserve the point under the pointer")
        viewport.magnify(by: 100)
        precondition(viewport.zoom == 16)
        viewport.magnify(by: 0.001)
        precondition(viewport.zoom == 1 && viewport.offset == .zero)
        viewport.magnify(by: .nan)
        precondition(viewport.zoom == 1)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let size = CGSize(width: 800, height: 400)
        let fit = CanvasViewport.imageRect(size: size, bounds: bounds, zoom: 1, offset: CGPoint(x: 999, y: -999))
        precondition(fit == CGRect(x: 12, y: 56, width: 376, height: 188))
        let zoomed = CanvasViewport.imageRect(size: size, bounds: bounds, zoom: 2, offset: CGPoint(x: 999, y: -999))
        precondition(zoomed.minX == 12 && zoomed.maxY == 288, "Pan limits must keep the image covering the viewport")
        let canvas = CGRect(x: 0, y: 0, width: 760, height: 540)
        let fittingBounds = CanvasViewport.fittingBounds(in: canvas)
        let square = CGSize(width: 1000, height: 1000)
        let fitted = CanvasViewport.imageRect(size: square, bounds: fittingBounds, zoom: 1, offset: .zero)
        precondition(fitted.maxY < canvas.maxY - 136, "Fit must leave the floating controls clear")
        let enlarged = CanvasViewport.imageRect(size: square, bounds: fittingBounds, zoom: 3, offset: .zero)
        precondition(enlarged.maxY > canvas.maxY, "Zoomed content must extend behind the bottom controls to the window edge")
        let panned = CanvasViewport.imageRect(size: square, bounds: fittingBounds, zoom: 3, offset: CGPoint(x: 0, y: -9999))
        precondition(panned.maxY == fitted.maxY, "The bottom edge must still be pannable above the controls for inspection")
        viewport.magnify(by: 3)
        viewport.offset = CGPoint(x: 100, y: 100)
        viewport.fit()
        precondition(viewport.zoom == 1 && viewport.offset == .zero)
        print("PASS: anchored zoom, limits, fit geometry, pan bounds, and reset")
    }
}
