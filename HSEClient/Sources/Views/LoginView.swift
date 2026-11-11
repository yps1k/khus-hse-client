import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var busy = false

    var body: some View {
        ZStack {
            AppBackground()
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 22) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.accent)
                        .padding(22)
                        .glassEffect(.regular, in: .circle)

                    VStack(spacing: 6) {
                        Text("Khus HSE Client").font(.largeTitle.bold())
                        Text("Неофициальный клиент HSE App X")
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        busy = true
                        Task { await auth.login(); busy = false }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().controlSize(.small) }
                            Text("Войти через ВШЭ")
                        }
                        .font(.headline)
                        .frame(minWidth: 220)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.accent)
                    .controlSize(.large)
                    .disabled(busy)

                    if let err = auth.lastError {
                        Text(err).foregroundStyle(.red).font(.callout)
                    }
                }
                .padding(40)
                .glassCard(cornerRadius: 28)
            }
            .frame(maxWidth: 420)
        }
    }
}
