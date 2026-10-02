import SwiftUI

struct DailyReelView: View {
    let feature: DailyReelFeature
    var onChallenge: (DailyReelSessionProjection) async throws -> URL = { _ in
        throw DailyReelClientError.invalidEndpoint
    }
    var onClose: () -> Void = {}

    @State private var interaction = DailyReelPlayInteraction()
    @State private var showRevealConfirmation = false
    @State private var challengeShareItem: DailyReelChallengeShareItem?
    @State private var challengeErrorMessage: String?
    @State private var isCreatingChallenge = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            DailyReelBackdrop()

            Group {
                switch feature.phase {
                case .idle, .loading:
                    DailyReelLoadingView()
                case .playing, .submitting:
                    playContent
                case .completed:
                    resultsContent
                case .unavailable:
                    messageView(
                        eyebrow: "COMING ATTRACTION",
                        title: "Today's reel is being developed.",
                        message: "The classic Daily Puzzle is still ready to play.",
                        actionTitle: "Back to Home",
                        action: onClose
                    )
                case .failed:
                    messageView(
                        eyebrow: "PROJECTION PAUSED",
                        title: "We lost the picture.",
                        message: "Your place is saved. Reconnect and continue with the same reel.",
                        actionTitle: feature.isRetryAvailable ? "Retry Scene" : "Try Again",
                        action: retry
                    )
                }
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 18)
        }
        .preferredColorScheme(.dark)
        .task {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.84)) {
                appeared = true
            }
            await feature.load()
            interaction.prepare(for: feature.session?.currentAct)
        }
        .onChange(of: feature.session?.currentAct?.id) { _, _ in
            withAnimation(.snappy(duration: 0.35)) {
                interaction.prepare(for: feature.session?.currentAct)
            }
        }
        .confirmationDialog(
            "Reveal this scene?",
            isPresented: $showRevealConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reveal and move on", role: .destructive) {
                Task { await feature.reveal() }
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("You will keep the run, but this scene will not earn full points.")
        }
        .sheet(item: $challengeShareItem) { item in
            DailyReelChallengeShareView(item: item)
        }
        .alert(
            "Challenge unavailable",
            isPresented: Binding(
                get: { challengeErrorMessage != nil },
                set: { if !$0 { challengeErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { challengeErrorMessage = nil }
        } message: {
            Text(challengeErrorMessage ?? "Please try again in a moment.")
        }
    }

    private var playContent: some View {
        ScrollView {
            VStack(spacing: 22) {
                DailyReelHeader(
                    currentActIndex: feature.session?.currentActIndex ?? 0,
                    onClose: onClose
                )

                if let session = feature.session, let act = session.currentAct {
                    DailyReelActCard(
                        act: act,
                        progress: session.currentProgress,
                        interaction: interaction,
                        feedback: feature.feedback,
                        isSubmitting: feature.phase == .submitting,
                        onSubmit: submit,
                        onAssist: { kind in Task { await feature.requestAssist(kind) } },
                        onReveal: { showRevealConfirmation = true }
                    )
                    .id(act.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private var resultsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                DailyReelHeader(currentActIndex: 3, onClose: onClose)
                if let session = feature.session {
                    DailyReelResultsView(
                        session: session,
                        isCreatingChallenge: isCreatingChallenge,
                        onChallenge: { createChallenge(for: session) },
                        onClose: onClose
                    )
                }
            }
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    private func submit() {
        guard let act = feature.session?.currentAct,
              let answer = interaction.answer(for: act.role)
        else { return }
        Task { await feature.submit(answer) }
    }

    private func retry() {
        Task {
            if feature.isRetryAvailable {
                await feature.retry()
            } else {
                await feature.load()
            }
        }
    }

    private func createChallenge(for session: DailyReelSessionProjection) {
        guard !isCreatingChallenge else { return }
        isCreatingChallenge = true
        Task {
            do {
                challengeShareItem = DailyReelChallengeShareItem(
                    url: try await onChallenge(session)
                )
            } catch {
                challengeErrorMessage = "We could not create the link. Your score is still saved."
            }
            isCreatingChallenge = false
        }
    }

    private func messageView(
        eyebrow: String,
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text(eyebrow)
                .font(.custom("Avenir Next Condensed", size: 14, relativeTo: .caption))
                .fontWeight(.heavy)
                .tracking(2.2)
                .foregroundStyle(DailyReelPalette.gold)
            Text(title)
                .font(.custom("Avenir Next Condensed", size: 38, relativeTo: .largeTitle))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.68))
            Button(actionTitle, action: action)
                .buttonStyle(DailyReelPrimaryButtonStyle())
            Spacer()
        }
        .padding(30)
    }
}

private struct DailyReelHeader: View {
    let currentActIndex: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("DAILY")
                        .font(.custom("Avenir Next Condensed", size: 12, relativeTo: .caption2))
                        .fontWeight(.black)
                        .tracking(3)
                        .foregroundStyle(DailyReelPalette.gold)
                    Text("REEL")
                        .font(.custom("Avenir Next Condensed", size: 34, relativeTo: .largeTitle))
                        .fontWeight(.black)
                        .tracking(0.5)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.09), in: Circle())
                }
                .accessibilityLabel("Close Daily Reel")
            }

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    DailyReelProgressFrame(
                        number: index + 1,
                        state: index < currentActIndex ? .complete : index == currentActIndex ? .active : .upcoming
                    )
                }
            }
        }
    }
}

