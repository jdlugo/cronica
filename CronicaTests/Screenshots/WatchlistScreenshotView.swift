import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper for the Watchlist screen. Renders a poster grid layout
/// using ItemContentPosterView with mock data, bypassing Core Data @FetchRequest.
struct WatchlistScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let items = ItemContent.examples

    private let columns = [GridItem(.adaptive(minimum: 160))]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Section {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(items) { item in
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
        }
    }
}
