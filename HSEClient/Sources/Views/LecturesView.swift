import SwiftUI

/// Lecture notes from the "Маруся Конспектовна" channel, bundled as PDFs and
/// opened in an in-app PDF preview.
struct LecturesView: View {
    @State private var selected: Lecture?

    private let order = ["Алгебра", "Матанализ", "Дискретная математика"]

    private var groups: [(subject: String, items: [Lecture])] {
        Dictionary(grouping: lectures, by: { $0.subject })
            .sorted { (order.firstIndex(of: $0.key) ?? 9) < (order.firstIndex(of: $1.key) ?? 9) }
            .map { ($0.key, $0.value.sorted { $0.number < $1.number }) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ChannelHeader(name: "Маруся Конспектовна",
                              subtitle: "Конспекты ФКН ПИ 26",
                              url: "https://t.me/marusya_pishet_konspecty")

                ForEach(groups, id: \.subject) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Pill(text: group.subject)
                        ForEach(group.items) { lec in
                            Button { selected = lec } label: { LectureRow(lecture: lec) }
                                .buttonStyle(.plain)
                                .glassCard()
                        }
                    }
                }
                Text("By Mariya Savonik")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .screenBackground()
        .navigationTitle("Конспекты лекций")
        .sheet(item: $selected) { LecturePreview(lecture: $0) }
    }
}

private struct LectureRow: View {
    let lecture: Lecture
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.title3).foregroundStyle(Theme.accent).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("Лекция №\(lecture.number)").font(.body.weight(.semibold))
                if !lecture.topic.isEmpty {
                    Text(lecture.topic).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if !lecture.date.isEmpty {
                Text(lecture.date).font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
