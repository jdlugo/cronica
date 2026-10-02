#if os(iOS)
import SwiftUI
import Observation

@MainActor @Observable
private final class ArcadePlayer {
    var session: ArcadeSession?
    var showingSummary = false
    var feedbackTick = 0
    let progress: ArcadeProgressStore
    private let fixture: Bool
    @ObservationIgnored private var analytics: ArcadeAnalyticsJournal
    private var entryType = "fresh"
    init() {
        fixture = ProcessInfo.processInfo.arguments.contains("--arcade-test")
        let defaults = fixture ? UserDefaults(suiteName: "MovieArcade.UITests")! : .standard
        if fixture && ProcessInfo.processInfo.arguments.contains("--arcade-reset") {
            defaults.removePersistentDomain(forName: "MovieArcade.UITests")
        }
        progress = ArcadeProgressStore(defaults: defaults)
        analytics = ArcadeAnalyticsJournal(defaults: defaults)
        if fixture, let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--arcade-game=") }) {
            let value = String(arg.dropFirst("--arcade-game=".count))
            if value == "daily" { openDaily() }
            else if let kind = ArcadeKind(rawValue: value) { openPractice(kind) }
        }
    }
    var today: String { fixture ? "2026-09-30" : ArcadeSession.dayKey() }
    var savedDaily: ArcadeSession? { progress.load(isDaily: true, day: today) }
    func openDaily() {
        let saved = savedDaily
        session = saved ?? .daily(day: today)
        showingSummary = session?.isComplete == true
        entryType = showingSummary ? "summary" : saved == nil ? "fresh" : "resume"
        save()
    }
    func openPractice(_ kind: ArcadeKind, fresh: Bool = false) {
        if !fresh, let saved = progress.load(isDaily: false, kind: kind), !saved.isComplete {
            session = saved; entryType = "resume"
        } else {
            session = fixture && !fresh ? ArcadeSession.practice(kind, number: 0) : progress.nextPracticeSession(kind)
            entryType = "fresh"
        }
        showingSummary = false; save()
    }
    func exposed() { emit(analytics.exposed(entry: "lobby")) }
    func roundVisible() {
        guard let session, !showingSummary else { return }
        emit(analytics.visible(ArcadeAnalyticsContext(session: session)))
    }
    func suspend() {
        guard let session else { return }
        analytics.suspend(ArcadeAnalyticsContext(session: session))
    }
    func summaryVisible() {
        guard let session else { return }
        emit(analytics.summaryVisible(ArcadeAnalyticsContext(session: session)))
    }
    func discover(_ action: ArcadeDiscoveryEvent.Action, filmID: Int,
                  surface: ArcadeDiscoverySurface, session: ArcadeSession) {
        guard let event = ArcadeDiscoveryEvent.make(action, filmID: filmID, surface: surface, session: session) else { return }
        emit([event])
    }
    func act(_ action: ArcadeAction) {
        guard var run = session else { return }
        let before = run.current
        guard run.rounds[run.index].apply(action) else { return }
        session = run; save(); feedbackTick += 1
        let role: ArcadeAnalyticsActionRole
        switch action {
        case .skip: role = .skip
        case .clue, .assemble: role = .help
        case .choose: role = before.kind == .memory ? .bonus : .attempt
        case .timeline: role = .attempt
        case .card: role = before.selected.isEmpty ? .selection : .attempt
        case .tile(let index): role = before.selected == [index] ? .progress : before.selected.isEmpty ? .selection : .attempt
        case .swapTiles: role = .attempt
        case .nextHeist, .nextTimeline, .clearMismatch, .finishMatching: role = .progress
        }
        emit(analytics.acceptedAction(role, context: ArcadeAnalyticsContext(session: run)))
    }
    func next() {
        guard var run = session else { return }
        if run.isComplete { showingSummary = true }
        else if run.advance() { session = run; save() }
    }
    func backToGames() { trackAbandon(); session = nil; showingSummary = false }
    func trackAbandon(reason: String = "dismissed") {
        guard let session, !session.isComplete else { return }
        emit(analytics.abandon(ArcadeAnalyticsContext(session: session)), additional: ["exit_reason": reason])
    }
    private func save() { if let session { progress.save(session) } }
    private func emit(_ events: [ArcadeAnalyticsEvent], additional: [String: Any] = [:]) {
        guard !fixture else { return }
        for event in events {
            CronicaTelemetry.shared.capture(event.name, properties: event.properties.merging([
                "entry_type": entryType, "entry_layout": "guided_v2"
            ], uniquingKeysWith: { _, value in value }).merging(additional, uniquingKeysWith: { _, value in value }))
        }
    }
}

struct MovieArcadeHomeCard: View {
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: "gamecontroller.fill").font(.title).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Movie Arcade").font(.headline)
                    Text("Match posters. Spot scenes. Start with a quick win.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.mint)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.mint.opacity(0.25)))
        }
        .buttonStyle(.plain).accessibilityIdentifier("arcade.home")
        .onAppear {
            guard !ProcessInfo.processInfo.arguments.contains("--arcade-test") else { return }
            CronicaTelemetry.shared.capture("movie_arcade_exposed", properties: ["arcade_schema_version": 2, "entry": "home", "entry_layout": "guided_v2"])
        }
    }
}

