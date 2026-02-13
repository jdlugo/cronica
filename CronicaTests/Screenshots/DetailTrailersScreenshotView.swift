import SwiftUI
@testable import StreamingNow

#if DEBUG
/// Screenshot wrapper showing the Trailers section from the detail page.
/// Uses ItemContentViewModel.preview() which provides mock VideoItem data.
struct DetailTrailersScreenshotView: View {
    @State private var viewModel: ItemContentViewModel

    private let item: ItemContent

    init(item: ItemContent = .example) {
        self.item = item
        _viewModel = State(wrappedValue: ItemContentViewModel.preview(with: item, includeMockTrailers: true))
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

                TrailerListView(trailers: viewModel.trailers)
            }
            .navigationTitle(item.itemTitle)
        }
    }
}
#endif
