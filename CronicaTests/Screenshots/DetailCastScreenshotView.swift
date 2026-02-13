import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper showing Cast & Crew and Recommendations sections
/// from the detail page, with a cinematic backdrop overlay.
struct DetailCastScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let item = ItemContent.example
    private let recommendations = Array(ItemContent.examples.prefix(8))

    var body: some View {
        NavigationStack {
            ScrollView {
                CastListView(credits: item.credits?.cast ?? [])

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("Recommendations", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle(item.itemTitle)
            .toolbar(.hidden, for: .navigationBar)
            .background {
                ZStack {
                    WebImage(url: item.cardImageLarge) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle().fill(.background)
                    }
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                }
            }
        }
    }
}
