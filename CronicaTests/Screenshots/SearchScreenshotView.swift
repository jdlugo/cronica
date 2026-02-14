import SwiftUI
@testable import StreamingNow

/// Screenshot wrapper showing search results — demonstrates the app's
/// search feature with a poster grid for the query "Action".
struct SearchScreenshotView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    // Triple the data to fill iPad grids.
    private let items = ItemContent.examples + ItemContent.examples + ItemContent.examples

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Simulated search bar
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text("Action")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal)

                    // Scope picker
                    Picker("Scope", selection: .constant(0)) {
                        Text("Movies").tag(0)
                        Text("TV Shows").tag(1)
                        Text("People").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                // Results grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        ItemContentPosterView(
                            item: item,
                            showPopup: $showPopup,
                            popupType: $popupType
                        )
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
