import SwiftUI

/// The signed-in user's own weekly schedule.
struct ScheduleView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        WeeklyTimetable(title: "Расписание") { start, end in
            try await APIClient(auth: auth).schedule(from: start, to: end)
        }
    }
}
