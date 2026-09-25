import SwiftUI
import UniformTypeIdentifiers

private let ink = Color(nsColor: .labelColor)
private let surface = Color(nsColor: .controlBackgroundColor)

private struct CutoutButtonStyle: ButtonStyle {
    var primary = false
    var raised = false
    var height: CGFloat = 36
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .frame(height: height)
            .foregroundStyle(primary ? Color.white : ink)
            .background(primary ? Color.black : (raised ? surface : Color.clear), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(raised ? 0.12 : 0), lineWidth: 1))
            .opacity(!enabled ? 0.4 : configuration.isPressed ? 0.65 : 1)
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            previewBackdrop.ignoresSafeArea()
            if model.original == nil { emptyState }
            else { preview }
        }
        .toolbar {
            if #available(macOS 26.0, *) {
                openItem.sharedBackgroundVisibility(.hidden)
            } else {
                openItem
            }
            ToolbarItem(placement: .automatic) { Spacer() }
            if #available(macOS 26.0, *) {
                titlebarItem.sharedBackgroundVisibility(.hidden)
            } else {
                titlebarItem
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .tint(ink)
        .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: $model.targeted, perform: model.acceptDrop)
        .overlay {
            if model.targeted && !model.busy {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(ink.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 5]))
                    .padding(8).allowsHitTesting(false)
            }
        }
        .alert("Couldn’t finish", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) {
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var openItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if model.original != nil {
                Button("Open New Image", action: model.chooseImage)
                    .buttonStyle(CutoutButtonStyle(primary: true, height: 30))
                    .disabled(model.busy || model.cropping)
                    .help("Open new image (⌘O)")
            }
        }
    }

    private var titlebarItem: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            titlebarControls
                .padding(.trailing, 11)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Text(model.busy ? "Preparing your image…" : "Drop an image here")
                .font(.system(size: 23, weight: .medium))
            Button("Open Image…", action: model.chooseImage)
                .buttonStyle(CutoutButtonStyle(primary: true))
                .disabled(model.busy)
            Text("or paste with ⌘V").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var preview: some View {
        ZStack {
            if let image = model.showOriginal ? model.original : (model.result ?? model.original) {
                CropCanvas(image: image, editing: model.cropping,
                           crop: model.cropping ? model.draftCrop : model.crop) {
                    model.draftCrop = $0
                }
                .modifier(ProcessingPulse(active: model.busy))
                .padding(.top, 12).padding(.bottom, 104)
            }
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Text(model.outputDimensions)
                        .font(.system(size: 11)).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Image dimensions: " + model.outputDimensions)
                    dock
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var titlebarControls: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(RemovalMode.allCases, id: \.self) { mode in
                    Button { model.selectMode(mode) } label: {
                        Text(mode.title)
                            .font(.system(size: 13))
                            .frame(width: 102, height: 24)
                            .background(
                                model.removalMode == mode ? ink.opacity(0.10) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.removalMode == mode ? .isSelected : [])
                    .help(mode == .segmentation
                          ? "Solid clothing and shoes"
                          : "Soft edges and transparency")
                }
            }
            .padding(3)
            .background(surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(0.12)))
            .disabled(model.busy || model.cropping)
            .opacity(model.busy || model.cropping ? 0.4 : 1)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Background removal mode")
        }
    }

    private var previewSelector: some View {
        HStack(spacing: 2) {
            ForEach([true, false], id: \.self) { original in
                Button { model.showOriginal = original } label: {
                    Text(original ? "Original" : "Cutout")
                        .font(.system(size: 13))
                        .frame(width: 68, height: 30)
                        .background(
                            model.showOriginal == original ? ink.opacity(0.10) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.showOriginal == original ? .isSelected : [])
            }
        }
        .padding(3)
        .background(surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ink.opacity(0.12)))
        .disabled(model.cropping)
        .opacity(model.cropping ? 0.4 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Image preview")
    }

    private var dock: some View {
        HStack(spacing: 3) {
            if model.busy {
                ProgressView().controlSize(.small).padding(.leading, 10).padding(.trailing, 7)
                Text(model.status.isEmpty ? "Preparing image…" : model.status)
                    .font(.system(size: 13)).lineLimit(1)
                    .padding(.trailing, 8)
                    .accessibilityLabel(model.status)
                Divider().frame(height: 23).padding(.horizontal, 5)
                Button("Cancel", action: model.cancel).buttonStyle(CutoutButtonStyle())
            } else if model.result != nil {
                previewSelector
                backgrounds
                Divider().frame(height: 23).padding(.horizontal, 5)
                if model.cropping {
                    Button("Reset") { model.draftCrop = CropGeometry.full }
                        .buttonStyle(CutoutButtonStyle())
                    Button("Cancel") { model.cropping = false }
                        .buttonStyle(CutoutButtonStyle())
                    Button("Done", action: model.applyCrop)
                        .buttonStyle(CutoutButtonStyle(primary: true))
                } else {
                    if model.crop != CropGeometry.full {
                        Button(action: model.resetCrop) { Image(systemName: "arrow.uturn.backward") }
                            .buttonStyle(CutoutButtonStyle())
                            .help("Reset crop").accessibilityLabel("Reset crop")
                    }
                    Button(action: {
                        model.showOriginal = false
                        model.beginCrop()
                    }) { Label("Crop", systemImage: "crop") }
                        .buttonStyle(CutoutButtonStyle())
                    Button(action: model.copyResult) {
                        Label(model.copied ? "Copied" : "Copy", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                    }.buttonStyle(CutoutButtonStyle())
                    Button(action: model.save) { Label("Save PNG…", systemImage: "arrow.down.to.line") }
                        .buttonStyle(CutoutButtonStyle(primary: true))
                }
            } else {
                Text(model.status.isEmpty ? "Try again or open another image" : model.status)
                    .font(.system(size: 12)).padding(.leading, 8)
                Button("Try Again", action: model.retry).buttonStyle(CutoutButtonStyle(primary: true))
            }
        }
        .padding(7)
        .background(surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ink.opacity(0.12)))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
    }

    private var backgrounds: some View {
        HStack(spacing: 3) {
            ForEach(PreviewBackground.allCases, id: \.self) { option in
                Button { model.background = option } label: {
                    ZStack {
                        if option == .paper { GraphPaper(cell: 6) }
                        else { option == .dark ? Color(white: 0.16) : Color.white }
                    }
                    .frame(width: 17, height: 17).clipShape(Circle())
                    .overlay(Circle().strokeBorder(ink.opacity(0.18)))
                    .padding(4)
                    .overlay(Circle().strokeBorder(model.background == option ? ink : .clear, lineWidth: 2))
                    .frame(width: 32, height: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(option.rawValue + " preview background")
                .accessibilityLabel(option.rawValue + " preview background")
                .accessibilityAddTraits(model.background == option ? .isSelected : [])
            }
        }
    }

    @ViewBuilder private var previewBackdrop: some View {
        switch model.background {
        case .light: Color.white
        case .dark: Color(white: 0.14)
        case .paper: GraphPaper()
        }
    }
}

struct GraphPaper: View {
    var cell: CGFloat = 28
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            let dark = colorScheme == .dark
            let paper = dark ? Color(red: 0.13, green: 0.14, blue: 0.14)
                             : Color(red: 0.97, green: 0.965, blue: 0.95)
            let line = dark ? Color.white.opacity(0.055) : Color(red: 0.38, green: 0.43, blue: 0.41).opacity(0.10)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper))
            var grid = Path()
            for column in 0...Int(ceil(size.width / cell)) {
                let x = CGFloat(column) * cell
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in 0...Int(ceil(size.height / cell)) {
                let y = CGFloat(row) * cell
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(line), lineWidth: 0.5)
        }.accessibilityHidden(true)
    }
}

private struct ProcessingPulse: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * (.pi / 2)
            content.opacity(active ? (reduceMotion ? 0.70 : 0.70 + 0.04 * cos(phase)) : 1)
        }
    }
}
