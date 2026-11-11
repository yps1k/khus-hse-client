import SwiftUI

struct GradesView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case vedomosti = "Ведомости"
        case final = "Итоговые оценки"
        var id: String { rawValue }
    }
    @State private var tab: Tab = .vedomosti

    var body: some View {
        VStack(spacing: 14) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case .vedomosti: VedomostiView()
            case .final: FinalGradesView()
            }
        }
        .padding(20)
        .screenBackground()
        .navigationTitle("Оценки")
    }
}
