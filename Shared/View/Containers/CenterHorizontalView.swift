import SwiftUI

struct CenterHorizontalView<Content: View>: View {
    var content: () -> Content
    @ViewBuilder
    var body: some View {
        HStack {
            Spacer()
            content()
            Spacer()
        }
    }
}

#Preview {
    CenterHorizontalView {
        Label("Preview", systemImage: "square.stack")
    }
}
