import SwiftUI

private struct DashboardHeight: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
struct PanelContents: View {
    @ObservedObject var model: MonitorModel
    let maximumHeight: CGFloat
    let resize: (CGFloat) -> Void
    @State private var contentHeight: CGFloat = 740
    var body: some View {
        ScrollView(.vertical) {
            DashboardView(model: model)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: DashboardHeight.self, value: geometry.size.height)
                })
        }
        .scrollIndicators(.hidden)
        .frame(width: 382, height: min(contentHeight, maximumHeight), alignment: .top)
        // One material covers the entire viewport, including any scroll overshoot.
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .onPreferenceChange(DashboardHeight.self) { height in
            guard height > 0, abs(height - contentHeight) > 0.5 else { return }
            contentHeight = height
            resize(min(height, maximumHeight))
        }
    }
}