private struct DailyReelProgressFrame: View {
    enum State { case complete, active, upcoming }

    let number: Int
    let state: State

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: state == .complete ? "checkmark" : "\(number).circle.fill")
                .font(.caption.weight(.black))
            Text(["DECODE", "CONNECT", "ARRANGE"][number - 1])
                .font(.custom("Avenir Next Condensed", size: 11, relativeTo: .caption2))
                .fontWeight(.heavy)
                .lineLimit(1)
        }
        .foregroundStyle(state == .upcoming ? .white.opacity(0.34) : .white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            state == .active ? DailyReelPalette.red : .white.opacity(state == .complete ? 0.12 : 0.055),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            if state == .active {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DailyReelPalette.gold.opacity(0.7), lineWidth: 1)
            }
        }
    }
}

private struct DailyReelActCard: View {
    let act: DailyReelSessionAct
    let progress: DailyReelActProgress?
    let interaction: DailyReelPlayInteraction
    let feedback: DailyReelFeature.Feedback?
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onAssist: (DailyReelAssistKind) -> Void
    let onReveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("ACT \(actNumber) / \(act.role.rawValue.uppercased())")
                    .font(.custom("Avenir Next Condensed", size: 13, relativeTo: .caption))
                    .fontWeight(.heavy)
                    .tracking(2)
                    .foregroundStyle(DailyReelPalette.gold)
                Text(act.title ?? roleTitle)
                    .font(.custom("Avenir Next Condensed", size: 34, relativeTo: .title))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(act.prompt ?? rolePrompt)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.62))
            }

            roleContent

            if let feedback {
                DailyReelFeedbackBanner(feedback: feedback)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            Button(action: onSubmit) {
                HStack {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    }
                    Text(isSubmitting ? "Checking the cut..." : "Lock This Scene")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(DailyReelPrimaryButtonStyle())
            .disabled(interaction.answer(for: act.role) == nil || isSubmitting)
            .accessibilityIdentifier("dailyReel.submit")

            Divider().overlay(.white.opacity(0.1))

            HStack(spacing: 10) {
                assistButton(
                    title: "Clue",
                    symbol: "sparkle.magnifyingglass",
                    kind: .clue,
                    disabled: progress?.usedFreeClue == true
                )
                assistButton(
                    title: "Hint",
                    symbol: "lightbulb.max.fill",
                    kind: .hint,
                    disabled: progress?.usedScoreHint == true
                )
                Button(action: onReveal) {
                    Label("Reveal", systemImage: "eye.fill")
                }
                .buttonStyle(DailyReelUtilityButtonStyle())
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(DailyReelPalette.card)
                LinearGradient(
                    colors: [DailyReelPalette.red.opacity(0.17), .clear, DailyReelPalette.gold.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 28, y: 16)
    }

    @ViewBuilder
    private var roleContent: some View {
        switch act.role {
        case .decode:
            DailyReelDecodeView(act: act, interaction: interaction)
        case .connect:
            DailyReelConnectView(act: act, interaction: interaction)
        case .arrange:
            DailyReelArrangeView(act: act, interaction: interaction)
        }
    }

    private var actNumber: Int {
        switch act.role { case .decode: 1; case .connect: 2; case .arrange: 3 }
    }

    private var roleTitle: String {
        switch act.role {
        case .decode: "Name the movie"
        case .connect: "Find the connection"
        case .arrange: "Cut it in order"
        }
    }

    private var rolePrompt: String {
        switch act.role {
        case .decode: "Turn the visual clue into a title."
        case .connect: "Choose the detail shared by the film and its clue."
        case .arrange: "Put the story beats into release order."
        }
    }

    private func assistButton(
        title: String,
        symbol: String,
        kind: DailyReelAssistKind,
        disabled: Bool
    ) -> some View {
        Button { onAssist(kind) } label: {
            Label(title, systemImage: disabled ? "checkmark" : symbol)
        }
        .buttonStyle(DailyReelUtilityButtonStyle())
        .disabled(disabled || isSubmitting)
    }
}

private struct DailyReelDecodeView: View {
    let act: DailyReelSessionAct
    @Bindable var interaction: DailyReelPlayInteraction

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                ForEach(Array((act.emojis ?? []).enumerated()), id: \.offset) { _, emoji in
                    DailyReelEmojiGlyph(value: emoji)
                        .frame(maxWidth: .infinity, minHeight: 78)
                        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            if let clue = act.clue, !clue.isEmpty {
                Text(clue)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            TextField("Movie title", text: $interaction.textAnswer)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .font(.title3.weight(.semibold))
                .padding(16)
                .background(.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
                .accessibilityIdentifier("dailyReel.decode.answer")
        }
    }
}

private struct DailyReelEmojiGlyph: View {
    let value: String

    @ViewBuilder
    var body: some View {
        if let symbol = symbolName {
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(DailyReelPalette.gold)
                .accessibilityLabel(Text(value))
        } else {
            Text(value)
                .font(.system(size: 42))
        }
    }

    private var symbolName: String? {
        [
            "⏪": "backward.fill",
            "🚗": "car.fill",
            "⚡": "bolt.fill",
            "🚢": "ferry.fill",
            "🧊": "snowflake",
            "💔": "heart.slash.fill"
        ][value]
    }
}

private struct DailyReelConnectView: View {
    let act: DailyReelSessionAct
    let interaction: DailyReelPlayInteraction

    var body: some View {
        VStack(spacing: 10) {
            ForEach(act.options ?? []) { option in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { interaction.select(option.id) }
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: interaction.selectedChoiceID == option.id ? "record.circle.fill" : "circle")
                            .foregroundStyle(
                                interaction.selectedChoiceID == option.id ? DailyReelPalette.gold : .white.opacity(0.42)
                            )
                        Text(option.label)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        interaction.selectedChoiceID == option.id
                            ? DailyReelPalette.red.opacity(0.22)
                            : .black.opacity(0.24),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                interaction.selectedChoiceID == option.id
                                    ? DailyReelPalette.red.opacity(0.85)
                                    : .white.opacity(0.08),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dailyReel.connect.\(option.id)")
            }
        }
    }
}

private struct DailyReelArrangeView: View {
    let act: DailyReelSessionAct
    let interaction: DailyReelPlayInteraction

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Use the arrows to edit the cut")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.46))

            ForEach(Array(interaction.arrangedItems.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.custom("Avenir Next Condensed", size: 20, relativeTo: .headline))
                        .fontWeight(.black)
                        .foregroundStyle(DailyReelPalette.gold)
                        .frame(width: 28)
                    Text(item.label)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button { interaction.move(item.id, by: -1) } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(index == 0)
                    .accessibilityLabel("Move \(item.label) earlier")
                    Button { interaction.move(item.id, by: 1) } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(index == interaction.arrangedItems.count - 1)
                    .accessibilityLabel("Move \(item.label) later")
                }
                .padding(14)
                .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(DailyReelPalette.red)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
                .accessibilityIdentifier("dailyReel.arrange.\(item.id)")
            }
        }
    }
}

