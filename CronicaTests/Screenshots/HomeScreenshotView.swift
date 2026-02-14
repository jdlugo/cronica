import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper for the Home screen. Uses real HorizontalItemContentListView
/// components with mock data, bypassing HomeViewModel's network dependency.
struct HomeScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    // Each section uses a distinct slice so visible posters never repeat.
    private let trending = Array(ItemContent.examples.prefix(10))
    private let nowPlaying = Array(ItemContent.examples.dropFirst(7).prefix(8))
    private let upcoming = Array(ItemContent.examples.dropFirst(15).prefix(8))
    private let topRated = Array(ItemContent.examples.dropFirst(22).prefix(8))
    private let popularTV = Array(ItemContent.examples.dropFirst(4).prefix(8))
    private let recommendations = Array(ItemContent.examples.dropFirst(10).prefix(5))

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
                    items: topRated,
                    title: NSLocalizedString("Top Rated", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )

                HorizontalItemContentListView(
                    items: popularTV,
                    title: NSLocalizedString("Popular", comment: ""),
                    subtitle: NSLocalizedString("TV Shows", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
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
