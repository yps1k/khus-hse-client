import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                ZStack {
                    AppBackground()
                    ProgressView().controlSize(.large)
                }
            case .signedIn:
                MainView()
            case .signedOut:
                LoginView()
            }
        }
        .tint(Theme.accent)
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case schedule = "Расписание"
    case search = "Поиск"
    case grades = "Оценки"
    case deadlines = "Дедлайны"
    case notifications = "Уведомления"
    case info = "Полезная информация"
    case lectures = "Конспекты лекций"
    case food = "Столовые"
    case profile = "Профиль"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .schedule: return "calendar"
        case .search: return "magnifyingglass"
        case .grades: return "list.number"
        case .deadlines: return "checklist"
        case .notifications: return "bell.badge"
        case .info: return "lightbulb"
        case .lectures: return "doc.text"
        case .food: return "fork.knife"
        case .profile: return "person.crop.circle"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var auth: AuthService
    @State private var selection: AppSection? = .schedule
    @State private var avatarURL: URL?

    private var menuSections: [AppSection] { AppSection.allCases.filter { $0 != .profile } }

    var body: some View {
        NavigationSplitView {
            List(menuSections, selection: $selection) { s in
                Label(s.rawValue, systemImage: s.icon)
                    .font(.body.weight(.medium))
                    .tag(s)
            }
            .navigationSplitViewColumnWidth(205)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .safeAreaInset(edge: .top) {
                Button { selection = .profile } label: {
                    AsyncImage(url: avatarURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Theme.accent, lineWidth: selection == .profile ? 3 : 2))
                }
                .buttonStyle(.plain)
                .help("Профиль")
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
            .task {
                if let p = try? await APIClient(auth: auth).profile(), let u = p.avatarUrl {
                    avatarURL = URL(string: u)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button(role: .destructive) { auth.logout() } label: {
                        Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    Text("Yan Khus · All Rights Reserved")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
            }
        } detail: {
            detail
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection ?? .schedule {
        case .schedule: ScheduleView()
        case .search: SearchView()
        case .grades: GradesView()
        case .deadlines: DeadlinesView()
        case .notifications: NotificationsView()
        case .info: UsefulInfoView()
        case .lectures: LecturesView()
        case .food: FoodView()
        case .profile: ProfileView()
        }
    }
}
