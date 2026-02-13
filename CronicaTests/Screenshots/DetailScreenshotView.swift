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

    init(item: ItemContent = .previewMock) {
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
                TranslucentBackground(image: item.cardImageLarge)
            }
        }
    }
}
#endif
