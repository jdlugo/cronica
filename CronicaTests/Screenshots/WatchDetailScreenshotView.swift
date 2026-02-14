import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper mimicking the watchOS detail screen (ItemContentView).
/// Renders at watch point dimensions through the iOS test target.
struct WatchDetailScreenshotView: View {
    private let item = ItemContent.example

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Hero backdrop — replicates watchOS HeroImage (90pt tall)
                WebImage(url: item.cardImageMedium) { image in
                    image.resizable()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "popcorn.fill")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                }
                .aspectRatio(contentMode: .fill)
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.horizontal, 4)

                // Title
                Text(item.itemTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Quick info (genre, runtime)
                Text(item.itemGenre)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Add to Watchlist button
                Button {
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                // About section
                VStack(alignment: .leading, spacing: 4) {
                    Text("About")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(item.itemOverview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 4)
        }
        .background(Color.black)
    }
}
