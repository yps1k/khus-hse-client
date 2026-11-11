import SwiftUI
import PDFKit

/// Embedded PDF view (PDFKit) for the lecture preview.
struct PDFKitView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: url)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url { view.document = PDFDocument(url: url) }
    }
}

/// Full-screen-ish sheet showing one lecture's PDF.
struct LecturePreview: View {
    let lecture: Lecture
    @Environment(\.dismiss) private var dismiss

    private var url: URL? {
        Bundle.main.url(forResource: (lecture.file as NSString).deletingPathExtension, withExtension: "pdf")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(lecture.subject) · Лекция №\(lecture.number)").font(.headline)
                    if !lecture.topic.isEmpty {
                        Text(lecture.topic).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                if let url {
                    Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "arrow.up.forward.app") }
                        .help("Открыть во внешнем просмотре")
                }
                Button("Закрыть") { dismiss() }
            }
            .padding(12)
            Divider()
            if let url {
                PDFKitView(url: url)
            } else {
                ContentUnavailableView("Файл не найден", systemImage: "doc.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 760)
    }
}
