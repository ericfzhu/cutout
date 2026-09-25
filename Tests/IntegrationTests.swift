import AppKit
import Foundation

/// Exercises the actual drop/import → bundled subprocess → PNG → retry path.
@main
struct IntegrationTests {
    @MainActor
    static func wait(until predicate: () -> Bool, seconds: Double = 90) async throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !predicate() {
            if Date() > deadline { throw CutoutError.message("Timed out waiting for integration test") }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    @MainActor
    static func main() async throws {
        let arguments = CommandLine.arguments
        precondition(arguments.count == 3, "Usage: integration-tests ResourcesFolder SampleImage")
        let resources = URL(fileURLWithPath: arguments[1])
        let source = URL(fileURLWithPath: arguments[2])
        let model = AppModel(worker: InferenceWorker(resourceRoot: resources))
        defer { model.shutdown() }
        precondition(model.removalMode == .segmentation, "Default must be segmentation")
        let provider = NSItemProvider(contentsOf: source)!
        precondition(model.acceptDrop([provider]), "Image drop rejected")
        try await wait(until: { model.busy || model.error != nil })
        try await wait(until: { !model.busy })
        precondition(model.error == nil, model.error ?? "")
        precondition(model.result != nil, "No cutout returned from bundled runtime")
        precondition(model.dimensions == "1546 × 1213", "Export size changed")
        print("PASS: file drop automatically produces an original-size cutout")

        let segmentation = model.result!.tiffRepresentation!
        model.crop = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let savedCrop = model.crop
        model.selectMode(.matting)
        try await wait(until: { model.status == "Removing background…" || model.error != nil })
        precondition(model.error == nil, model.error ?? "")
        model.cancel()
        precondition(!model.busy && model.removalMode == .segmentation, "Cancel must restore completed mode")
        precondition(model.result?.tiffRepresentation == segmentation, "Cancel lost completed segmentation")
        precondition(model.crop == savedCrop, "Cancel lost crop")
        model.selectMode(.segmentation)
        precondition(!model.busy, "Completed mode should not reprocess")
        try await Task.sleep(for: .seconds(3))
        print("PASS: cancel mode switch restores the prior cutout and crop")

        model.selectMode(.matting)
        precondition(model.busy && model.result == nil, "Switch must discard stale output and process")
        model.selectMode(.segmentation)
        precondition(model.removalMode == .matting, "Busy mode change must be ignored")
        try await wait(until: { !model.busy })
        precondition(model.error == nil, model.error ?? "")
        precondition(model.result != nil && model.crop == savedCrop, "Mode switch lost result or crop")
        precondition(model.result!.tiffRepresentation! != segmentation, "Modes returned identical results")
        let matting = model.result!.tiffRepresentation!
        model.selectMode(.segmentation)
        precondition(!model.busy, "Cached segmentation must be immediate")
        precondition(model.error == nil && model.result != nil, "Switch back failed")
        precondition(model.result!.tiffRepresentation! == segmentation, "Switch back did not restore segmentation")
        model.selectMode(.matting)
        precondition(!model.busy && model.result?.tiffRepresentation == matting, "Cached matting must be immediate")
        model.selectMode(.segmentation)
        precondition(!model.busy && model.result?.tiffRepresentation == segmentation)
        print("PASS: both completed modes switch immediately with distinct outputs and preserved crop")

        model.open(source)
        try await wait(until: { model.status == "Removing background…" || model.error != nil })
        model.cancel()
        precondition(!model.busy && model.status == "Cancelled")
        precondition(model.result == nil, "New image must not restore a previous image’s cache")
        // Allow the previous process to terminate before starting another model.
        try await Task.sleep(for: .seconds(3))
        model.retry()
        try await wait(until: { !model.busy })
        precondition(model.error == nil, model.error ?? "")
        precondition(model.result != nil, "Retry after cancellation failed")
        print("PASS: cancellation and fresh-worker retry")

        let badFile = FileManager.default.temporaryDirectory.appendingPathComponent("Cutout-bad-\(UUID()).png")
        try Data("not an image".utf8).write(to: badFile)
        defer { try? FileManager.default.removeItem(at: badFile) }
        model.open(badFile)
        try await wait(until: { !model.busy })
        precondition(model.error != nil, "Bad image should show an error")
        precondition(model.result != nil, "Invalid import discarded the previous cutout")
        print("PASS: invalid image reports an error and retains the previous result")
    }
}
