import Foundation
import SwiftUI
import UserNotifications

struct Vedomost: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var subject: String
    var url: String
}

/// Ведомости list, persisted in UserDefaults. Also keeps the last seen hash of the
/// user's row per ведомость, to detect updates.
@MainActor
final class VedomostiStore: ObservableObject {
    @Published private(set) var items: [Vedomost] = []
    private let key = "vedomosti.v1"
    private let hashKey = "vedomosti.hashes.v1"

    init() { load() }

    func add(subject: String, url: String) {
        let s = subject.trimmingCharacters(in: .whitespaces)
        let u = url.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !u.isEmpty else { return }
        items.append(Vedomost(subject: s, url: u))
        save()
    }

    func remove(_ item: Vedomost) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func lastHash(_ id: String) -> Int? {
        (UserDefaults.standard.dictionary(forKey: hashKey)?[id] as? Int)
    }
    func setHash(_ id: String, _ value: Int) {
        var dict = UserDefaults.standard.dictionary(forKey: hashKey) ?? [:]
        dict[id] = value
        UserDefaults.standard.set(dict, forKey: hashKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let v = try? JSONDecoder().decode([Vedomost].self, from: data) { items = v }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key) }
    }
}

enum SheetsError: LocalizedError {
    case badURL
    case noAccess
    var errorDescription: String? {
        switch self {
        case .badURL: return "Это не ссылка на Google Sheets"
        case .noAccess: return "Нет доступа к таблице. Откройте доступ «всем, у кого есть ссылка»"
        }
    }
}

/// Reads a public Google Sheet (one worksheet) as CSV and finds the user's row.
enum Sheets {
    static func spreadsheetID(from url: String) -> String? {
        firstGroup(in: url, pattern: #"/d/([a-zA-Z0-9\-_]+)"#)
    }
    static func gid(from url: String) -> String? {
        firstGroup(in: url, pattern: #"[#&?]gid=([0-9]+)"#)
    }

    /// Candidate CSV exports, most-specific first: the exact tab from the link's gid,
    /// the first VISIBLE sheet (gviz), then gid=0. We try them until the viewer is found.
    static func csvCandidates(from url: String) -> [URL] {
        guard let id = spreadsheetID(from: url) else { return [] }
        var urls: [URL] = []
        if let g = gid(from: url),
           let u = URL(string: "https://docs.google.com/spreadsheets/d/\(id)/export?format=csv&gid=\(g)") { urls.append(u) }
        if let u = URL(string: "https://docs.google.com/spreadsheets/d/\(id)/gviz/tq?tqx=out:csv") { urls.append(u) }
        if let u = URL(string: "https://docs.google.com/spreadsheets/d/\(id)/export?format=csv&gid=0") { urls.append(u) }
        return urls
    }

    private static func fetchCSV(_ u: URL) async throws -> [[String]] {
        var req = URLRequest(url: u)
        req.setValue("text/csv", forHTTPHeaderField: "Accept")
        let (data, resp) = try await Net.data(for: req)
        let text = String(decoding: data, as: UTF8.self)
        if (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.contains("text/html") == true
            || text.hasPrefix("<!DOCTYPE") || text.contains("<html") {
            throw SheetsError.noAccess
        }
        return parseCSV(text)
    }

    struct Match {
        let pairs: [(label: String, value: String)]
        let signature: String
    }

    /// Fetches the workbook across candidate sheets and returns the viewer's labelled grades.
    static func grades(url: String, fullName: String) async throws -> Match? {
        let candidates = csvCandidates(from: url)
        guard !candidates.isEmpty else { throw SheetsError.badURL }
        var lastError: Error?
        var sawData = false
        for u in candidates {
            do {
                let rows = try await fetchCSV(u)
                sawData = true
                if let m = match(rows, fullName: fullName) { return m }
            } catch { lastError = error }
        }
        if !sawData, let e = lastError { throw e }
        return nil   // sheets readable, but the viewer's row wasn't on any tried tab
    }

    private static func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "ё", with: "е").trimmingCharacters(in: .whitespaces)
    }

    /// Finds the viewer's row by surname+name and labels their non-empty cells using the
    /// two-row header (group row + "№1/№2" row), handling merged group cells.
    static func match(_ rows: [[String]], fullName: String) -> Match? {
        let tokens = norm(fullName).split(separator: " ").map(String.init).filter { $0.count > 1 }
        guard tokens.count >= 2 else { return nil }
        let last = tokens[0], first = tokens[1]

        guard let idx = rows.firstIndex(where: { row in
            let joined = norm(row.joined(separator: " "))
            return joined.contains(last) && joined.contains(first)
        }) else { return nil }
        let userRow = rows[idx]

        // Header: the row whose first cell is "ФИО" is the sub-header; the row above is the group.
        let subIdx = rows.firstIndex { ($0.first.map(norm) ?? "") == "фио" } ?? max(idx - 1, 0)
        let groupIdx = subIdx > 0 ? subIdx - 1 : subIdx
        let labels = buildLabels(group: rows[groupIdx], sub: rows[subIdx], width: userRow.count)

        var pairs: [(String, String)] = []
        for j in 1..<userRow.count {
            let v = userRow[j].trimmingCharacters(in: .whitespaces)
            guard !v.isEmpty else { continue }
            let label = j < labels.count && !labels[j].isEmpty ? labels[j] : "Колонка \(j + 1)"
            pairs.append((label, v))
        }
        return Match(pairs: pairs, signature: userRow.joined(separator: "|"))
    }

    private static func buildLabels(group: [String], sub: [String], width: Int) -> [String] {
        // Forward-fill the group row across merged (empty) cells.
        var filled: [String] = []
        var lastGroup = ""
        for j in 0..<max(group.count, width) {
            let g = j < group.count ? group[j].trimmingCharacters(in: .whitespaces) : ""
            if !g.isEmpty { lastGroup = g }
            filled.append(lastGroup)
        }
        var labels: [String] = []
        var lastQuiz = ""
        for j in 0..<filled.count {
            var g = filled[j]
            if g.hasPrefix("Квиз") { lastQuiz = g }
            if norm(g) == "оценка" && !lastQuiz.isEmpty { g = "\(lastQuiz) · Оценка" }
            let s = j < sub.count ? sub[j].trimmingCharacters(in: .whitespaces) : ""
            labels.append([g, s].filter { !$0.isEmpty }.joined(separator: " "))
        }
        return labels
    }

    private static func firstGroup(in s: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
        return String(s[r])
    }

    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { field.append(c) }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": row.append(field); field = ""
                case "\n": row.append(field); rows.append(row); row = []; field = ""
                case "\r": break
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}

enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
