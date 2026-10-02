#if canImport(ActivityKit)
import ActivityKit
import WidgetKit
import SwiftUI

struct CronicaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CronicaActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            HStack(spacing: 12) {
                Image(systemName: context.attributes.mediaType == "movie" ? "film" : "tv")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)

                    if context.state.hasReleased {
                        Text("Available Now!")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Text(context.state.releaseDate, style: .relative)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !context.state.hasReleased {
                    Text(context.state.releaseDate, style: .timer)
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.mediaType == "movie" ? "film" : "tv")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        if context.state.hasReleased {
                            Text("Available Now!")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text(context.state.releaseDate, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !context.state.hasReleased {
                        Text(context.state.releaseDate, style: .timer)
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: "popcorn.fill")
                    .foregroundStyle(.red)
            } compactTrailing: {
                if context.state.hasReleased {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text(context.state.releaseDate, style: .timer)
                        .font(.caption)
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: "popcorn.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.2, *)
struct LiveActivityManager {
    @MainActor
    static func startActivity(for item: WatchlistItem) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let title = item.title else { return }

        let releaseDate = item.movieReleaseDate ?? item.firstAirDate ?? item.date ?? Date()
        let mediaType = item.contentType == 0 ? "movie" : "tv"

        let attributes = CronicaActivityAttributes(
            title: title,
            posterPath: item.posterPath,
            mediaType: mediaType,
            tmdbID: Int(item.id)
        )

        let state = CronicaActivityAttributes.ContentState(
            releaseDate: releaseDate,
            hasReleased: releaseDate <= Date()
        )

        let content = ActivityContent(state: state, staleDate: releaseDate.addingTimeInterval(3600))

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    static func endAllActivities() async {
        for activity in Activity<CronicaActivityAttributes>.activities {
            let state = CronicaActivityAttributes.ContentState(
                releaseDate: activity.content.state.releaseDate,
                hasReleased: true
            )
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(.now + 3600)
            )
        }
    }
}
#endif