private struct DailyReelFeedbackBanner: View {
    let feedback: DailyReelFeature.Feedback

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private var title: String {
        switch feedback {
        case .correct: "Scene locked"
        case .incorrect: "Try another cut"
        case .assist: "Clue from the booth"
        case .revealed: "Scene revealed"
        }
    }

    private var detail: String? {
        switch feedback {
        case .assist(let text): text
        case .revealed(let text): text
        default: nil
        }
    }

    private var symbol: String {
        switch feedback {
        case .correct: "checkmark.seal.fill"
        case .incorrect: "arrow.counterclockwise"
        case .assist: "sparkles"
        case .revealed: "eye.fill"
        }
    }

    private var color: Color {
        switch feedback {
        case .correct: .green
        case .incorrect: DailyReelPalette.gold
        case .assist: .cyan
        case .revealed: DailyReelPalette.red
        }
    }
}

private struct DailyReelResultsView: View {
    let session: DailyReelSessionProjection
    let isCreatingChallenge: Bool
    let onChallenge: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("THAT'S A WRAP")
                    .font(.custom("Avenir Next Condensed", size: 13, relativeTo: .caption))
                    .fontWeight(.black)
                    .tracking(2.4)
                    .foregroundStyle(DailyReelPalette.gold)
                Text("\(session.totalScore)")
                    .font(.custom("Avenir Next Condensed", size: 78, relativeTo: .largeTitle))
                    .fontWeight(.black)
                    .contentTransition(.numericText())
                Text("FINAL CUT SCORE")
                    .font(.caption.weight(.heavy))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack(spacing: 8) {
                ForEach(["DECODE", "CONNECT", "ARRANGE"], id: \.self) { title in
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(DailyReelPalette.gold)
                        Text(title)
                            .font(.custom("Avenir Next Condensed", size: 11, relativeTo: .caption2))
                            .fontWeight(.heavy)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Button(action: onChallenge) {
                if isCreatingChallenge {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Challenge a Friend", systemImage: "person.2.fill")
                }
            }
            .buttonStyle(DailyReelPrimaryButtonStyle())
            .disabled(isCreatingChallenge)
            .accessibilityIdentifier("dailyReel.challenge")

            ShareLink(item: shareText) {
                Label("Share My Cut", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DailyReelSecondaryButtonStyle())

            Button("Return to Streaming Now", action: onClose)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(26)
        .background(DailyReelPalette.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(DailyReelPalette.gold.opacity(0.3), lineWidth: 1)
        }
    }

    private var shareText: String {
        "Daily Reel \(session.publicationID)\nFinal Cut: \(session.totalScore)\nDecode. Connect. Arrange."
    }
}

private struct DailyReelChallengeShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct DailyReelChallengeShareView: View {
    @Environment(\.dismiss) private var dismiss
    let item: DailyReelChallengeShareItem

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "person.2.badge.plus")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(DailyReelPalette.gold)
            Text("Challenge link ready")
                .font(.title2.weight(.black))
            Text("Your score stays hidden until your friend finishes the same Reel.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            ShareLink(
                item: item.url,
                subject: Text("Can you beat my Daily Reel?"),
                message: Text("Decode. Connect. Arrange. Then beat my cut.")
            ) {
                Label("Share Challenge", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DailyReelPalette.red)
            Button("Not now") { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

private struct DailyReelLoadingView: View {
    @State private var spinning = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.stack.fill")
                .font(.system(size: 54, weight: .black))
                .foregroundStyle(DailyReelPalette.red, DailyReelPalette.gold)
                .rotationEffect(.degrees(spinning ? 8 : -8))
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: spinning)
            Text("THREADING TODAY'S REEL")
                .font(.custom("Avenir Next Condensed", size: 15, relativeTo: .headline))
                .fontWeight(.black)
                .tracking(2)
            ProgressView().tint(DailyReelPalette.gold)
        }
        .onAppear { spinning = true }
    }
}

private struct DailyReelBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.12, green: 0.025, blue: 0.035), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { proxy in
                Path { path in
                    let spacing: CGFloat = 44
                    for x in stride(from: -proxy.size.height, through: proxy.size.width, by: spacing) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + proxy.size.height, y: proxy.size.height))
                    }
                }
                .stroke(.white.opacity(0.018), lineWidth: 1)
            }
            RadialGradient(
                colors: [DailyReelPalette.red.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

private enum DailyReelPalette {
    static let red = Color(red: 0.86, green: 0.12, blue: 0.18)
    static let gold = Color(red: 1.0, green: 0.69, blue: 0.22)
    static let card = Color(red: 0.105, green: 0.09, blue: 0.095)
}

private struct DailyReelPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [DailyReelPalette.red, Color(red: 0.63, green: 0.055, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct DailyReelSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(.white.opacity(configuration.isPressed ? 0.14 : 0.075), in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct DailyReelUtilityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.55 : 0.82))
            .background(.white.opacity(configuration.isPressed ? 0.1 : 0.055), in: RoundedRectangle(cornerRadius: 11))
    }
}
