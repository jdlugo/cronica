import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

#if DEBUG
/// Screenshot wrapper showing Trailers, Cast, Overview, and Recommendations
/// from the detail page, with a cinematic backdrop overlay.
struct DetailRecommendationsScreenshotView: View {
    @State private var viewModel: ItemContentViewModel
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let item: ItemContent
    private let recommendations = Array(ItemContent.examples.dropFirst(10).prefix(8))

    init(item: ItemContent = .example) {
        self.item = item
        _viewModel = State(wrappedValue: ItemContentViewModel.preview(with: item, includeMockTrailers: true))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                TrailerListView(trailers: viewModel.trailers)

                CastListView(credits: item.credits?.cast ?? [])

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
#endif
