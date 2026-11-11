import SwiftUI

struct DeadlinesView: View {
    @EnvironmentObject var auth: AuthService
    @State private var state: LoadState<[Deadline]> = .idle

    var body: some View {
        Loader(state: state, retry: load) { items in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { d in
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(d.title).font(.body.weight(.semibold))
                                if let due = d.expiresAt {
                                    Label(dueText(due), systemImage: "clock")
                                        .font(.caption)
                                        .foregroundStyle(due < Date() ? .red : .secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .glassCard()
                    }
                    if items.isEmpty {
                        ContentUnavailableView("Дедлайнов нет", systemImage: "checkmark.circle",
                                               description: Text("Активных задач нет"))
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(20)
            }
            .screenBackground()
        }
        .navigationTitle("Дедлайны")
        .task { await loadAsync() }
    }

    private func load() { Task { await loadAsync() } }

    private func loadAsync() async {
        state = .loading
        do {
            let resp = try await APIClient(auth: auth).deadlines(completed: false)
            state = .loaded(resp.items.sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) })
        } catch { state = .failed(error.localizedDescription) }
    }

    private func dueText(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMMM yyyy, HH:mm"; f.locale = Locale(identifier: "ru_RU")
        f.timeZone = TimeZone(identifier: "Europe/Moscow")
        return "до " + f.string(from: date)
    }
}
