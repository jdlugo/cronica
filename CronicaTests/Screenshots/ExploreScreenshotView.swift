import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper for the Explore screen. Uses a poster grid layout
/// with mock data, bypassing ExploreView's network pagination.
struct ExploreScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let items = ItemContent.examples

    private let columns = [GridItem(.adaptive(minimum: 160))]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(items) { item in
                        ItemContentPosterView(
                            item: item,
                            showPopup: $showPopup,
                            popupType: $popupType
                        )
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("Explore", comment: ""))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
