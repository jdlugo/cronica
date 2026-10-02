import SwiftUI

/// Generic marketing wrapper that adds a gradient background and localized headline
/// above any existing screenshot content view. Inspired by JustWatch's App Store design.
///
/// Layout:
/// ```
/// ┌──────────────────────────┐
/// │   Gradient Background    │
/// │                          │
/// │  **Never Miss**          │  ← ~30% of height
/// │  What's Next             │     left-aligned, two-tone text
/// │                          │
/// │  ┌────────────────────┐  │
/// │  │                    │  │
/// │  │   App Screenshot   │  │  ← ~70% of height
/// │  │   Content          │  │     rounded top corners, bleeds to bottom
/// │  │                    │  │     subtle device border + shadow
/// │  │                    │  │
/// └──┴────────────────────┴──┘
/// ```
///
/// Headlines use `**text**` markers for accent-colored keywords:
/// `"**Never Miss** What's Next"` → "Never Miss" in gold, "What's Next" in white.
struct MarketingScreenshotView<Content: View>: View {
    let headline: String
    let content: Content

    /// Warm gold accent for keyword emphasis — cinematic, premium feel.
    private let accentColor = Color(red: 1.0, green: 0.78, blue: 0.30)

    private let contentShape = UnevenRoundedRectangle(
        topLeadingRadius: 20,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 20
    )

    init(
        headline: String,
        @ViewBuilder content: () -> Content
    ) {
        self.headline = headline
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let fontSize = adaptiveFontSize(for: width)
            let horizontalPadding = width * 0.06
            let contentPadding = width * 0.04

            ZStack {
                // Background gradient: cinematic burgundy → warm shadow → black
                LinearGradient(
                    colors: [
                        Color(red: 0.19, green: 0.035, blue: 0.045),
                        Color(red: 0.07, green: 0.025, blue: 0.018),
                        .black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Headline area — centered, two-tone text, compact top padding
                    styledHeadline(fontSize: fontSize)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, height * 0.03)
                        .padding(.bottom, height * 0.02)
                        .accessibilityIdentifier("marketing.headline")

                    // App content — device-style presentation
                    content
                        .clipShape(contentShape)
                        // Subtle top gradient overlay — smooths bright backdrop transitions
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [.black.opacity(0.35), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 50)
                            .clipShape(contentShape)
                        }
                        // Device frame: thin border + drop shadow
                        .overlay {
                            contentShape
                                .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                        }
                        .shadow(color: .black.opacity(0.6), radius: 15, y: 8)
                        .padding(.horizontal, contentPadding)
                }
            }
        }
    }

    // MARK: - Two-Tone Headline Rendering

    /// Parses `**text**` markers and renders accent words in gold bold,
    /// regular words in white medium weight.
    private func styledHeadline(fontSize: CGFloat) -> Text {
        let segments = parseMarkup(headline)
        var result = Text("")
        for segment in segments {
            if segment.isAccent {
                result = result + Text(segment.text)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
            } else {
                result = result + Text(segment.text)
                    .font(.system(size: fontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
            }
        }
        return result
    }

    /// Splits a string on `**` delimiters into (text, isAccent) segments.
    private func parseMarkup(_ text: String) -> [(text: String, isAccent: Bool)] {
        let parts = text.components(separatedBy: "**")
        return parts.enumerated().compactMap { index, part in
            guard !part.isEmpty else { return nil }
            return (text: part, isAccent: index % 2 == 1)
        }
    }

    // MARK: - Adaptive Sizing

    /// Adaptive font size based on device width.
    /// iPhone (~430-440pt) → 36pt, iPad 11" (~834pt) → 48pt, iPad 13" (~1032pt) → 56pt
    private func adaptiveFontSize(for width: CGFloat) -> CGFloat {
        if width > 900 {
            return 56  // iPad 13"
        } else if width > 700 {
            return 48  // iPad 11"
        } else {
            return 36  // iPhone
        }
    }
}
