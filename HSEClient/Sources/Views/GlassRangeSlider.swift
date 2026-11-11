import SwiftUI

/// Two-thumb range slider with Liquid Glass thumbs. Values are in `bounds` units (minutes).
struct GlassRangeSlider: View {
    let bounds: ClosedRange<Int>
    let step: Int
    @Binding var lower: Int
    @Binding var upper: Int

    private let thumb: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = max(width - thumb, 1)
            let span = CGFloat(bounds.upperBound - bounds.lowerBound)
            let lowerX = CGFloat(lower - bounds.lowerBound) / span * usable
            let upperX = CGFloat(upper - bounds.lowerBound) / span * usable

            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.25)).frame(height: 6)
                Capsule().fill(Theme.accent)
                    .frame(width: max(upperX - lowerX, 0) + thumb, height: 6)
                    .offset(x: lowerX)

                thumbView.offset(x: lowerX)
                    .gesture(drag(usable: usable, span: span, isLower: true))
                thumbView.offset(x: upperX)
                    .gesture(drag(usable: usable, span: span, isLower: false))
            }
            .frame(height: thumb)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 44)
    }

    private var thumbView: some View {
        Circle()
            .frame(width: thumb, height: thumb)
            .glassEffect(.regular.interactive(), in: .circle)
            .overlay(Circle().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1.5))
            .shadow(radius: 2, y: 1)
    }

    private func drag(usable: CGFloat, span: CGFloat, isLower: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let x = min(max(g.location.x - thumb / 2, 0), usable)
                let raw = bounds.lowerBound + Int((x / usable * span).rounded())
                let stepped = (raw / step) * step
                if isLower {
                    lower = min(max(stepped, bounds.lowerBound), upper - step)
                } else {
                    upper = max(min(stepped, bounds.upperBound), lower + step)
                }
            }
    }
}