struct MovieArcadeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var player = ArcadePlayer()
    @State private var showingAllGames = false
    @State private var showingMovie = false
    @State private var discovery: DiscoverySelection?
    @GestureState private var scrambleDrag: ScrambleDrag?
    private struct ScrambleDrag: Equatable {
        let source: Int
        let location: CGPoint?
    }
    private struct DiscoverySelection {
        let filmID: Int
        let session: ArcadeSession
        let surface: ArcadeDiscoverySurface
    }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    private let supportingText = Color(white: 0.8)
    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Color.clear.frame(height: 1).id("arcade.top")
                            if let session = player.session {
                                if player.showingSummary { summary(session).transition(.opacity).onAppear { player.summaryVisible() } }
                                else {
                                    roundView(session)
                                        .id("\(session.runID ?? "legacy"):\(session.index)")
                                        .transition(.opacity)
                                        .onAppear { player.roundVisible() }
                                }
                            } else { lobby.transition(.opacity).onAppear { player.exposed() } }
                        }
                        .padding(20).frame(width: min(viewport.size.width, 680)).frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("arcade.scroll")
                    .onChange(of: player.session?.index) { _, _ in proxy.scrollTo("arcade.top") }
                    .onChange(of: player.session?.current.isComplete) { _, _ in proxy.scrollTo("arcade.top") }
                    .onChange(of: player.session?.current.step) { _, _ in proxy.scrollTo("arcade.top") }
                    .onChange(of: player.session?.current.kind) { _, _ in proxy.scrollTo("arcade.top") }
                    .onChange(of: player.showingSummary) { _, _ in proxy.scrollTo("arcade.top") }
                }
            }
            .background(LinearGradient(colors: [Color(red: 0.035, green: 0.10, blue: 0.15), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
            .navigationTitle("Movie Arcade").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if player.session != nil {
                        Button("Games", systemImage: "chevron.left") { navigate { player.backToGames() } }.accessibilityIdentifier("arcade.games")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }.accessibilityIdentifier("arcade.close")
                }
            }
            .sensoryFeedback(.selection, trigger: player.feedbackTick)
            .sensoryFeedback(.success, trigger: player.session?.current.isComplete) { _, complete in
                complete == true && player.session?.current.skipped == false
            }
            .navigationDestination(isPresented: $showingMovie) {
                if let discovery {
                    ItemContentDetails(title: ArcadeCatalog.film(discovery.filmID).title,
                                       id: discovery.filmID, type: .movie,
                                       onWatchlistAdded: {
                        player.discover(.added, filmID: discovery.filmID, surface: discovery.surface, session: discovery.session)
                    })
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(arcadeText("Back to Arcade"), systemImage: "chevron.left") { showingMovie = false }
                                .accessibilityIdentifier("arcade.discovery.back")
                        }
                    }
                }
            }
            .onDisappear { if !showingMovie { player.trackAbandon() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { player.trackAbandon(reason: "background") }
                else if phase == .inactive { player.suspend() }
                else if phase == .active && !showingMovie { player.roundVisible() }
            }
        }
        .tint(.mint).preferredColorScheme(.dark)
    }
    private var lobby: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A little movie magic.").font(.largeTitle.bold())
                Text("Swap scenes. Spot stars. Make connections.").foregroundStyle(supportingText)
            }
            Text("Start here · No movie trivia needed").font(.title2.bold())
            gameGrid([.memory, .scene])
            Button { navigate { player.openDaily() } } label: {
                VStack(alignment: .leading, spacing: 12) {
                    Label("DAILY MIX", systemImage: "sparkles").font(.caption.bold()).tracking(2)
                    Text(arcadeText(player.savedDaily?.isComplete == true ? "Your mix is complete!" : "Four quick games. One happy brain.")).font(.title2.bold())
                    HStack {
                        Text(arcadeText(player.savedDaily?.isComplete == true ? "See your score" : player.savedDaily == nil ? "Let’s play" : "Continue your mix")).font(.headline)
                        Spacer(); Image(systemName: "arrow.right.circle.fill").font(.title)
                    }
                }
                .foregroundStyle(.black).padding(22)
                .background(LinearGradient(colors: [.mint, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))
            }.buttonStyle(.plain).accessibilityIdentifier("arcade.daily")
            Button {
                navigate { showingAllGames.toggle() }
            } label: {
                HStack {
                    Text(arcadeText(showingAllGames ? "Fewer choices" : "All games"))
                    Spacer()
                    Image(systemName: showingAllGames ? "chevron.up" : "chevron.down")
                }.font(.headline).frame(minHeight: 48)
            }
            .accessibilityIdentifier("arcade.allGames")
            .accessibilityValue(arcadeText(showingAllGames ? "Expanded" : "Collapsed"))
            if showingAllGames {
                gameGrid(ArcadeKind.allCases.filter { ![ArcadeKind.memory, .scene].contains($0) })
                    .transition(.opacity)
            }
            Text("A 12-movie starter pack · Works offline · No timer\nDaily Mix has its own score; your Daily Puzzle streak stays separate.")
                .font(.footnote).foregroundStyle(supportingText)
        }
    }
    private func gameGrid(_ kinds: [ArcadeKind]) -> some View {
        LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : columns, spacing: 12) {
            ForEach(kinds) { kind in
                Button { navigate { player.openPractice(kind) } } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: kind.symbol).font(.title2).foregroundStyle(accent(kind)).fixedSize()
                            Spacer()
                            Image(systemName: "play.circle.fill").font(.title3).foregroundStyle(accent(kind)).fixedSize().accessibilityHidden(true)
                        }
                        Text(kind.title).font(.headline).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                        Text(teaser(kind)).font(.caption).foregroundStyle(supportingText).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading).padding(16)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent(kind).opacity(0.45)))
                }.buttonStyle(ArcadePressStyle(reduceMotion: reduceMotion)).accessibilityIdentifier("arcade.game.\(kind.rawValue)")
            }
        }
    }
    private func roundView(_ session: ArcadeSession) -> some View {
        let round = session.current
        let availablePoints = round.canFinishMatching ? round.matchingPoints ?? round.availablePoints : round.availablePoints
        return VStack(alignment: .leading, spacing: 20) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                Label(session.isDaily ? arcadeText("DAILY MIX · %@/4", String(session.index + 1)) : arcadeText("FREE PLAY"), systemImage: round.kind.symbol)
                    .font(.caption.bold()).foregroundStyle(accent(round.kind))
                Spacer()
                Text(round.isComplete ? arcadeText("%@/3 points", String(round.points)) : arcadeText(availablePoints == 1 ? "Up to %@ point" : "Up to %@ points", String(availablePoints)))
                    .font(.caption.bold()).accessibilityIdentifier("arcade.points")
            }
            if session.isDaily {
                HStack(spacing: 5) {
                    ForEach(0..<4) { i in Capsule().fill(i < session.index ? Color.mint : i == session.index ? Color.white : Color.white.opacity(0.16)).frame(height: 4) }
                }.accessibilityLabel(arcadeText("Round %@ of 4", String(session.index + 1)))
            }
            Text(round.kind.title).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("arcade.roundTitle").accessibilityAddTraits(.isHeader)
            if round.isComplete { result(round, session: session).transition(.opacity) }
            else {
                Text(round.instruction).font(.body).foregroundStyle(supportingText)
                knowledgeHelp(round)
                game(round)
                if let feedback = round.feedback, round.kind != .timeline && !(round.kind == .heist && round.awaitingNext) {
                    Label(feedback, systemImage: round.selected.count == 2 ? "arrow.uturn.backward" : "lightbulb.fill")
                        .font(.callout).foregroundStyle(.yellow).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("arcade.feedback")
                }
                secondary("Reveal & move on · 0 points", symbol: "forward.end", id: "arcade.skip") { act(.skip) }
            }
        }
    }
    @ViewBuilder private func knowledgeHelp(_ round: ArcadeRound) -> some View {
        if let clue = round.knowledgeClue {
            if round.clues.contains(clue) {
                Label(knowledgeHint(round), systemImage: clueSymbol(clue))
                    .font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("arcade.knowledgeHint")
            } else {
                Button { act(.clue(clue)) } label: {
                    HStack(spacing: 12) {
                        Label(arcadeText(clue == .cast ? "Show the cast clue" : "Show the release years"), systemImage: clueSymbol(clue))
                        Spacer(minLength: 4)
                        Text(arcadeText(round.availablePoints > 1 ? "−1 point" : "Free")).font(.caption.bold())
                    }.padding(12).frame(minHeight: 48)
                }.buttonStyle(.bordered).accessibilityIdentifier("arcade.help")
            }
        }
    }
    private func knowledgeHint(_ round: ArcadeRound) -> String {
        if round.kind == .doubleFeature { return arcadeText("Match the actor names beneath the posters.") }
        if round.knowledgeClue == .year { return arcadeText("The release years are now shown. Use them to make your choices.") }
        let film = round.kind == .heist ? round.heistFilm : round.film
        return arcadeText("Cast member: %@", ArcadeCatalog.actor(film.leadID).name)
    }
    @ViewBuilder private func game(_ round: ArcadeRound) -> some View {
        switch round.kind {
        case .directorsCut:
            VStack(alignment: .leading, spacing: 16) {
                Text(arcadeText("%@ of 3 in your cut", String(round.selected.count))).font(.headline).foregroundStyle(.mint)
                    .accessibilityIdentifier("arcade.cut.progress")
                Text(arcadeText(round.selected.isEmpty ? "Which came out first?" : "What came next?")).font(.title2.bold())
                LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                    ForEach(round.board.indices, id: \.self) { index in
                        let id = round.board[index]
                        let position = round.selected.firstIndex(of: index)
                        Button { act(.choose(id)) } label: {
                            VStack(spacing: 10) {
                                poster(id).frame(maxWidth: 140)
                                Text(ArcadeCatalog.film(id).title).font(.caption.bold())
                                    .fixedSize(horizontal: false, vertical: true)
                                if round.clues.contains(.year) && position == nil {
                                    Text(String(ArcadeCatalog.film(id).year)).font(.caption.bold()).foregroundStyle(.mint)
                                }
                                if let position {
                                    Label("\(position + 1) · \(String(ArcadeCatalog.film(id).year))", systemImage: "checkmark.circle.fill")
                                        .font(.caption.bold()).foregroundStyle(.mint)
                                }
                            }
                            .padding(10).frame(maxWidth: .infinity)
                            .background(position != nil ? Color.mint.opacity(0.12) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).disabled(position != nil || round.eliminated.contains(id))
                        .accessibilityLabel(ArcadeCatalog.film(id).title)
                        .accessibilityValue(position.map { arcadeText("Position %@, %@", String($0 + 1), String(ArcadeCatalog.film(id).year)) } ?? (round.clues.contains(.year) ? String(ArcadeCatalog.film(id).year) + ", " : "") + arcadeText(round.eliminated.contains(id) ? "Not yet" : "Unplaced"))
                        .accessibilityIdentifier("arcade.choice.\(id)")
                    }
                }
            }
        case .heist:
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(0..<3) { digit in
                        let unlocked = digit < round.step || (digit == round.step && round.awaitingNext)
                        Text(unlocked ? String(round.films[digit] % 10) : "?")
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .background(unlocked ? Color.mint.opacity(0.2) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
                            .accessibilityLabel(unlocked ? arcadeText("Digit %@: %@", String(digit + 1), String(round.films[digit] % 10)) : arcadeText("Digit %@ locked", String(digit + 1)))
                    }
                }
                Text(arcadeText("LOCK %@ OF 3", String(round.step + 1))).font(.caption.bold()).foregroundStyle(.mint)
                    .accessibilityIdentifier("arcade.heist.lock")
                if round.awaitingNext {
                    Text(round.feedback ?? arcadeText("Lock cracked!")).font(.headline).foregroundStyle(.mint)
                    primary("Next lock", id: "arcade.heist.next") { act(.nextHeist) }
                } else {
                    if round.step == 0 {
                        scene(round.heistFilm.id)
                        Text("The security camera caught this scene. Which movie?").font(.headline)
                    } else if round.step == 1 {
                        poster(round.heistFilm.id).frame(maxWidth: 100)
                        Text(arcadeText("The guard wants a cast member from %@. Who gets you through?", round.heistFilm.title)).font(.headline)
                    } else {
                        Label("THE FINAL DOSSIER", systemImage: "doc.text.magnifyingglass").foregroundStyle(.mint)
                        Text(round.heistFilm.localizedPlot).font(.title3).padding(16)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                        Text("Which film is hidden in the vault?").font(.headline)
                    }
                    choices(round, portraits: round.step == 1)
                }
            }
        case .scene:
            scene(round.film.id)
            Text(round.film.localizedPlot).font(.callout).foregroundStyle(supportingText)
            choices(round)
        case .scramble:
            scramble(round)
        case .casting:
            HStack(alignment: .center, spacing: 18) {
                poster(round.film.id).frame(width: 100)
                VStack(alignment: .leading, spacing: 8) {
                    Text(round.film.title).font(.title2.bold())
                    Text("Who’s in the cast?").foregroundStyle(supportingText)
                }
            }
            choices(round, portraits: true)
        case .timeline: timeline(round)
        case .oddOneOut:
            choices(round, posters: true)
        case .doubleFeature, .memory:
            matching(round)
        case .detective:
            scene(round.film.id, cropped: !round.clues.contains(.plot))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(ArcadeClue.allCases, id: \.self) { clue in
                    if round.clues.contains(clue) {
                        HStack(spacing: 12) {
                            if clue == .cast {
                                Image("ArcadeActor\(round.film.leadID)").resizable().scaledToFill()
                                    .frame(width: 48, height: 64).clipped().clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
                            }
                            Label(clueText(clue, round: round), systemImage: clueSymbol(clue))
                        }
                        .font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Button { act(.clue(clue)) } label: {
                            HStack {
                                Label(clueTitle(clue), systemImage: clueSymbol(clue)); Spacer()
                                Text(arcadeText(round.availablePoints > 1 ? "−1 point" : "Free")).font(.caption.bold())
                            }.padding(12).frame(minHeight: 48)
                        }.buttonStyle(.bordered).accessibilityIdentifier("arcade.clue.\(clue.rawValue)")
                    }
                }
            }
            choices(round)
        }
    }
    private func scramble(_ round: ArcadeRound) -> some View {
        VStack(spacing: 16) {
            GeometryReader { bounds in
                let tileSize = CGSize(width: max(0, (bounds.size.width - 8) / 2), height: max(0, (bounds.size.height - 8) / 2))
                let target = scrambleDrag?.location.flatMap { scrambleTarget(at: $0, tileSize: tileSize) }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    // Keep each scene section's identity as its position changes.
                    ForEach(Array(round.board.enumerated()), id: \.element) { index, _ in
                        scramblePiece(round, index: index)
                            .frame(width: tileSize.width, height: tileSize.height)
                            .overlay(RoundedRectangle(cornerRadius: 12).fill(target == index && scrambleDrag?.source != index ? Color.mint.opacity(0.3) : .clear))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(round.selected.contains(index) || target == index ? Color.mint : Color.white.opacity(0.4), lineWidth: round.selected.contains(index) || target == index ? 3 : 1))
                            .overlay(alignment: .bottomTrailing) {
                                if !round.canGuess {
                                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                        .font(.caption.bold()).padding(7).background(.black.opacity(0.65), in: Circle()).padding(7)
                                        .accessibilityHidden(true)
                                }
                            }
                            .opacity(scrambleDrag?.source == index ? 0.3 : 1)
                        .contentShape(Rectangle())
                        .disabled(round.canGuess)
                        .highPriorityGesture(scrambleGesture(round, source: index, tileSize: tileSize), including: round.canGuess ? .none : .all)
                        .simultaneousGesture(TapGesture().onEnded {
                            guard player.session?.current.seed == round.seed,
                                  player.session?.current.board == round.board else { return }
                            act(.tile(index))
                        }, including: round.canGuess ? .none : .all)
                        .accessibilityElement(children: .ignore)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { act(.tile(index)) }
                        .accessibilityLabel(arcadeText("Position %@, scene section %@", String(index + 1), String(round.board[index] + 1)))
                        .accessibilityHint(arcadeText("Tap this tile, then another tile to swap them. Arrange sections 1 through 4."))
                        .accessibilityAddTraits(round.selected.contains(index) ? .isSelected : [])
                        .accessibilityIdentifier("arcade.tile.\(index)")
                    }
                }
                .overlay {
                    if let drag = scrambleDrag {
                        scramblePiece(round, index: drag.source)
                            .frame(width: tileSize.width, height: tileSize.height)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.mint, lineWidth: 3))
                            .scaleEffect(reduceMotion ? 1 : 1.04)
                            .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                            .position(drag.location ?? CGPoint(x: CGFloat(drag.source % 2) * (tileSize.width + 8) + tileSize.width / 2,
                                                             y: CGFloat(drag.source / 2) * (tileSize.height + 8) + tileSize.height / 2))
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .coordinateSpace(name: "scramble.board")
            }
            .aspectRatio(1.5, contentMode: .fit)
            if round.canGuess {
                Text("Scene restored!").font(.headline).foregroundStyle(.mint)
                Text(round.film.localizedPlot).font(.callout).foregroundStyle(supportingText)
                choices(round)
            } else {
                Label(arcadeText(round.selected.isEmpty ? "Hold & drag, or tap two tiles" : "Now tap the tile to swap it with."), systemImage: "hand.draw.fill")
                    .font(.callout).foregroundStyle(.mint)
                secondary("Assemble for me · −1 point", symbol: "square.grid.2x2.fill", id: "arcade.assemble") { act(.assemble) }
            }
        }
    }
    private func scramblePiece(_ round: ArcadeRound, index: Int) -> some View {
        GeometryReader { size in
            Image("MovieQuiz\(round.film.id)").resizable().scaledToFill()
                .frame(width: size.size.width * 2, height: size.size.height * 2)
                .offset(x: -CGFloat(round.board[index] % 2) * size.size.width, y: -CGFloat(round.board[index] / 2) * size.size.height)
        }
        .clipped().clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
    }
    private func scrambleTarget(at point: CGPoint, tileSize: CGSize) -> Int? {
        (0..<4).first { index in
            CGRect(x: CGFloat(index % 2) * (tileSize.width + 8), y: CGFloat(index / 2) * (tileSize.height + 8),
                   width: tileSize.width, height: tileSize.height).contains(point)
        }
    }
    private func scrambleGesture(_ round: ArcadeRound, source: Int, tileSize: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("scramble.board")))
            .updating($scrambleDrag) { value, state, _ in
                switch value {
                case .first(true): state = ScrambleDrag(source: source, location: nil)
                case .second(true, let drag): state = ScrambleDrag(source: source, location: drag?.location)
                default: break
                }
            }
            .onEnded { value in
                guard player.session?.current.seed == round.seed,
                      player.session?.current.board == round.board else { return }
                if case .second(true, let drag?) = value,
                   let target = scrambleTarget(at: drag.location, tileSize: tileSize) {
                    act(.swapTiles(from: source, to: target))
                }
            }
    }
    private func timeline(_ round: ArcadeRound) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                poster(round.film.id).frame(width: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text("THE ANCHOR").font(.caption.bold()).foregroundStyle(.mint)
                    Text(round.film.title).font(.headline)
                    Text(String(round.film.year)).font(.title.bold().monospacedDigit())
                }
                Spacer()
            }.padding(14).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            let incoming = ArcadeCatalog.film(round.films[round.step + 1])
            Text(arcadeText("Movie %@ of 3", String(round.step + 1))).font(.caption).foregroundStyle(supportingText)
            poster(incoming.id).frame(maxWidth: 120)
            Text(incoming.title).font(.title3.bold()).multilineTextAlignment(.center)
            if round.clues.contains(.year) { Text(String(incoming.year)).font(.title2.bold()).foregroundStyle(.mint) }
            if let feedback = round.feedback {
                Text(feedback).font(.callout).foregroundStyle(.yellow)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("arcade.feedback")
            }
            if round.awaitingNext {
                primary("Next movie", id: "arcade.timeline.next") { act(.nextTimeline) }
            } else {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    primary(arcadeText("Before %@", String(round.film.year)), id: "arcade.before") { act(.timeline(false)) }
                    primary(arcadeText("After %@", String(round.film.year)), id: "arcade.after") { act(.timeline(true)) }
                }
            }
            if round.step > 0 || round.awaitingNext {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR TIMELINE").font(.caption.bold()).foregroundStyle(.mint)
                    ForEach(round.films.prefix(round.step + (round.awaitingNext ? 2 : 1)).map { ArcadeCatalog.film($0) }.sorted { $0.year < $1.year }) { film in
                        Text("\(String(film.year))  ·  \(film.title)").font(.callout)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    private func matching(_ round: ArcadeRound) -> some View {
        VStack(spacing: 16) {
            Text(arcadeText("%@ of 3 pairs", String(round.matched.count / 2))).font(.headline).foregroundStyle(.mint).accessibilityIdentifier("arcade.pairs")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 12) {
                ForEach(round.board.indices, id: \.self) { index in
                    let visible = round.kind == .doubleFeature || round.selected.contains(index) || round.matched.contains(index)
                    Button { act(.card(index)) } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                // Keep both faces mounted so the button label can crossfade.
                                poster(round.board[index])
                                    .saturation(round.kind == .memory ? 1.18 : 1)
                                    .contrast(round.kind == .memory ? 1.06 : 1)
                                    .brightness(round.kind == .memory ? 0.025 : 0)
                                    .opacity(visible ? 1 : 0)
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient(colors: [.purple, .pink, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .aspectRatio(2.0/3, contentMode: .fit)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.35), lineWidth: 1).padding(6)
                                        }
                                        .overlay {
                                            VStack(spacing: 10) {
                                                Image(systemName: "sparkles").font(.caption).foregroundStyle(.yellow)
                                                Image(systemName: "film.fill").font(.largeTitle).foregroundStyle(.white)
                                                Label {
                                                    Text(arcadeText("Tap to flip"))
                                                        .fixedSize(horizontal: false, vertical: true)
                                                } icon: {
                                                    Image(systemName: "hand.tap.fill")
                                                }
                                                    .font(.caption2.bold()).multilineTextAlignment(.center)
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                                    .background(.black.opacity(0.65), in: Capsule())
                                            }.padding(8)
                                        }
                                        .accessibilityHidden(true)
                                        .opacity(visible ? 0 : 1)
                            }
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: visible)
                            .overlay(alignment: .topTrailing) {
                                if round.matched.contains(index) {
                                    Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.black, .mint)
                                        .background(.mint, in: Circle()).padding(5).shadow(radius: 3).accessibilityHidden(true)
                                        .transition(.opacity)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(round.selected.contains(index) || round.matched.contains(index) ? Color.mint : Color.white.opacity(0.4), lineWidth: round.selected.contains(index) || round.matched.contains(index) ? 3 : 1))
                            .shadow(color: round.matched.contains(index) ? .mint.opacity(0.22) : .pink.opacity(0.15), radius: 6, y: 3)
                            if round.kind == .doubleFeature { Text(ArcadeCatalog.film(round.board[index]).title).font(.caption.bold()).lineLimit(typeSize.isAccessibilitySize ? nil : 3).fixedSize(horizontal: false, vertical: true).frame(minHeight: 32) }
                            if round.kind == .doubleFeature && round.clues.contains(.cast) {
                                Text(ArcadeRound.pairActorName(round.pairKey(round.board[index])))
                                    .font(.caption).foregroundStyle(.mint).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .buttonStyle(ArcadePressStyle(reduceMotion: reduceMotion)).disabled(round.matched.contains(index) || round.selected.count == 2 || round.selected.contains(index))
                    .accessibilityLabel(visible ? ArcadeCatalog.film(round.board[index]).title + (round.kind == .doubleFeature && round.clues.contains(.cast) ? ", " + ArcadeRound.pairActorName(round.pairKey(round.board[index])) : "") : arcadeText("Face-down card %@", String(index + 1)))
                    .accessibilityValue(arcadeText(round.matched.contains(index) ? "Matched" : round.selected.contains(index) ? "Selected" : ""))
                    .accessibilityHint(round.kind == .memory && !visible ? arcadeText("Tap to flip") : "")
                    .accessibilityIdentifier("arcade.card.\(index)")
                }
            }
            if round.selected.count == 2 {
                primary(arcadeText(round.kind == .memory ? "Turn them over & try again" : "Try another pair"), id: "arcade.retryPair") { act(.clearMismatch) }
            }
            if round.kind == .memory && round.canGuess {
                Text("All pairs found!").font(.title2.bold()).foregroundStyle(.mint)
                primary(arcadeText("Finish round · %@ points", String(round.matchingPoints ?? round.availablePoints)), id: "arcade.memory.finish") { act(.finishMatching) }
                Text(arcadeText("Optional bonus: when did %@ come out?", round.film.title)).font(.headline)
                Text("Your matching points are safe either way.").font(.callout).foregroundStyle(supportingText)
                choices(round)
            }
        }
    }
    private func choices(_ round: ArcadeRound, portraits: Bool = false, posters: Bool = false) -> some View {
        LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(round.kind == .heist ? round.heistOptions : round.options, id: \.self) { id in
                let eliminated = round.eliminated.contains(id)
                Button { act(.choose(id)) } label: {
                    VStack(spacing: 9) {
                        if portraits {
                            GeometryReader { bounds in
                                Image("ArcadeActor\(id)").resizable().scaledToFit()
                                    .frame(width: bounds.size.width, height: bounds.size.height, alignment: .top)
                            }
                            .frame(height: 145).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                            .allowsHitTesting(false).accessibilityHidden(true)
                        }
                        if posters { poster(id).frame(maxWidth: 100) }
                        if round.kind == .oddOneOut && round.clues.contains(.year) {
                            Text(String(ArcadeCatalog.film(id).year)).font(.caption.bold()).foregroundStyle(.mint)
                        }
                        HStack(spacing: 6) {
                            if !eliminated {
                                Image(systemName: "circle").foregroundStyle(.mint).accessibilityHidden(true)
                            }
                            Text(optionTitle(id, kind: round.kind == .heist && round.step == 1 ? .casting : round.kind)).font(.headline).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            if eliminated { Image(systemName: "xmark.circle").accessibilityHidden(true) }
                        }.frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                    }
                    .padding(14).frame(maxWidth: .infinity, minHeight: 64)
                    .foregroundStyle(eliminated ? .secondary : .primary)
                    .background(.white.opacity(eliminated ? 0.025 : 0.08), in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(eliminated ? 0.1 : 0.3)))
                    .contentShape(Rectangle())
                }.buttonStyle(ArcadePressStyle(reduceMotion: reduceMotion)).disabled(eliminated)
                .accessibilityLabel(optionTitle(id, kind: round.kind == .heist && round.step == 1 ? .casting : round.kind))
                .accessibilityValue(choiceAccessibilityValue(round, id: id))
                .accessibilityIdentifier("arcade.choice.\(id)")
            }
        }
    }
    private func choiceAccessibilityValue(_ round: ArcadeRound, id: Int) -> String {
        var values: [String] = []
        if round.kind == .oddOneOut && round.clues.contains(.year) { values.append(String(ArcadeCatalog.film(id).year)) }
        if round.eliminated.contains(id) { values.append(arcadeText("Ruled out")) }
        return values.joined(separator: ", ")
    }
    private func result(_ round: ArcadeRound, session: ArcadeSession) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 15)) : AnyLayout(HStackLayout(spacing: 15))) {
                Image(systemName: round.skipped ? "lightbulb.fill" : round.kind == .heist ? "lock.open.fill" : "star.circle.fill")
                    .font(.system(size: 52)).foregroundStyle(round.skipped ? .yellow : .mint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(arcadeText(round.skipped ? "Now you know!" : round.kind == .heist ? "You’re in." : round.points == 3 ? "That’s movie magic." : "Nicely played.")).font(.title2.bold())
                    Text(round.skipped ? arcadeText("A fresh round is waiting.") : arcadeText("%@ of 3 points earned", String(round.points))).foregroundStyle(supportingText)
                }
            }.accessibilityIdentifier("arcade.result")
            if round.kind == .heist && !round.skipped {
                Text(round.vaultCode).font(.system(size: 54, weight: .bold, design: .monospaced))
                    .tracking(12).foregroundStyle(.mint).frame(maxWidth: .infinity)
                    .padding(.vertical, 16).background(.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel(arcadeText("Vault code %@", round.vaultCode))
                    .accessibilityIdentifier("arcade.heist.code")
            }
            if round.kind != .doubleFeature && round.kind != .timeline && round.kind != .directorsCut { scene(round.kind == .heist ? round.films[2] : round.kind == .oddOneOut ? round.answer : round.film.id) }
            Text(round.reveal).font(.body).fixedSize(horizontal: false, vertical: true)
            if session.isDaily {
                primary(session.isComplete ? arcadeText("See my mix score") : arcadeText("Next: %@", session.rounds[session.index + 1].kind.title), id: "arcade.next") { navigate { player.next() } }
            } else {
                primary("Play another", id: "arcade.playAgain") { navigate { player.openPractice(round.kind, fresh: true) } }
                secondary("Try a different game", id: "arcade.differentGame") { navigate { player.backToGames() } }
            }
            discoverySection(round.discoveryFilmIDs, session: session, surface: .result)
        }
    }
    private func summary(_ session: ArcadeSession) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "sparkles").font(.system(size: 48)).foregroundStyle(.mint)
            Text("That’s a wrap!").font(.largeTitle.bold())
            Text("\(session.points) / \(session.maximumPoints)").font(.system(size: 56, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1).accessibilityIdentifier("arcade.summaryScore")
            Text("Four games. A little more movie magic in your day.").foregroundStyle(supportingText)
            ForEach(Array(session.rounds.enumerated()), id: \.offset) { _, round in
                (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())) {
                    Label(round.kind.title, systemImage: round.kind.symbol)
                    Spacer()
                    Text(round.skipped ? arcadeText("Revealed") : "\(round.points)/3").foregroundStyle(round.skipped ? Color.secondary : Color.mint)
                }.font(.callout).padding(12).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            ShareLink(item: arcadeText("Movie Arcade · %@\n%@/%@ across four movie games!\n", session.day, String(session.points), String(session.maximumPoints)) + session.rounds.map { "\($0.kind.title): \($0.skipped ? arcadeText("revealed") : "\($0.points)/3")" }.joined(separator: "\n")) {
                Label("Share my mix", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 48)
            }.buttonStyle(.bordered).accessibilityIdentifier("arcade.share")
            primary("Keep playing", id: "arcade.keepPlaying") { navigate { player.backToGames() } }
            Text("A fresh mix tomorrow. Free play is always here.").font(.footnote).foregroundStyle(supportingText)
            discoverySection(session.discoveryFilmIDs, session: session, surface: .summary)
        }
    }
    private func discoverySection(_ films: [Int], session: ArcadeSession, surface: ArcadeDiscoverySurface) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save it for movie night").font(.title3.bold())
            Text("Explore the movies you just played. Add a favorite to your watchlist.")
                .font(.subheadline).foregroundStyle(supportingText).fixedSize(horizontal: false, vertical: true)
            ForEach(films, id: \.self) { id in
                let film = ArcadeCatalog.film(id)
                Button {
                    discovery = DiscoverySelection(filmID: id, session: session, surface: surface)
                    player.discover(.opened, filmID: id, surface: surface, session: session)
                    showingMovie = true
                } label: {
                    (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 14))) {
                        poster(id).frame(width: typeSize.isAccessibilitySize ? 72 : 60)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(film.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text(String(film.year)).font(.subheadline).foregroundStyle(supportingText)
                            Text("Movie details & watchlist").font(.caption).foregroundStyle(.mint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !typeSize.isAccessibilitySize {
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(.mint).accessibilityHidden(true)
                        }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(arcadeText("Explore %@, %@", film.title, String(film.year)))
                .accessibilityHint("Open movie details and add to your watchlist")
                .accessibilityIdentifier("arcade.discovery.\(id)")
            }
        }.padding(.top, 8)
    }
    private func secondary(_ title: String, symbol: String? = nil, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol) }
                Text(arcadeText(title)).multilineTextAlignment(.center)
            }
            .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .foregroundStyle(.mint)
            .background(.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.mint.opacity(0.45)))
            .contentShape(Rectangle())
        }.buttonStyle(ArcadePressStyle(reduceMotion: reduceMotion)).accessibilityIdentifier(id)
    }
    private func primary(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(arcadeText(title)).font(.headline).multilineTextAlignment(.center).frame(maxWidth: .infinity, minHeight: 30).padding(12)
                .foregroundStyle(.black).background(.mint, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(ArcadePressStyle(reduceMotion: reduceMotion)).accessibilityIdentifier(id)
    }
    private func poster(_ id: Int) -> some View {
        Image("MovieQuizPoster\(id)").resizable().scaledToFit().aspectRatio(2.0/3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
    }
    private func scene(_ id: Int, cropped: Bool = false) -> some View {
        GeometryReader { bounds in
            Image("MovieQuiz\(id)").resizable().scaledToFill()
                .frame(width: bounds.size.width, height: bounds.size.height)
                .scaleEffect(cropped ? 1.7 : 1)
        }
        .aspectRatio(1.5, contentMode: .fit).clipped().clipShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityHidden(true).allowsHitTesting(false)
    }
    private func act(_ action: ArcadeAction) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { player.act(action) }
    }
    private func navigate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2), action)
    }
    private func optionTitle(_ id: Int, kind: ArcadeKind) -> String {
        if kind == .casting { return ArcadeCatalog.actor(id).name }
        if kind == .memory { return String(id) }
        return ArcadeCatalog.film(id).title
    }
    private func clueText(_ clue: ArcadeClue, round: ArcadeRound) -> String {
        switch clue {
        case .plot: round.film.localizedPlot
        case .cast: arcadeText("Starring %@", ArcadeCatalog.actor(round.film.leadID).name)
        case .year: arcadeText("Released in %@", String(round.film.year))
        }
    }
    private func clueSymbol(_ clue: ArcadeClue) -> String { clue == .plot ? "text.book.closed" : clue == .cast ? "person.fill" : "calendar" }
    private func clueTitle(_ clue: ArcadeClue) -> String { arcadeText(clue == .plot ? "Open the plot file" : clue == .cast ? "Reveal a cast member" : "Find the release year") }
    private func accent(_ kind: ArcadeKind) -> Color {
        switch kind {
        case .scene, .scramble, .heist: .mint
        case .casting, .doubleFeature: .orange
        case .timeline, .oddOneOut, .directorsCut: .cyan
        case .detective, .memory: .purple
        }
    }
    private func teaser(_ kind: ArcadeKind) -> String {
        switch kind {
        case .directorsCut: arcadeText("Put a triple feature in order")
        case .heist: arcadeText("Crack the movie vault")
        case .scene: arcadeText("Name that scene")
        case .scramble: arcadeText("Piece the scene together")
        case .casting: arcadeText("Put a face to the film")
        case .timeline: arcadeText("Travel through movie history")
        case .oddOneOut: arcadeText("Spot the one that doesn’t belong")
        case .doubleFeature: arcadeText("Connect the stars")
        case .detective: arcadeText("Follow your own clues")
        case .memory: arcadeText("Flip, remember, match")
        }
    }
}

private struct ArcadePressStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
#endif
