import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper showing Cast & Crew and Recommendations sections
/// from the detail page, stacked to fill the screen without navigation chrome.
struct DetailCastScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let item = ItemContent.example
    private let recommendations = Array(ItemContent.examples.prefix(8))

    var body: some View {
        NavigationStack {
            ScrollView {
                CastListView(credits: item.credits?.cast ?? [])

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("Recommendations", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle(item.itemTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
