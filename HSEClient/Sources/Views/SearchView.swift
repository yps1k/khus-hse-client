import SwiftUI

struct SearchView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var history = SearchHistory()
    @State private var query = ""
    @State private var kind: SearchKind = .people
    @State private var state: LoadState<[SearchResult]> = .idle

    enum SearchKind: String, CaseIterable, Identifiable {
        case people = "Люди", groups = "Группы", rooms = "Аудитории"
        var id: String { rawValue }
        var apiType: String? {
            switch self {
            case .people: return nil
            case .groups: return "GROUP"
            case .rooms: return "AUDITORIUM"
            }
        }
        var placeholder: String {
            switch self {
            case .people: return "ФИО студента, преподавателя или сотрудника"
            case .groups: return "Номер группы, например БПИ221"
            case .rooms: return "Номер аудитории, например R608"
            }
        }
        static func from(_ raw: String) -> SearchKind { SearchKind(rawValue: raw) ?? .people }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("", selection: $kind) {
                    ForEach(SearchKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: kind) { _, _ in if !query.isEmpty { run() } }

                if kind == .rooms {
                    RoomsFinderView()
                } else {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(kind.placeholder, text: $query)
                            .textFieldStyle(.plain)
                            .onSubmit(run)
                        if !query.isEmpty {
                            Button { query = ""; state = .idle } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .glassEffect(.regular, in: .capsule)

                    results
                }
            }
            .padding(20)
            .screenBackground()
            .navigationTitle("Поиск")
            .navigationDestination(for: SearchResult.self) { SearchDetailView(result: $0) }
            .navigationDestination(for: TimetableTarget.self) { target in
                WeeklyTimetable(title: target.title, roomMode: target.roomMode) { start, end in
                    try await APIClient(auth: auth).timetable(
                        from: start, to: end,
                        email: target.email, group: target.group, auditorium: target.auditorium)
                }
            }
        }
    }

    @ViewBuilder private var results: some View {
        switch state {
        case .idle:
            historyOrHint
        case .loading:
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                Text(msg).foregroundStyle(.secondary)
                Button("Повторить", action: run).buttonStyle(.glass)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let items):
            if items.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { ResultCard(result: $0) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var historyOrHint: some View {
        if history.entries.isEmpty {
            ContentUnavailableView("Поиск по ВШЭ", systemImage: "magnifyingglass",
                                   description: Text("Найдите студента, преподавателя, группу или аудиторию — посмотрите профиль, расписание и занятость"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Недавние").font(.headline)
                        Spacer()
                        Button("Очистить") { history.clear() }
                            .buttonStyle(.plain).font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(history.entries) { entry in
                        Button {
                            kind = .from(entry.kind)
                            query = entry.query
                            run()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                                Text(entry.query)
                                Spacer(minLength: 0)
                                Text(entry.kind).font(.caption).foregroundStyle(.secondary)
                                Button { history.remove(entry) } label: { Image(systemName: "xmark") }
                                    .buttonStyle(.plain).foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassCard(cornerRadius: 14)
                    }
                }
            }
        }
    }

    private func run() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        history.add(query: q, kind: kind.rawValue)
        state = .loading
        Task {
            do { state = .loaded(try await APIClient(auth: auth).search(q, type: kind.apiType)) }
            catch { state = .failed(error.localizedDescription) }
        }
    }
}

/// Maps a search result to the right timetable query. Hashable so it can drive navigation.
struct TimetableTarget: Hashable {
    let title: String
    let roomMode: Bool
    let email: String?
    let group: String?
    let auditorium: String?

    init(result r: SearchResult) {
        switch r.type {
        case "AUDITORIUM":
            title = "Аудитория \(r.room ?? r.title)"
            roomMode = true; email = nil; group = nil; auditorium = r.id
        case "GROUP":
            title = r.label ?? r.title
            roomMode = false; email = nil; group = r.id; auditorium = nil
        default:
            title = r.title
            roomMode = false; email = r.email; group = nil; auditorium = nil
        }
    }

    init(personEmail: String, title: String) {
        self.title = title; roomMode = false; email = personEmail; group = nil; auditorium = nil
    }
}

private struct ResultCard: View {
    let result: SearchResult

    var body: some View {
        NavigationLink(value: result) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title).font(.body.weight(.semibold))
                    if let sub = subtitle { Text(sub).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard()
    }

    private var icon: String {
        switch result.type {
        case "AUDITORIUM": return "door.left.hand.open"
        case "GROUP": return "person.3.fill"
        case "STAFF": return "briefcase.fill"
        default: return "graduationcap.fill"
        }
    }

    private var subtitle: String? {
        if result.type == "AUDITORIUM" {
            return [result.auditoriumType, result.description].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
        }
        return result.description
    }
}
