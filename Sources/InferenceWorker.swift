import Foundation

/// A child process communicating through pipes, never a network service.
@MainActor
final class InferenceWorker {
    var onEvent: (([String: Any]) -> Void)?
    var onExit: (() -> Void)?
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var pending = Data()
    private var generation = UUID()
    private let resourceRoot: URL?

    init(resourceRoot: URL? = Bundle.main.resourceURL) {
        self.resourceRoot = resourceRoot
    }

    func submit(id: UUID, source: URL, destination: URL, mode: RemovalMode = .segmentation) throws {
        if process?.isRunning != true { try start() }
        var data = try JSONSerialization.data(withJSONObject: [
            "id": id.uuidString, "input": source.path, "output": destination.path, "mode": mode.rawValue
        ])
        data.append(0x0A)
        try input?.write(contentsOf: data)
    }

    private func start() throws {
        guard let resources = resourceRoot else {
            throw CutoutError.message("The app’s runtime is missing. Please rebuild Cutout.")
        }
        let runtime = resources.appendingPathComponent("Runtime")
        let executable = runtime.appendingPathComponent("python/bin/python3")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw CutoutError.message("The bundled background remover is missing. Please rebuild Cutout.")
        }
        let child = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let current = UUID()
        generation = current
        pending.removeAll()
        child.executableURL = executable
        child.arguments = ["-u", "-B", "-s", runtime.appendingPathComponent("worker.py").path]
        child.currentDirectoryURL = runtime
        // No dependence on shell configuration, system Python, or user packages.
        child.environment = [
            "PATH": "/usr/bin:/bin", "HOME": NSHomeDirectory(),
            "TMPDIR": NSTemporaryDirectory(), "LANG": "en_US.UTF-8",
            "PYTHONNOUSERSITE": "1", "PYTHONDONTWRITEBYTECODE": "1",
            "HF_HUB_OFFLINE": "1", "TRANSFORMERS_OFFLINE": "1",
            "HF_HUB_DISABLE_TELEMETRY": "1", "DO_NOT_TRACK": "1",
            "PYTORCH_ENABLE_MPS_FALLBACK": "1", "TOKENIZERS_PARALLELISM": "false",
        ]
        child.standardInput = stdinPipe
        child.standardOutput = stdoutPipe
        let logFolder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("local.cutout.app")
        try FileManager.default.createDirectory(at: logFolder, withIntermediateDirectories: true)
        let logURL = logFolder.appendingPathComponent("runtime.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        child.standardError = try FileHandle(forWritingTo: logURL)
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.pending.append(data)
                while let end = self.pending.firstIndex(of: 0x0A) {
                    let line = self.pending[..<end]
                    self.pending.removeSubrange(...end)
                    if let event = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                        self.onEvent?(event)
                    }
                }
            }
        }
        child.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.output?.readabilityHandler = nil
                self.process = nil
                self.input = nil
                self.onExit?()
            }
        }
        try child.run()
        process = child
        input = stdinPipe.fileHandleForWriting
        output = stdoutPipe.fileHandleForReading
    }

    func stop() {
        generation = UUID()
        output?.readabilityHandler = nil
        try? input?.close()
        if let child = process, child.isRunning {
            child.terminate()
            // Python may defer SIGTERM during native inference. Bound cancellation.
            let pid = child.processIdentifier
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if child.isRunning { kill(pid, SIGKILL) }
            }
        }
        input = nil
        output = nil
        process = nil
        pending.removeAll()
    }
}

enum CutoutError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}
