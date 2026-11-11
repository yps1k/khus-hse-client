import SwiftUI

/// Generic async-load state plus a view that renders loading / error / content.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

struct Loader<Value, Content: View>: View {
    let state: LoadState<Value>
    let retry: () -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppBackground())
        case .failed(let msg):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                Text(msg).foregroundStyle(.secondary)
                Button("Повторить", action: retry).buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
        case .loaded(let value):
            content(value)
        }
    }
}
