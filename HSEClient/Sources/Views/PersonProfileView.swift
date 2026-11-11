import SwiftUI

/// Full profile ("account") of a person, loaded by email. Reused by search and by
/// tapping a teacher in the timetable.
struct PersonProfileView: View {
    @EnvironmentObject var auth: AuthService
    let ref: PersonRef
    var showSchedule: Bool = true
    @State private var profile: LoadState<PersonProfile> = .idle

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                details
                if showSchedule {
                    NavigationLink(value: TimetableTarget(personEmail: ref.email, title: ref.name)) {
                        Label("Расписание", systemImage: "calendar")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent).tint(Theme.accent).controlSize(.large)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: 580)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .navigationTitle(ref.name)
        .task {
            guard !ref.email.isEmpty else { return }
            profile = .loading
            do { profile = .loaded(try await APIClient(auth: auth).person(email: ref.email)) }
            catch { profile = .failed(error.localizedDescription) }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            AsyncImage(url: avatarURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
            }
            .frame(width: 92, height: 92).clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))

            Text(loadedName).font(.title2.bold()).multilineTextAlignment(.center)
            if let type = typeLabel { Pill(text: type) }
            if !ref.email.isEmpty { CopyableText(text: ref.email, icon: "envelope") }
        }
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder private var details: some View {
        switch profile {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
        case .failed(let msg):
            Text(msg).font(.callout).foregroundStyle(.secondary)
        case .loaded(let p):
            if !p.positions.isEmpty {
                Card(title: "Должности") {
                    ForEach(Array(p.positions.enumerated()), id: \.offset) { _, pos in
                        if let line = pos.line { Text(line).font(.callout) }
                    }
                }
            }
            let contacts = personalContacts(p)
            if !contacts.isEmpty {
                Card(title: "Контакты") {
                    ForEach(contacts, id: \.0) { item in
                        HStack {
                            Text(item.0).foregroundStyle(.secondary)
                            Spacer()
                            CopyableText(text: item.1, icon: "doc.on.doc")
                        }.font(.callout)
                    }
                }
            }
            if let edu = p.education.first {
                Card(title: "Обучение") {
                    DetailRow("Программа", edu.programTitle)
                    DetailRow("Факультет", edu.facultyTitle)
                    DetailRow("Год поступления", edu.admissionYear)
                }
            }
            if let campus = p.campus {
                Card(title: "Информация") { DetailRow("Кампус", campusLabel(campus)) }
            }
        }
    }

    private var avatarURL: URL? {
        if case .loaded(let p) = profile, let u = p.avatarUrl { return URL(string: u) }
        return nil
    }
    private var loadedName: String {
        if case .loaded(let p) = profile, let n = p.fullName { return n }
        return ref.name
    }
    private var typeLabel: String? {
        guard case .loaded(let p) = profile else { return nil }
        switch p.type {
        case "STAFF": return "Сотрудник"
        case "STUDENT": return "Студент"
        default: return nil
        }
    }

    private func personalContacts(_ p: PersonProfile) -> [(String, String)] {
        var out: [(String, String)] = []
        if let v = p.staffEmailPersonal, !v.isEmpty { out.append(("Доп. почта", v)) }
        if let v = p.staffPhoneMobile, !v.isEmpty { out.append(("Телефон", v)) }
        if let v = p.staffAddress, !v.isEmpty { out.append(("Адрес", v)) }
        return out
    }
    private func campusLabel(_ raw: String) -> String {
        switch raw {
        case "CAMPUS_MOS": return "Москва"
        case "CAMPUS_SPB": return "Санкт-Петербург"
        case "CAMPUS_NN", "CAMPUS_NNOV": return "Нижний Новгород"
        case "CAMPUS_PERM": return "Пермь"
        default: return raw
        }
    }
}

/// Shared little building blocks.
struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 20)
    }
}

struct DetailRow: View {
    let label: String
    let value: String?
    init(_ label: String, _ value: String?) { self.label = label; self.value = value }
    var body: some View {
        if let value, !value.isEmpty {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }.font(.callout)
        }
    }
}
