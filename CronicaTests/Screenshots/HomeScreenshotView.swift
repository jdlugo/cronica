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
                dailyPuzzleCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

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

    private var dailyPuzzleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    NSLocalizedString("dailyPuzzleTitle", comment: "Daily puzzle screenshot title"),
                    systemImage: "sparkles"
                )
                .font(.headline.weight(.bold))
                Spacer()
                Text("24h")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.red.opacity(0.22), in: Capsule())
            }

            Text(NSLocalizedString("dailyPuzzleGuessFromEmojis", comment: "Daily puzzle screenshot subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                puzzleIcon("car.side.fill", color: .red)
                Text("+").foregroundStyle(.secondary)
                puzzleIcon("flag.checkered", color: .white)
                Text("+").foregroundStyle(.secondary)
                puzzleIcon("trophy.fill", color: .yellow)
            }
            .font(.title2.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.black.opacity(0.22), in: Capsule())

            Label(
                NSLocalizedString("dailyPuzzleTitle", comment: "Daily puzzle screenshot CTA"),
                systemImage: "play.fill"
            )
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [.red.opacity(0.26), .orange.opacity(0.08), .black.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.red.opacity(0.4), lineWidth: 1)
        }
        .accessibilityIdentifier("marketing.dailyPuzzleCard")
    }

    private func puzzleIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 25, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 48, height: 42)
            .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(color.opacity(0.34), lineWidth: 1)
            }
    }
}
