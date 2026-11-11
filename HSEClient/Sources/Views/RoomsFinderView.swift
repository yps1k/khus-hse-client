import SwiftUI

/// Pick a building and a time interval → list of free auditoriums in that building.
struct RoomsFinderView: View {
    @EnvironmentObject var auth: AuthService

    @State private var campuses: [Campus] = []
    @State private var building: Building?
    @State private var day = Date()
    @State private var lowerMin = 10 * 60      // 10:00
    @State private var upperMin = 13 * 60      // 13:00
    @State private var rooms: LoadState<[FreeRoom]> = .idle
    @State private var buildingsError: String?

    private let dayStart = 8 * 60
    private let dayEnd = 22 * 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                buildingPicker
                timeCard
                Button(action: find) {
                    Label("Показать свободные", systemImage: "door.left.hand.open")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent).tint(Theme.accent).controlSize(.large)
                .disabled(building == nil)

                resultsSection
            }
            .padding(4)
        }
        .task { await loadBuildings() }
    }

    // MARK: Building

    private var buildingPicker: some View {
        Card(title: "Корпус") {
            if let error = buildingsError {
                Text(error).font(.callout).foregroundStyle(.secondary)
            } else if campuses.isEmpty {
                ProgressView().controlSize(.small)
            } else {
                Menu {
                    ForEach(campuses.indices, id: \.self) { ci in
                        let c = campuses[ci]
                        Section(campusName(c.campus)) {
                            ForEach(c.buildings ?? []) { b in
                                Button(b.name ?? b.address ?? b.id) { building = b; rooms = .idle }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(building?.name ?? building?.address ?? "Выберите корпус")
                            .foregroundStyle(building == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    // MARK: Time

    private var timeCard: some View {
        Card(title: "Когда") {
            DatePicker("Дата", selection: $day, displayedComponents: .date)
                .datePickerStyle(.field)
            HStack {
                Text(timeLabel(lowerMin)).font(.title3.monospacedDigit().weight(.semibold))
                Text("—").foregroundStyle(.secondary)
                Text(timeLabel(upperMin)).font(.title3.monospacedDigit().weight(.semibold))
                Spacer()
            }
            .padding(.top, 4)
            GlassRangeSlider(bounds: dayStart...dayEnd, step: 5, lower: $lowerMin, upper: $upperMin)
        }
    }

    // MARK: Results

    @ViewBuilder private var resultsSection: some View {
        switch rooms {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView().controlSize(.large).frame(maxWidth: .infinity).padding(.top, 20)
        case .failed(let msg):
            Text(msg).font(.callout).foregroundStyle(.secondary).padding(.top, 8)
        case .loaded(let list):
            if list.isEmpty {
                ContentUnavailableView("Свободных нет", systemImage: "door.left.hand.closed",
                                       description: Text("В этот интервал свободных аудиторий не найдено"))
                    .frame(maxWidth: .infinity).padding(.top, 20)
            } else {
                Text("Свободно: \(list.count)").font(.headline).padding(.top, 4)
                LazyVStack(spacing: 10) {
                    ForEach(list) { room in
                        HStack(spacing: 12) {
                            Image(systemName: "door.left.hand.open").foregroundStyle(Theme.accent).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(room.fullName ?? room.id).font(.body.weight(.semibold))
                                let sub = [room.auditoriumType, room.auditoriumFloor.map { "\($0) этаж" }]
                                    .compactMap { $0 }.joined(separator: " · ")
                                if !sub.isEmpty { Text(sub).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer(minLength: 0)
                        }
                        .glassCard()
                    }
                }
            }
        }
    }

    // MARK: Logic

    private func loadBuildings() async {
        guard campuses.isEmpty else { return }
        do { campuses = try await APIClient(auth: auth).buildings() }
        catch { buildingsError = error.localizedDescription }
    }

    private func find() {
        guard let b = building else { return }
        let cal = Calendar.moscow
        let base = cal.startOfDay(for: day)
        let from = cal.date(byAdding: .minute, value: lowerMin, to: base)!
        let to = cal.date(byAdding: .minute, value: upperMin, to: base)!
        rooms = .loading
        Task {
            do { rooms = .loaded(try await APIClient(auth: auth).freeRooms(buildingId: b.id, from: from, to: to)) }
            catch { rooms = .failed(error.localizedDescription) }
        }
    }

    private func timeLabel(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
    private func campusName(_ raw: String?) -> String {
        switch raw {
        case "CAMPUS_MOS": return "Москва"
        case "CAMPUS_SPB": return "Санкт-Петербург"
        case "CAMPUS_NN", "CAMPUS_NNOV": return "Нижний Новгород"
        case "CAMPUS_PERM": return "Пермь"
        default: return raw ?? "Кампус"
        }
    }
}
