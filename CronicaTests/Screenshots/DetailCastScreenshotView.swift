import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper showing the About section and Cast & Crew row
/// from the detail page. Uses ItemContent.example which has full cast data.
struct DetailCastScreenshotView: View {
    private let item = ItemContent.example

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
            }
            .navigationTitle(item.itemTitle)
        }
    }
}
