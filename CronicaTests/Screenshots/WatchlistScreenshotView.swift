import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper for the Watchlist screen. Renders a poster grid layout
/// using ItemContentPosterView with mock data, bypassing Core Data @FetchRequest.
struct WatchlistScreenshotView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    // Triple the data to fill iPad grids. Use enumerated ForEach below
    // since ItemContent.id (Int) is the same across copies.
    private let items = ItemContent.examples + ItemContent.examples + ItemContent.examples

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 280))]
        }
        return [GridItem(.adaptive(minimum: 160))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
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
                            Text("All Items")
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
            .navigationTitle(NSLocalizedString("Watchlist", comment: ""))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
