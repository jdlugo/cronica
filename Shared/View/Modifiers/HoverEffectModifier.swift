import SwiftUI

struct HoverEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        return content
            .hoverEffect(.automatic)
#else
        return content
            .buttonStyle(.plain)
#endif
    }
}
