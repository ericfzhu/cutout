import AppKit
import UniformTypeIdentifiers

@main
struct ImportTests {
    @MainActor
    static func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Import did not settle")
    }

    static func delayedFile(_ url: URL) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
                completion(url.dataRepresentation, nil)
            }
            return nil
        }
        return provider
    }

    @MainActor
    static func main() async throws {
        let model = AppModel(worker: InferenceWorker(resourceRoot: nil))
        defer { model.shutdown() }
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        precondition(!model.acceptDrop([NSItemProvider()]) && !model.busy)
        let delayed = delayedFile(missing)
        precondition(model.acceptDrop([delayed]))
        precondition(model.busy && model.status == "Preparing image…", "Drop must acknowledge before the provider completes")
        precondition(!model.acceptDrop([delayed]), "Concurrent drops must be rejected")
        model.cancel()
        try await Task.sleep(for: .milliseconds(400))
        precondition(!model.busy && model.error == nil && model.status == "Cancelled", "Cancelled provider completion must be ignored")
        precondition(model.acceptDrop([delayedFile(missing)]))
        try await waitUntil { !model.busy }
        precondition(model.error != nil, "Unreadable files must release busy state and report the error")
        model.clear()
        model.open(missing)
        precondition(model.busy && model.error == nil, "Open must return before reading the file")
        try await waitUntil { !model.busy }
        precondition(model.error != nil)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 20, pixelsHigh: 10,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let file = folder.appendingPathComponent("sample.png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: file)
        model.clear()
        var sawEarlyPreview = false
        let observation = model.$importPreview.sink { preview in
            if preview != nil {
                precondition(model.busy && model.status == "Preparing image…")
                precondition(model.original == nil, "Quick preview must arrive before the prepared original")
                sawEarlyPreview = true
            }
        }
        precondition(model.acceptDrop([delayedFile(file)]))
        try await waitUntil { !model.busy }
        precondition(sawEarlyPreview && model.importPreview == nil, "Quick preview must be replaced after preparation")
        observation.cancel()
        // The deliberately missing worker fails after import; image preparation must succeed first.
        precondition(model.original != nil && model.dimensions == "20 × 10" && model.filename == "sample")
        print("PASS: immediate drop feedback, busy guard, cancellation, file errors, async open, and successful preparation")
    }
}
