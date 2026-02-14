import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper for the Watchlist screen. Shows a favorites horizontal
/// section and a poster grid, demonstrating the app's collection features.
struct WatchlistScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let favorites = Array(ItemContent.examples.prefix(6))

    // Triple the data to fill iPad grids. Use enumerated ForEach below
    // since ItemContent.id (Int) is the same across copies.
    private let items = ItemContent.examples + ItemContent.examples + ItemContent.examples

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    HorizontalItemContentListView(
                        items: favorites,
                        title: NSLocalizedString("Favorites", comment: ""),
                        subtitle: "",
                        showPopup: $showPopup,
                        popupType: $popupType
                    )

                    Section {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                ItemContentPosterView(
                                    item: item,
                                    showPopup: $showPopup,
                                    popupType: $popupType
                                )
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    } header: {
                        HStack {
                            Text("Want to Watch")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(items.count) items")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
