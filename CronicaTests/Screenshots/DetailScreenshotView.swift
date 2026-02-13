import SDWebImageSwiftUI
import SwiftUI
@testable import StreamingNow

#if DEBUG
/// Screenshot wrapper for the Detail screen. Pre-populates an ItemContentViewModel
/// with mock data and renders ItemContentPhoneView.
struct DetailScreenshotView: View {
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
}
#endif
