import SwiftUI
import AppKit

enum Theme {
    /// HSE blue.
    static let accent = Color(red: 0.03, green: 0.24, blue: 0.69)

    static func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

/// Tappable text that copies its value to the clipboard and briefly shows "Скопировано".
struct CopyableText: View {
    let text: String
    var icon: String = "doc.on.doc"
    @State private var copied = false

    var body: some View {
        Button {
            Theme.copyToClipboard(text)
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation { copied = false }
            }
        } label: {
            HStack(spacing: 6) {
                Text(copied ? "Скопировано" : text)
                    .foregroundStyle(copied ? .green : .secondary)
                Image(systemName: copied ? "checkmark" : icon)
                    .font(.caption2)
                    .foregroundStyle(copied ? .green : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Нажмите, чтобы скопировать")
    }
}

/// Soft tinted gradient used behind every screen so Liquid Glass has something to refract.
struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Theme.accent.opacity(0.22),
                Color(nsColor: .windowBackgroundColor),
                Theme.accent.opacity(0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// A Liquid Glass card.
    func glassCard(cornerRadius: CGFloat = 18, interactive: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, interactive: interactive))
    }

    /// Standard screen scaffold: tinted background + hidden scroll background.
    func screenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppBackground())
    }
}

private struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        content
            .padding(14)
            .glassEffect(
                interactive ? .regular.interactive() : .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

/// A rounded pill used for section headers.
struct Pill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(Theme.accent.opacity(0.25)), in: .capsule)
    }
}
