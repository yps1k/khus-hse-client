import SwiftUI

struct VedomostiView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var store = VedomostiStore()
    @State private var fullName = ""
    @State private var results: [String: LoadState<[(String, String)]>] = [:]
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Ваши ведомости").font(.headline)
                    Spacer()
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                        .buttonStyle(.plain).foregroundStyle(Theme.accent)
                }

                if store.items.isEmpty {
                    ContentUnavailableView(
                        "Нет ведомостей", systemImage: "tablecells",
                        description: Text("Нажмите + и вставьте ссылку на Google Sheets с текущими оценками. Приложение найдёт вашу строку и пришлёт пуш при её обновлении."))
                        .frame(maxWidth: .infinity).padding(.top, 40)
                }

                ForEach(store.items) { item in
                    VedomostCard(item: item, state: results[item.id] ?? .idle,
                                 onDelete: { store.remove(item); results[item.id] = nil })
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showAdd) { addSheet }
        .task {
            Notifier.requestAuthorization()
            fullName = (try? await APIClient(auth: auth).profile().fullName) ?? ""
            await reloadAll(notify: false)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 90 * 1_000_000_000)
                await reloadAll(notify: true)
            }
        }
    }

    private var addSheet: some View {
        AddVedomostSheet { subject, url in
            store.add(subject: subject, url: url)
            showAdd = false
            Task { await reloadAll(notify: false) }
        } onCancel: { showAdd = false }
    }

    private func reloadAll(notify: Bool) async {
        for item in store.items {
            if results[item.id] == nil { results[item.id] = .loading }
            do {
                guard let m = try await Sheets.grades(url: item.url, fullName: fullName) else {
                    results[item.id] = .failed(fullName.isEmpty
                        ? "Профиль ещё не загрузился — обновите позже"
                        : "Строки «\(fullName)» не найдено ни на одной вкладке таблицы")
                    continue
                }
                results[item.id] = .loaded(m.pairs.map { ($0.label, $0.value) })

                let hash = stableHash(m.signature)
                if notify, let old = store.lastHash(item.id), old != hash {
                    Notifier.notify(title: "Обновление ведомости",
                                    body: "«\(item.subject)» — ваша строка изменилась")
                }
                store.setHash(item.id, hash)
            } catch {
                results[item.id] = .failed(error.localizedDescription)
            }
        }
    }

    private func stableHash(_ s: String) -> Int {
        var h = 5381
        for b in s.utf8 { h = (h &* 33) &+ Int(b) }
        return h
    }
}

private struct VedomostCard: View {
    let item: Vedomost
    let state: LoadState<[(String, String)]>
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tablecells.fill").foregroundStyle(Theme.accent)
                Text(item.subject).font(.body.weight(.semibold))
                Spacer()
                Link(destination: URL(string: item.url) ?? URL(string: "https://docs.google.com")!) {
                    Image(systemName: "arrow.up.right.square")
                }.buttonStyle(.plain).foregroundStyle(.secondary)
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            switch state {
            case .idle, .loading:
                ProgressView().controlSize(.small)
            case .failed(let msg):
                Text(msg).font(.caption).foregroundStyle(.secondary)
            case .loaded(let pairs):
                if pairs.isEmpty {
                    Text("Нет данных по вашей строке").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                        HStack {
                            Text(pair.0).foregroundStyle(.secondary)
                            Spacer()
                            Text(pair.1).fontWeight(.medium)
                        }.font(.caption)
                    }
                }
            }
        }
        .glassCard()
    }
}

private struct AddVedomostSheet: View {
    @State private var subject = ""
    @State private var url = ""
    let onAdd: (String, String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Новая ведомость").font(.title2.bold())
            VStack(alignment: .leading, spacing: 6) {
                Text("Предмет").font(.caption).foregroundStyle(.secondary)
                TextField("Например, Алгебра", text: $subject).textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Ссылка на Google Sheets").font(.caption).foregroundStyle(.secondary)
                TextField("https://docs.google.com/spreadsheets/…", text: $url).textFieldStyle(.roundedBorder)
                Text("Откройте доступ к таблице «всем, у кого есть ссылка». Для отдельной вкладки (ДЗ/КР/колок) вставьте ссылку именно на неё — у каждой свой gid.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Отмена", action: onCancel)
                Button("Добавить") { onAdd(subject, url) }
                    .buttonStyle(.borderedProminent)
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty || url.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
