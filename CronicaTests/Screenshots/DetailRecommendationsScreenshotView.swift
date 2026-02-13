import SwiftUI
@testable import StreamingNow

#if DEBUG
/// Screenshot wrapper showing Trailers and Cast sections from the detail page,
/// stacked to fill the screen without navigation chrome.
struct DetailRecommendationsScreenshotView: View {
    @State private var viewModel: ItemContentViewModel

    private let item: ItemContent

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
            }
            .navigationTitle(item.itemTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
