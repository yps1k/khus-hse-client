import SwiftUI

struct HistoryEntry: Codable, Hashable, Identifiable {
    let query: String
    let kind: String          // SearchView.SearchKind.rawValue
    var id: String { kind + "|" + query }
}

/// Recent searches, persisted in UserDefaults.
@MainActor
final class SearchHistory: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    private let key = "search.history.v1"
    private let limit = 12

    init() { load() }

    func add(query: String, kind: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let entry = HistoryEntry(query: trimmed, kind: kind)
        entries.removeAll { $0 == entry }
        entries.insert(entry, at: 0)
        if entries.count > limit { entries = Array(entries.prefix(limit)) }
        save()
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0 == entry }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let value = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = value
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
