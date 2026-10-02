import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper mimicking the watchOS Watchlist screen.
/// Shows a scrolling list of movies with thumbnails at watch dimensions.
struct WatchWatchlistScreenshotView: View {
    private let items = Array(ItemContent.examples.prefix(5))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Watchlist")
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

/// Reusable row for watch screenshot lists — 70x50 image + title + subtitle.
struct WatchRowView: View {
    let item: ItemContent

    var body: some View {
        HStack(spacing: 8) {
            WebImage(url: item.cardImageSmall) { image in
                image.resizable()
            } placeholder: {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "popcorn.fill")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 70, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemTitle)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                Text(item.itemGenre)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
