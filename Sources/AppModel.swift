import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var removalMode = RemovalMode.segmentation
    @Published var original: NSImage?
    @Published var result: NSImage?
    @Published var busy = false
    @Published var status = ""
    @Published var filename = ""
    private var exportFilename = "cutout.png"
    @Published var dimensions = ""
    @Published var error: String?
    @Published var showOriginal = false
    @Published var background = PreviewBackground.paper
    @Published var copied = false
    @Published var targeted = false
    @Published var cropping = false
    @Published var crop = CropGeometry.full
    @Published var draftCrop = CropGeometry.full
    private var pixelSize = CGSize.zero

    var outputDimensions: String {
        let rect = CropGeometry.pixels(cropping ? draftCrop : crop, size: pixelSize)
        return "\(Int(rect.width)) × \(Int(rect.height))"
    }

    func beginCrop() {
        guard !busy, result != nil else { return }
        draftCrop = crop
        cropping = true
    }

    func applyCrop() {
        crop = draftCrop
        cropping = false
        copied = false
    }

    func resetCrop() {
        crop = CropGeometry.full
        draftCrop = CropGeometry.full
        copied = false
    }
    private let worker: InferenceWorker
    private var panelOpen = false
    private var requestID: UUID?
    private var sourceURL: URL?
    private var resultURL: URL?
    private var completedResults: [RemovalMode: URL] = [:]
    private var lastCompletedMode: RemovalMode?
    private var activeFolder: URL?
    private var watchdog: Task<Void, Never>?
    private var copyFeedback: Task<Void, Never>?
    private let sessionFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent("Cutout-\(UUID().uuidString)")

    init(worker suppliedWorker: InferenceWorker? = nil) {
        let worker = suppliedWorker ?? InferenceWorker()
        self.worker = worker
        worker.onEvent = { [weak self] in self?.receive($0) }
        worker.onExit = { [weak self] in
            guard let self, self.busy else { return }
            self.fail("Background removal stopped unexpectedly. Try again, or close other memory-heavy apps first.")
        }
    }

    func chooseImage() {
        guard !busy, !panelOpen else { return }
        panelOpen = true
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an image to remove its background."
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            Task { @MainActor in
                self?.panelOpen = false
                guard response == .OK, let url = panel.url else { return }
                self?.open(url)
            }
        }
        if let window = NSApp.mainWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    func open(_ url: URL) {
        guard !busy else { NSSound.beep(); return }
        guard url.isFileURL else { error = "Choose a file saved on your Mac."; return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 250_000_000 else {
                throw CutoutError.message("This file is too large. Please use an image smaller than 250 MB.")
            }
            importImage(try Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent, hasFilename: true)
        } catch { self.error = error.localizedDescription }
    }

    func paste() {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.isEditable {
            editor.paste(nil)
            return
        }
        guard !busy else { return }
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = urls.first { open(first); return }
        if let png = pasteboard.data(forType: .png) { importImage(png, name: "Pasted image"); return }
        if let tiff = pasteboard.data(forType: .tiff) { importImage(tiff, name: "Pasted image"); return }
        error = "Copy an image or an image file, then paste it here."
    }

    func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !busy else { return false }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                Task { @MainActor in
                    if let url { self?.open(url) }
                    else { self?.error = "Couldn’t open the dropped file. Try Choose Image." }
                }
            }
            return true
        }
        if let provider = providers.first(where: { $0.canLoadObject(ofClass: NSImage.self) }) {
            _ = provider.loadObject(ofClass: NSImage.self) { [weak self] image, _ in
                let data = (image as? NSImage)?.tiffRepresentation
                Task { @MainActor in
                    if let data { self?.importImage(data, name: "Dropped image") }
                    else { self?.error = "Couldn’t read the dropped image. Try Choose Image." }
                }
            }
            return true
        }
        return false
    }

    private func importImage(_ data: Data, name: String, hasFilename: Bool = false) {
        guard !busy else { return }
        busy = true
        error = nil
        status = "Preparing image…"
        let id = UUID()
        requestID = id
        let folder = sessionFolder.appendingPathComponent(id.uuidString)
        let source = folder.appendingPathComponent("input.png")
        Task {
            do {
                let size = try await Task.detached(priority: .userInitiated) {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    return try ImageFiles.normalize(data, to: source)
                }.value
                guard requestID == id else { try? FileManager.default.removeItem(at: folder); return }
                if let activeFolder { try? FileManager.default.removeItem(at: activeFolder) }
                activeFolder = folder
                sourceURL = source
                resultURL = nil
                completedResults.removeAll()
                lastCompletedMode = nil
                original = NSImage(contentsOf: source)
                result = nil
                showOriginal = false
                copied = false
                cropping = false
                resetCrop()
                pixelSize = CGSize(width: size.0, height: size.1)
                filename = name
                exportFilename = hasFilename ? name + "_cutout.png" : "cutout.png"
                dimensions = "\(size.0) × \(size.1)"
                try run(id: id)
            } catch {
                guard requestID == id else { return }
                try? FileManager.default.removeItem(at: folder)
                fail(error.localizedDescription)
            }
        }
    }

    private func run(id: UUID) throws {
        guard let sourceURL, let activeFolder else { return }
        // A cancelled worker can finish writing late; never reuse its destination.
        let destination = activeFolder.appendingPathComponent("\(removalMode.rawValue)-\(id.uuidString).png")
        resultURL = destination
        busy = true
        status = "Starting background remover…"
        try worker.submit(id: id, source: sourceURL, destination: destination, mode: removalMode)
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(300))
            guard !Task.isCancelled, let self, self.requestID == id, self.busy else { return }
            self.worker.stop()
            self.fail("Background removal took too long. Close other memory-heavy apps and try again.")
        }
    }

    func selectMode(_ mode: RemovalMode) {
        guard !busy, !cropping, mode != removalMode else { return }
        removalMode = mode
        error = nil
        if restoreResult(for: mode) { return }
        result = nil
        resultURL = nil
        copied = false
        showOriginal = false
        if sourceURL != nil { retry() }
    }

    func retry() {
        guard !busy, sourceURL != nil else { return }
        error = nil
        if restoreResult(for: removalMode) { return }
        let id = UUID()
        requestID = id
        do { try run(id: id) } catch { fail(error.localizedDescription) }
    }

    @discardableResult
    private func restoreResult(for mode: RemovalMode) -> Bool {
        guard let url = completedResults[mode], let image = NSImage(contentsOf: url) else { return false }
        removalMode = mode
        resultURL = url
        result = image
        lastCompletedMode = mode
        showOriginal = false
        copied = false
        status = "Background removed"
        return true
    }

    private func receive(_ event: [String: Any]) {
        guard let id = event["id"] as? String, id == requestID?.uuidString, busy else { return }
        switch event["event"] as? String {
        case "status": status = event["message"] as? String ?? "Removing background…"
        case "complete":
            guard let resultURL, let image = NSImage(contentsOf: resultURL) else {
                fail("The finished image couldn’t be opened. Please try again."); return
            }
            completedResults[removalMode] = resultURL
            lastCompletedMode = removalMode
            result = image
            busy = false
            watchdog?.cancel()
            status = "Background removed"
        case "error":
            let detail = event["message"] as? String ?? "Unknown error"
            fail(detail.localizedCaseInsensitiveContains("memory")
                 ? "There wasn’t enough free memory. Close other memory-heavy apps and try again."
                 : "Couldn’t remove this background. \(detail)")
            worker.stop()
        default: break
        }
    }

    private func fail(_ message: String) {
        watchdog?.cancel()
        busy = false
        status = ""
        error = message
        if let lastCompletedMode { restoreResult(for: lastCompletedMode) }
    }

    func cancel() {
        requestID = nil
        watchdog?.cancel()
        worker.stop()
        busy = false
        status = "Cancelled"
        if let lastCompletedMode { restoreResult(for: lastCompletedMode) }
    }

    func clear() {
        cancel()
        original = nil
        result = nil
        sourceURL = nil
        resultURL = nil
        completedResults.removeAll()
        lastCompletedMode = nil
        filename = ""
        exportFilename = "cutout.png"
        cropping = false
        resetCrop()
        error = nil
        status = ""
        if let activeFolder { try? FileManager.default.removeItem(at: activeFolder) }
        activeFolder = nil
    }

    func save() {
        guard !busy, !cropping, !panelOpen, result != nil, let resultURL else { return }
        let export: Data
        do { export = try ImageFiles.exportPNG(from: resultURL, crop: crop) }
        catch { self.error = error.localizedDescription; return }
        panelOpen = true
        let panel = NSSavePanel()
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = exportFilename
        panel.canCreateDirectories = true
        let completion: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            Task { @MainActor in
                self?.panelOpen = false
                guard response == .OK, let destination = panel.url else { return }
                do { try export.write(to: destination, options: .atomic) }
                catch { self?.error = error.localizedDescription }
            }
        }
        if let window = NSApp.mainWindow { panel.beginSheetModal(for: window, completionHandler: completion) }
        else { panel.begin(completionHandler: completion) }
    }

    func copyResult() {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
            editor.copy(nil)
            return
        }
        guard !busy, !cropping, result != nil, let resultURL else { return }
        do {
            let data = try ImageFiles.exportPNG(from: resultURL, crop: crop)
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setData(data, forType: .png) else {
                throw CutoutError.message("Couldn’t copy this image to the clipboard.")
            }
            copied = true
            copyFeedback?.cancel()
            copyFeedback = Task {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled { copied = false }
            }
        } catch { self.error = error.localizedDescription }
    }

    func shutdown() {
        cancel()
        try? FileManager.default.removeItem(at: sessionFolder)
    }
}

enum PreviewBackground: String, CaseIterable {
    case paper = "Graph paper", light = "White", dark = "Dark"
}


enum RemovalMode: String, CaseIterable {
    case segmentation, matting
    var title: String { self == .segmentation ? "Segmentation" : "Matting" }
}
