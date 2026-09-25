import AppKit
import SwiftUI

@main
struct CutoutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Cutout", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 620, minHeight: 380)
                .onAppear {
                    delegate.model = model
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    delegate.openPendingFiles()
                }
        }
        .defaultSize(width: 760, height: 540)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image…", action: model.chooseImage)
                    .keyboardShortcut("o").disabled(model.busy)
                Button("Save Cutout…", action: model.save)
                    .keyboardShortcut("s").disabled(model.result == nil || model.busy || model.cropping)
            }
            CommandGroup(replacing: .pasteboard) {
                Button("Cut") {
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.cut(nil)
                }.keyboardShortcut("x")
                Button("Copy Cutout", action: model.copyResult)
                    .keyboardShortcut("c")
                Button("Paste Image", action: model.paste)
                    .keyboardShortcut("v")
                Button("Select All") {
                    (NSApp.keyWindow?.firstResponder as? NSTextView)?.selectAll(nil)
                }.keyboardShortcut("a")
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private var pending: [URL] = []

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        if let model { model.open(first) } else { pending = [first] }
    }

    func openPendingFiles() {
        if let first = pending.first { model?.open(first); pending.removeAll() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}
