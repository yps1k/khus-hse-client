import SwiftUI

/// Reusable weekly timetable. `provider` returns lessons for a [start, end] range,
/// so the same view serves the user's own schedule, a person's, a group's or a room's.
struct WeeklyTimetable: View {
    let title: String
    var roomMode: Bool = false
    let provider: (_ start: Date, _ end: Date) async throws -> [Lesson]

    @State private var state: LoadState<[Lesson]> = .idle
    @State private var weekStart = WeeklyTimetable.startOfWeek(Date())
    @State private var teacher: PersonRef?

    var body: some View {
        Loader(state: state, retry: load) { lessons in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(grouped(lessons), id: \.0) { day, items in
                        VStack(alignment: .leading, spacing: 10) {
                            Pill(text: dayTitle(day))
                            ForEach(items) { lesson in
                                LessonRow(lesson: lesson) { ref in teacher = ref }
                                    .glassCard(cornerRadius: lesson.isNow ? 18 : 18)
                                    .overlay(alignment: .leading) {
                                        if lesson.isNow {
                                            RoundedRectangle(cornerRadius: 18)
                                                .strokeBorder(Theme.accent, lineWidth: 2)
                                        }
                                    }
                            }
                        }
                    }
                    if lessons.isEmpty {
                        ContentUnavailableView(
                            roomMode ? "Аудитория свободна всю неделю" : "Нет занятий",
                            systemImage: "calendar",
                            description: Text(roomMode ? "Занятых пар на этой неделе нет" : "На этой неделе пар нет"))
                            .frame(maxWidth: .infinity).padding(.top, 60)
                    } else if roomMode {
                        Text("Показаны занятые пары. Свободные интервалы — промежутки между ними.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .screenBackground()
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup {
                Button { shift(-7) } label: { Image(systemName: "chevron.left") }
                Text(weekLabel).font(.callout.monospacedDigit()).frame(width: 140)
                Button { shift(7) } label: { Image(systemName: "chevron.right") }
                Button { weekStart = Self.startOfWeek(Date()) } label: { Image(systemName: "arrow.uturn.backward") }
            }
        }
        .task(id: weekStart) { await loadAsync() }
        .sheet(item: $teacher) { ref in
            NavigationStack {
                PersonProfileView(ref: ref)
                    .navigationDestination(for: TimetableTarget.self) { t in
                        WeeklyTimetable(title: t.title, roomMode: t.roomMode) { s, e in
                            try await APIClient(auth: auth).timetable(from: s, to: e, email: t.email, group: t.group, auditorium: t.auditorium)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Закрыть") { teacher = nil }
                        }
                    }
            }
            .frame(minWidth: 520, minHeight: 600)
        }
    }

    @EnvironmentObject private var auth: AuthService

    private func shift(_ days: Int) {
        weekStart = Calendar.moscow.date(byAdding: .day, value: days, to: weekStart)!
    }

    private func load() { Task { await loadAsync() } }

    private func loadAsync() async {
        state = .loading
        do {
            let end = Calendar.moscow.date(byAdding: .day, value: 6, to: weekStart)!
            let lessons = try await provider(weekStart, end)
            state = .loaded(lessons.sorted { $0.dateStart < $1.dateStart })
        } catch { state = .failed(error.localizedDescription) }
    }

    private func grouped(_ lessons: [Lesson]) -> [(Date, [Lesson])] {
        Dictionary(grouping: lessons) { Calendar.moscow.startOfDay(for: $0.dateStart) }
            .sorted { $0.key < $1.key }
    }

    private var weekLabel: String {
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "ru_RU")
        let end = Calendar.moscow.date(byAdding: .day, value: 6, to: weekStart)!
        return "\(f.string(from: weekStart)) – \(f.string(from: end))"
    }

    private func dayTitle(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; f.locale = Locale(identifier: "ru_RU")
        return f.string(from: date).capitalized
    }

    static func startOfWeek(_ date: Date) -> Date {
        let cal = Calendar.moscow
        return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
    }
}

struct LessonRow: View {
    let lesson: Lesson
    var onTeacher: (PersonRef) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(time(lesson.dateStart)).bold()
                Text(time(lesson.dateEnd)).foregroundStyle(.secondary)
            }
            .font(.callout.monospacedDigit())
            .frame(width: 50)

            Capsule().fill(Theme.accent).frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(lesson.discipline ?? "—").font(.body.weight(.semibold))
                    if lesson.isNow {
                        Text("Сейчас")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Theme.accent, in: .capsule)
                            .foregroundStyle(.white)
                    }
                }
                if let type = lesson.type {
                    Text(type).font(.caption).foregroundStyle(.secondary)
                }
                if let lecturer = lesson.lecturer, !lecturer.isEmpty {
                    if let email = lesson.lecturerEmail, !email.isEmpty {
                        Button { onTeacher(PersonRef(email: email, name: lecturer)) } label: {
                            Label(lecturer, systemImage: "person.circle")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Label(lecturer, systemImage: "person.circle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    if let a = lesson.auditorium { Label(a, systemImage: "mappin.and.ellipse") }
                    if let b = lesson.building { Text("· \(b)") }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func time(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Moscow")
        return f.string(from: d)
    }
}

extension Calendar {
    static let moscow: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Moscow")!
        c.firstWeekday = 2
        return c
    }()
}
