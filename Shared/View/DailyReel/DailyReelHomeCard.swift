import SwiftUI

#if os(iOS)
struct DailyReelHomeCard: View {
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DAILY REEL")
                            .font(.caption.weight(.black))
                            .tracking(2.2)
                            .foregroundStyle(.yellow)

                        Text("Three acts. One perfect run.")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 16)

                    Text("NEW")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(.white.opacity(0.16), in: Capsule())
                }

                HStack(spacing: 8) {
                    actBadge(number: "1", title: "Decode", symbol: "sparkles")
                    actBadge(number: "2", title: "Connect", symbol: "link")
                    actBadge(number: "3", title: "Arrange", symbol: "arrow.up.arrow.down")
                }

                HStack {
                    Text("Play today's reel")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.subheadline.weight(.black))
                        .frame(width: 34, height: 34)
                        .background(.yellow, in: Circle())
                        .foregroundStyle(.black)
                }
                .foregroundStyle(.white)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.48, green: 0.05, blue: 0.08),
                            Color(red: 0.12, green: 0.02, blue: 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(.red.opacity(0.28))
                        .frame(width: 210, height: 210)
                        .blur(radius: 18)
                        .offset(x: 150, y: -85)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.red.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play Daily Reel, a three-act movie challenge")
    }

    private func actBadge(number: String, title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Text(number)
                .font(.caption2.weight(.black).monospacedDigit())
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.16), in: Circle())
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.2), in: Capsule())
        .frame(maxWidth: .infinity)
    }
}
#endif
