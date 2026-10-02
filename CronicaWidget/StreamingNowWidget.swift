//
//  CronicaWidget.swift
//  CronicaWidget
//
//  Created by Alexandre Madeira on 26/08/22.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ItemContentEntry {
        ItemContentEntry(date: Date(), item: ItemContent.examples)
    }

    func getSnapshot(in context: Context, completion: @escaping (ItemContentEntry) -> ()) {
        let entry = ItemContentEntry(date: Date(), item: ItemContent.examples)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let nextUpdate = Date().addingTimeInterval(86400) // 24 hours in seconds
            do {
                let result = try await NetworkService.shared.fetchItems(from: "trending/all/day")
                var content = [ItemContent]()
                let sortedItems = result.sorted { $0.id < $1.id }
                let itemCount: Int
                switch context.family {
                case .systemSmall:
                    itemCount = 1
                case .systemLarge:
                    itemCount = 8
                case .accessoryRectangular, .accessoryCircular:
                    itemCount = 1
                default:
                    itemCount = 4
                }
                for item in sortedItems.prefix(itemCount) {
                    let image = await NetworkService.shared.downloadImageData(from: item.posterImage)
                    let itemContent = ItemContent(id: item.id,
                                                  title: item.title,
                                                  name: item.name,
                                                  posterPath: item.posterPath,
                                                  backdropPath: item.backdropPath,
                                                  data: image)
                    content.append(itemContent)
                }
                let entry = ItemContentEntry(date: .now, item: content)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
}

struct ItemPosterImage: Codable, Identifiable {
    var id: Int
    var image: Data?
}

struct ItemContentEntry: TimelineEntry {
    let date: Date
    let item: [ItemContent]
}

struct CronicaWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .accessoryRectangular:
            rectangularWidget
        case .accessoryCircular:
            circularWidget
        default:
            mediumWidget
        }
    }

    private var smallWidget: some View {
        VStack {
            if let item = entry.item.first {
                Link(destination: URL(string: item.itemContentID)!) {
                    ZStack(alignment: .bottomLeading) {
                        posterImage(for: item)
                        LinearGradient(colors: [.clear, .black.opacity(0.7)],
                                       startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading) {
                            Spacer()
                            Text(item.title ?? item.name ?? "")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        .padding(8)
                    }
                }
            } else {
                PlaceholderImage()
            }
        }
    }

    private var mediumWidget: some View {
        VStack(alignment: .leading) {
            ItemContentList(items: entry.item)
        }
        .padding()
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trending")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 6) {
                ForEach(entry.item) { item in
                    Link(destination: URL(string: item.itemContentID)!) {
                        posterImage(for: item)
                            .frame(width: 70, height: 105)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
            .padding(.horizontal)
            Spacer()
        }
    }

    private var rectangularWidget: some View {
        VStack(alignment: .leading) {
            if let item = entry.item.first {
                Text("Trending")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(item.title ?? item.name ?? "")
                    .font(.headline)
                    .lineLimit(2)
            } else {
                Text("Trending")
                    .font(.caption2)
                Text("No data available")
                    .font(.headline)
            }
        }
    }

    private var circularWidget: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "popcorn.fill")
                .font(.title3)
        }
    }

    @ViewBuilder
    private func posterImage(for item: ItemContent) -> some View {
        if let data = item.data {
#if os(iOS)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                PlaceholderImage()
            }
#elseif os(macOS)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                PlaceholderImage()
            }
#endif
        } else {
            PlaceholderImage()
        }
    }
}

private struct PlaceholderImage: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color.gray.gradient)
            Image(systemName: "popcorn.fill")
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

@main
struct StreamingNowWidget: Widget {
    let kind: String = "StreamingNowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CronicaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Trending")
        .description("Shows movies and TV Shows trending from TMDb.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        #if os(iOS)
        families += [.accessoryRectangular, .accessoryCircular]
        #endif
        return families
    }
}
