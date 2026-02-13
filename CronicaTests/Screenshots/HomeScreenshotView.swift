import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper for the Home screen. Uses real HorizontalItemContentListView
/// components with mock data, bypassing HomeViewModel's network dependency.
struct HomeScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let trending = ItemContent.examples
    private let nowPlaying = Array(ItemContent.examples.dropFirst(3).prefix(8))
    private let upcoming = Array(ItemContent.examples.dropFirst(5).prefix(8))
    private let recommendations = Array(ItemContent.examples.prefix(5))

    var body: some View {
        NavigationStack {
            ScrollView {
                HorizontalItemContentListView(
                    items: trending,
                    title: NSLocalizedString("Trending", comment: ""),
                    subtitle: NSLocalizedString("Today", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )

                HorizontalItemContentListView(
                    items: nowPlaying,
                    title: NSLocalizedString("Now Playing", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType,
                    endpoint: .nowPlaying
                )

                HorizontalItemContentListView(
                    items: upcoming,
                    title: NSLocalizedString("Upcoming", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType,
                    endpoint: .upcoming
                )

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("recommendationsTitle", comment: ""),
                    subtitle: NSLocalizedString("recommendationsSubtitle", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle("Home")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
