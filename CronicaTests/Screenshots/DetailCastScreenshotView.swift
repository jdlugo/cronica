import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper showing Overview, Cast & Crew, Recommendations, and
/// Similar sections from the detail page, with a cinematic backdrop overlay.
struct DetailCastScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let item: ItemContent
    private let recommendations: [ItemContent]
    private let similar: [ItemContent]

    init(
        item: ItemContent = .example,
        recommendations: [ItemContent] = Array(ItemContent.examples.dropFirst(10).prefix(8)),
        similar: [ItemContent] = Array(ItemContent.examples.dropFirst(18).prefix(8))
    ) {
        self.item = item
        self.recommendations = recommendations
        self.similar = similar
    }

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
