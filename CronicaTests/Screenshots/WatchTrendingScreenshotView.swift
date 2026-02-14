import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper mimicking the watchOS Trending/Search screen.
/// Shows a list of trending items with thumbnails at watch dimensions.
struct WatchTrendingScreenshotView: View {
    private let items = Array(ItemContent.examples.suffix(5))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Trending")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    WatchRowView(item: item)
                    Divider()
                        .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color.black)
    }
}
