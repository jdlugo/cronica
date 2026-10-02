import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

#if DEBUG
/// Screenshot wrapper for the Detail screen. Pre-populates an ItemContentViewModel
/// with mock data and renders ItemContentPhoneView.
struct DetailScreenshotView: View {
    @Environment(\.locale) private var locale
    @State private var viewModel: ItemContentViewModel
    @State private var showPopup = false
    @State private var showCustomList = false
    @State private var popupType: ActionPopupItems?
    @State private var showReviewSheet = false

    private let item: ItemContent

    init(item: ItemContent = .example) {
        self.item = item
        _viewModel = State(wrappedValue: ItemContentViewModel.preview(with: item))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    regionalProviderCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    ItemContentPhoneView(
                        title: item.itemTitle,
                        type: .movie,
                        id: item.id,
                        showPopup: $showPopup,
                        showCustomList: $showCustomList,
                        popupType: $popupType,
                        showReviewSheet: $showReviewSheet
                    )
                }
            }
            .environment(viewModel)
            .background {
                // Material effects don't render in snapshot tests, so we replace
                // TranslucentBackground with the backdrop image + explicit dark overlay.
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

    private var providerContext: (region: String, services: [String]) {
        let identifier = locale.identifier.lowercased()
        if identifier.contains("es-mx") {
            return ("México", ["Netflix", "Prime Video", "Disney+"])
        }
        if identifier.hasPrefix("es") {
            return ("España", ["Movistar Plus+", "Netflix", "Prime Video"])
        }
        if identifier.hasPrefix("fr") {
            return ("France", ["CANAL+", "Netflix", "Disney+"])
        }
        if identifier.hasPrefix("pt-br") || identifier.hasPrefix("pt_br") {
            return ("Brasil", ["Globoplay", "Netflix", "Prime Video"])
        }
        return ("Your region", ["Apple TV", "Netflix", "Prime Video"])
    }

    private var regionalProviderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    NSLocalizedString("watchProviderTitleList", comment: "Provider screenshot title"),
                    systemImage: "play.tv.fill"
                )
                .font(.headline.weight(.bold))
                Spacer()
                Text(providerContext.region)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text(NSLocalizedString("justWatchSubtitle", comment: "Provider screenshot subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(providerContext.services, id: \.self) { service in
                    Text(service)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .accessibilityIdentifier("marketing.regionalProviders")
    }
}
#endif
