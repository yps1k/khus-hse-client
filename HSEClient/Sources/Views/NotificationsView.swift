import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var auth: AuthService
    @State private var state: LoadState<[Notice]> = .idle

    var body: some View {
        Loader(state: state, retry: load) { items in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { n in
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImage(url: n.image.flatMap(URL.init)) { img in
                                img.resizable().scaledToFit()
                            } placeholder: {
                                Image(systemName: "bell.fill").foregroundStyle(Theme.accent)
                            }
                            .frame(width: 32, height: 32)

                            VStack(alignment: .leading, spacing: 3) {
                                if let t = n.title { Text(t).font(.body.weight(.semibold)) }
                                if let c = n.content { Text(c).font(.callout).foregroundStyle(.secondary) }
                            }
                            Spacer(minLength: 0)
                        }
                        .glassCard()
                    }
                    if items.isEmpty {
                        ContentUnavailableView("Уведомлений нет", systemImage: "bell.slash")
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(20)
            }
            .screenBackground()
        }
        .navigationTitle("Уведомления")
        .task { await loadAsync() }
    }

    private func load() { Task { await loadAsync() } }

    private func loadAsync() async {
        state = .loading
        do { state = .loaded(try await APIClient(auth: auth).notifications().items) }
        catch { state = .failed(error.localizedDescription) }
    }
}
