import SwiftUI

#if os(iOS)
import AdmobSwiftUI
#endif

#if !os(tvOS)
/// Displays the overview of a movie, tv show, or episode.
/// It can also display biography.
struct OverviewBoxView: View {
    let overview: String?
    let title: String
    var type: MediaType = .movie
    var showAsPopover = false
    @State private var showFullText = false
    @State private var showSheet = false
    @State private var showTextOptions = true
    @State private var isTruncated = false
    @StateObject private var settings = SettingsStore.shared
#if os(iOS)
    @StateObject private var nativeViewModel = NativeAdViewModel(adUnitID: "ca-app-pub-7891478850122465/8171033829", requestInterval: 1)
#endif
    
    var body: some View {
        if let overview {
            if !overview.isEmpty {
                GroupBox {
                    VStack(alignment: .leading) {
                        Text(overview)
                            .font(.callout)
                            .padding([.top], 2)
                            .lineLimit(showFullText ? nil : 4)
                            .multilineTextAlignment(.leading)
#if os(iOS)
                            .background(
                                // Render the limited text and measure its size
                                Text(overview)
                                    .lineLimit(4)
                                    .font(.callout)
                                    .padding([.top], 2)
                                    .background(GeometryReader { displayedGeometry in
                                        // Create a ZStack with unbounded height to allow the inner Text as much
                                        // height as it likes, but no extra width.
                                        ZStack {
                                            // Render the text without restrictions and measure its size
                                            Text(overview)
                                                .font(.callout)
                                                .padding([.top], 2)
                                                .background(GeometryReader { fullGeometry in
                                                    // And compare the two
                                                    Color.clear.onAppear {
                                                        self.isTruncated = fullGeometry.size.height > displayedGeometry.size.height
                                                    }
                                                })
                                        }
                                        .frame(height: .greatestFiniteMagnitude)
                                    })
                                    .hidden() // Hide the background
                            )
#endif
                        
#if os(iOS)
                        if isTruncated {
                            Text(showFullText ? "Collapse" : "Show More")
                                .fontDesign(.rounded)
                                .textCase(.uppercase)
                                .font(.caption)
                                .foregroundStyle(settings.appTheme.color)
                                .padding(.top, 4)
                            
                        }
                        
#if os(iOS)
                        NativeAdView(nativeViewModel: nativeViewModel, style: .banner)
                                                .frame(height: 90)
                                                .background(Color(UIColor.secondarySystemBackground))
#endif
                        
                        
#endif
                    }
                } label: {
                    Text(type == .person ? "Biography" : "About")
                        .unredacted()
                }
                .onTapGesture {
#if os(iOS)
                    if UIDevice.isIPad {
                        if showAsPopover {
                            showSheet.toggle()
                        } else {
                            withAnimation { showFullText.toggle() }
                        }
                    } else {
                        withAnimation { showFullText.toggle() }
                    }
                    
#elseif os(macOS)
                    showSheet.toggle()
#endif
                }
                .accessibilityElement(children: .combine)
                .contextMenu {  ShareLink(item: overview) }
                .popover(isPresented: $showSheet) {
                    ScrollView {
                        Text(overview )
                            .unredacted()
                            .padding()
                    }
                    .frame(width: 400, height: 200, alignment: .center)
                }
#if os(iOS)
                .groupBoxStyle(TransparentGroupBox())
                .onAppear {
                           nativeViewModel.refreshAd()
                }
#endif
            }
        }
    }
}

#Preview {
    OverviewBoxView(overview: ItemContent.example.overview,
                    title: ItemContent.example.itemTitle,
                    type: .movie)
}
#endif
