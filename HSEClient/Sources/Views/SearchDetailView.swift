import SwiftUI

/// Detail page for a search result: a person's profile, or a group/room card.
struct SearchDetailView: View {
    let result: SearchResult

    private var isPerson: Bool { result.type != "GROUP" && result.type != "AUDITORIUM" }
    private var isRoom: Bool { result.type == "AUDITORIUM" }

    var body: some View {
        if isPerson {
            PersonProfileView(ref: PersonRef(email: result.email ?? "", name: result.title))
        } else {
            entity
        }
    }

    private var entity: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Image(systemName: isRoom ? "door.left.hand.open" : "person.3.fill")
                        .font(.system(size: 44)).foregroundStyle(Theme.accent)
                        .padding(22).glassEffect(.regular, in: .circle)
                    Text(result.title).font(.title2.bold()).multilineTextAlignment(.center)
                    Pill(text: isRoom ? "Аудитория" : "Группа")
                }
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: 24)

                Card(title: "Информация") {
                    if isRoom {
                        DetailRow("Аудитория", result.room ?? result.title)
                        DetailRow("Тип", result.auditoriumType)
                        DetailRow("Корпус", result.description)
                    } else {
                        DetailRow("Группа", result.label ?? result.title)
                        DetailRow("Описание", result.description)
                    }
                }

                NavigationLink(value: TimetableTarget(result: result)) {
                    Label(isRoom ? "Занятость аудитории" : "Расписание", systemImage: "calendar")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent).tint(Theme.accent).controlSize(.large)
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: 580)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .navigationTitle(result.title)
    }
}
