import SwiftUI

struct DetailWatchlistButton: View {
    @Environment(ItemContentViewModel.self) var viewModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var showCustomList: Bool
    @State private var showConfirmationPopup = false
    @StateObject private var settings = SettingsStore.shared
    var body: some View {
        Button {
            if viewModel.isInWatchlist {
                if SettingsStore.shared.showRemoveConfirmation {
                    showConfirmationPopup = true
                } else {
                    update()
                }
            } else {
                HapticManager.shared.successHaptic()
                update()
            }
        } label: {
#if os(iOS) || os(watchOS)
            VStack {
                Image(systemName: viewModel.isInWatchlist ? "minus.circle.fill" : "plus.circle.fill")
                    .symbolEffect(viewModel.isInWatchlist ? .bounce.down : .bounce.up,
                                  value: viewModel.isInWatchlist)
                Text(viewModel.isInWatchlist ? "Remove" : "Add")
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
                    .font(.caption)
            }
#if os(iOS)
            .padding(.vertical, 4)
            .frame(width: typeSize.isAccessibilitySize ? nil : 75)
            .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
#else
            .padding(.vertical, 2)
#endif
#elseif os(macOS)
            Label(viewModel.isInWatchlist ? "Remove": "Add to watchlist",
                  systemImage: viewModel.isInWatchlist ? "minus.circle.fill" : "plus.circle.fill")
            .symbolEffect(viewModel.isInWatchlist ? .bounce.down : .bounce.up,
                          value: viewModel.isInWatchlist)
#else
            Label(viewModel.isInWatchlist ? "Remove from watchlist": "Add to watchlist",
                  systemImage: viewModel.isInWatchlist ? "minus.circle.fill" : "plus.circle.fill")
            .symbolEffect(viewModel.isInWatchlist ? .bounce.down : .bounce.up,
                          value: viewModel.isInWatchlist)
#if os(tvOS)
            .labelStyle(.iconOnly)
#endif
#endif
        }
        .buttonStyle(.borderedProminent)
#if os(macOS)
        .controlSize(.large)
#elseif os(iOS)
        .controlSize(.small)
        .applyHoverEffect()
#endif
        .disabled(viewModel.isLoading)
        .accessibilityIdentifier("movieDetails.watchlist")
#if os(iOS) || os(macOS) || os(watchOS)
        .tint(viewModel.isInWatchlist ? .red.opacity(0.95) : settings.appTheme.color)
#endif
#if os(iOS)
        .buttonBorderShape(.roundedRectangle(radius: 12))
#endif
        .alert("removeDialogTitle", isPresented: $showConfirmationPopup) {
            Button("confirmDialogAction") { update() }
            Button("cancelConfirmDialogAction") {  showConfirmationPopup = false }
        }
    }
    
    private func update() {
        guard let item = viewModel.content else { return }
        viewModel.updateWatchlist(with: item)
        if settings.openListSelectorOnAdding && viewModel.isInWatchlist {
            showCustomList.toggle()
        }
    }
}
