import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper showing Overview, Cast & Crew, Recommendations, and
/// Similar sections from the detail page, with a cinematic backdrop overlay.
struct DetailCastScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let item = ItemContent.example
    // Non-overlapping slices so Recommendations and Similar show unique posters.
    private let recommendations = Array(ItemContent.examples.dropFirst(10).prefix(8))
    private let similar = Array(ItemContent.examples.dropFirst(18).prefix(8))

    var body: some View {
        NavigationStack {
            ScrollView {
                OverviewBoxView(
                    overview: item.itemOverview,
                    title: item.itemTitle,
                    type: .movie
                )
                .padding(.horizontal)

                CastListView(credits: item.credits?.cast ?? [])

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("Recommendations", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )

                HorizontalItemContentListView(
                    items: similar,
                    title: NSLocalizedString("Similar", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle(item.itemTitle)
            .toolbar(.hidden, for: .navigationBar)
            .background {
                ZStack {
                    WebImage(url: item.cardImageLarge) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle().fill(.background)
                    }
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                }
            }
        }
    }
}
