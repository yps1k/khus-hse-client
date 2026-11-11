import SwiftUI

/// Official final grades from /v2/grades.
struct FinalGradesView: View {
    @EnvironmentObject var auth: AuthService
    @State private var state: LoadState<GradesResponse> = .idle

    var body: some View {
        Loader(state: state, retry: load) { resp in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let year = resp.selectedAcademicYear {
                        Pill(text: "Учебный год \(year)")
                    }
                    ForEach(resp.items) { g in
                        HStack(spacing: 12) {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(Theme.accent)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(g.discipline).font(.body.weight(.medium))
                                HStack(spacing: 8) {
                                    if let t = g.typeRaw { Text(t) }
                                    if let m = g.moduleName { Text("· \(m)") }
                                    if let c = g.credits { Text("· \(c) кр.") }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .glassCard()
                    }
                    if resp.items.isEmpty {
                        ContentUnavailableView("Оценок нет", systemImage: "list.number")
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .task { await loadAsync() }
    }

    private func load() { Task { await loadAsync() } }

    private func loadAsync() async {
        state = .loading
        do { state = .loaded(try await APIClient(auth: auth).grades()) }
        catch { state = .failed(error.localizedDescription) }
    }
}
