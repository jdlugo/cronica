import SwiftUI

struct ContentView: View {
    var body: some View {
#if os(iOS) || os(tvOS)
        TabBarView()
#elseif os(macOS)
        SideBarView()
#endif   
    }
}

#Preview {
    ContentView()
}
