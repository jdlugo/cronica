import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper showing the Recommendations section from the detail page.
/// Uses ItemContent.examples to populate a horizontal list of similar movies.
struct DetailRecommendationsScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let item = ItemContent.example
    private let recommendations = Array(ItemContent.examples.prefix(8))

    var body: some View {
        NavigationStack {
            ScrollView {
                OverviewBoxView(
                    overview: item.itemOverview,
                    title: item.itemTitle,
                    type: .movie
                )
                .padding(.horizontal)

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("Recommendations", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle(item.itemTitle)
        }
    }
}
