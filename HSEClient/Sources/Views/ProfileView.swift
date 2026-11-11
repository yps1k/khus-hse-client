import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @State private var state: LoadState<Profile> = .idle

    var body: some View {
        Loader(state: state, retry: load) { p in
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        AsyncImage(url: p.avatarUrl.flatMap(URL.init)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
                        }
                        .frame(width: 96, height: 96).clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))

                        Text(p.fullName).font(.title2.bold())
                        CopyableText(text: p.email, icon: "envelope")
                        if let d = p.description { Pill(text: d) }
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard(cornerRadius: 24)

                    if let edu = p.education?.first {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Обучение").font(.headline)
                            row("Программа", edu.programTitle)
                            row("Факультет", edu.facultyTitle)
                            row("Год поступления", edu.admissionYear)
                            row("Уровень", degree(edu.degreeLevel))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 24)
                    }
                    Spacer(minLength: 0)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .screenBackground()
        }
        .navigationTitle("Профиль")
        .task { await loadAsync() }
    }

    @ViewBuilder private func row(_ label: String, _ value: String?) -> some View {
        if let value {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }
            .font(.callout)
        }
    }

    private func degree(_ raw: String?) -> String? {
        switch raw {
        case "DEGREE_BACHELOR": return "Бакалавриат"
        case "DEGREE_MASTER": return "Магистратура"
        case "DEGREE_SPECIALIST": return "Специалитет"
        default: return raw
        }
    }

    private func load() { Task { await loadAsync() } }

    private func loadAsync() async {
        state = .loading
        do { state = .loaded(try await APIClient(auth: auth).profile()) }
        catch { state = .failed(error.localizedDescription) }
    }
}
