import SwiftUI

struct FoodView: View {
    @EnvironmentObject var auth: AuthService
    @State private var state: LoadState<[Cafe]> = .idle

    var body: some View {
        Loader(state: state, retry: load) { cafes in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(cafes) { cafe in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.title2).foregroundStyle(Theme.accent)
                                Text(cafe.cafeName).font(.body.weight(.semibold))
                                Spacer(minLength: 0)
                                if isOpenNow(cafe) {
                                    Text("Открыто").font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Закрыто").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            if let today = todayHours(cafe) {
                                Text(today).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .glassCard()
                    }
                    if cafes.isEmpty {
                        ContentUnavailableView("Столовых нет", systemImage: "fork.knife")
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(20)
            }
            .screenBackground()
        }
        .navigationTitle("Столовые")
        .task { await loadAsync() }
    }

    private func load() { Task { await loadAsync() } }

    private func loadAsync() async {
        state = .loading
        do {
            let groups = try await APIClient(auth: auth).cafes()
            state = .loaded(groups.flatMap { $0.cafes })
        } catch { state = .failed(error.localizedDescription) }
    }

    private func weekdayKey() -> String {
        let idx = Calendar.moscow.component(.weekday, from: Date()) // 1=Sun
        return ["sunday","monday","tuesday","wednesday","thursday","friday","saturday"][idx - 1]
    }

    private func todayEntry(_ cafe: Cafe) -> OpeningHour? {
        cafe.openingHours?.first { $0.dayOfWeek == weekdayKey() }
    }

    private func todayHours(_ cafe: Cafe) -> String? {
        guard let e = todayEntry(cafe) else { return nil }
        guard e.isOpen, let s = e.startTime, let f = e.endTime else { return "Сегодня закрыто" }
        return "Сегодня \(s)–\(f)"
    }

    private func isOpenNow(_ cafe: Cafe) -> Bool {
        guard let e = todayEntry(cafe), e.isOpen, let s = e.startTime, let f = e.endTime else { return false }
        let now = DateFormatter.hm.string(from: Date())
        return s <= now && now <= f
    }
}

extension DateFormatter {
    static let hm: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Moscow"); f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
