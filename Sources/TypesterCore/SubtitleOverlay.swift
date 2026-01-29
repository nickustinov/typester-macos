import Cocoa
import SwiftUI

class SubtitleViewModel: ObservableObject {
    @Published var finalText: String = ""
    @Published var interimText: String = ""
    @Published var isActive: Bool = false
    @Published var targetAppName: String = ""
    @Published var targetAppIcon: NSImage?

    var displayText: String {
        if !finalText.isEmpty && !interimText.isEmpty
            && !finalText.hasSuffix(" ") && !interimText.hasPrefix(" ") {
            return finalText + " " + interimText
        }
        return finalText + interimText
    }

    func show(appName: String, appIcon: NSImage?) {
        finalText = ""
        interimText = ""
        targetAppName = appName
        targetAppIcon = appIcon
        isActive = true
    }

    func hide() {
        isActive = false
        finalText = ""
        interimText = ""
        targetAppName = ""
        targetAppIcon = nil
    }

    func updateFinal(_ text: String) {
        finalText += text
        interimText = ""
    }

    func updateInterim(_ text: String) {
        interimText = text
    }

    func clearText() {
        finalText = ""
        interimText = ""
    }
}

struct WaveformIcon: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 2, height: isAnimating ? barHeight(for: index) : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 16)
        .shadow(color: .white.opacity(0.4), radius: 4)
        .onAppear { isAnimating = true }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [8, 14, 10, 16, 6]
        return heights[index]
    }
}

struct SubtitleView: View {
    @ObservedObject var viewModel: SubtitleViewModel
    var maxCapsuleWidth: CGFloat = 600

    var body: some View {
        HStack(spacing: 8) {
            if let icon = viewModel.targetAppIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            }

            if viewModel.displayText.isEmpty {
                if !viewModel.targetAppName.isEmpty {
                    Text(viewModel.targetAppName)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                WaveformIcon()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(viewModel.displayText)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .fixedSize()
                            .id("text")
                    }
                    .frame(maxWidth: maxCapsuleWidth - 60)
                    .onChange(of: viewModel.displayText) { _ in
                        proxy.scrollTo("text", anchor: .trailing)
                    }
                    .onAppear {
                        proxy.scrollTo("text", anchor: .trailing)
                    }
                }
            }
        }
        .frame(minHeight: 20)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
        )
        .fixedSize()
    }
}

class SubtitleOverlay {
    static let shared = SubtitleOverlay()

    let viewModel = SubtitleViewModel()
    private var window: NSWindow?

    private init() {}

    func show(appName: String, appIcon: NSImage?) {
        DispatchQueue.main.async {
            self.viewModel.show(appName: appName, appIcon: appIcon)
            self.ensureWindow()
            self.repositionWindow()
            self.window?.orderFront(nil)
        }
    }

    func hide() {
        DispatchQueue.main.async {
            self.viewModel.hide()
            self.window?.orderOut(nil)
        }
    }

    func updateFinal(_ text: String) {
        DispatchQueue.main.async {
            self.viewModel.updateFinal(text)
            self.repositionWindow()
        }
    }

    func updateInterim(_ text: String) {
        DispatchQueue.main.async {
            self.viewModel.updateInterim(text)
            self.repositionWindow()
        }
    }

    func clearText() {
        DispatchQueue.main.async {
            self.viewModel.clearText()
            self.repositionWindow()
        }
    }

    private func ensureWindow() {
        guard window == nil else { return }

        let maxWidth = maxCapsuleWidth()
        let hosting = NSHostingView(
            rootView: SubtitleView(viewModel: viewModel, maxCapsuleWidth: maxWidth)
        )

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = true
        window.contentView = hosting

        self.window = window
    }

    private func maxCapsuleWidth() -> CGFloat {
        let screenWidth = NSScreen.main?.frame.width ?? 1440
        return screenWidth * 0.4
    }

    private func repositionWindow() {
        guard let window = window,
              let screen = NSScreen.main,
              let hosting = window.contentView as? NSHostingView<SubtitleView> else { return }

        let maxWidth = maxCapsuleWidth()
        hosting.rootView = SubtitleView(viewModel: viewModel, maxCapsuleWidth: maxWidth)
        hosting.layoutSubtreeIfNeeded()

        let fittingSize = hosting.fittingSize
        guard fittingSize.width > 0 && fittingSize.height > 0 else { return }

        // Clamp width to max
        let width = min(fittingSize.width, maxWidth)
        let height = fittingSize.height

        let x = screen.frame.midX - width / 2
        let y = screen.frame.minY + 80
        let newFrame = NSRect(origin: NSPoint(x: x, y: y), size: NSSize(width: width, height: height))

        Debug.log("Overlay reposition: x=\(Int(x)) y=\(Int(y)) w=\(Int(width)) h=\(Int(height))")

        window.setFrame(newFrame, display: true)
    }
}
