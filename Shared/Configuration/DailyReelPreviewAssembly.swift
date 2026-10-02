#if DEBUG && os(iOS)
import Foundation

enum DailyReelPreviewAssembly {
    @MainActor
    static func makeFeature(publicationID: String, locale: String) -> DailyReelFeature {
        DailyReelFeature(
            client: PreviewDailyReelClient(publicationID: publicationID, locale: locale),
            capabilities: InMemoryDailyReelCapabilityStore(),
            publicationID: publicationID,
            locale: locale
        )
    }
}

private actor PreviewDailyReelClient: DailyReelClientProtocol {
    private let publicationID: String
    private let locale: String
    private var completedActCount = 0

    init(publicationID: String, locale: String) {
        self.publicationID = publicationID
        self.locale = locale
    }

    func start(
        publicationID: String,
        locale: String,
        mode: DailyReelSessionMode,
        scopeID: String?
    ) async throws -> DailyReelSessionEnvelope {
        completedActCount = 0
        return DailyReelSessionEnvelope(
            capability: "debug-preview-capability",
            session: projection()
        )
    }

    func resume(capability: String) async throws -> DailyReelSessionProjection {
        projection()
    }

    func submitAttempt(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        answer: DailyReelAnswer
    ) async throws -> DailyReelMutationEnvelope {
        completedActCount = min(completedActCount + 1, 3)
        return DailyReelMutationEnvelope(session: projection(), correct: true)
    }

    func requestAssist(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        kind: DailyReelAssistKind
    ) async throws -> DailyReelMutationEnvelope {
        DailyReelMutationEnvelope(
            session: projection(),
            assist: .object(["message": .string("Think blockbuster history.")])
        )
    }

    func reveal(
        capability: String,
        expectedSequence: Int,
        requestID: String
    ) async throws -> DailyReelMutationEnvelope {
        completedActCount = min(completedActCount + 1, 3)
        return DailyReelMutationEnvelope(
            session: projection(),
            reveal: .string("Answer revealed")
        )
    }

    private func projection() -> DailyReelSessionProjection {
        let acts = previewActs
        let activeIndex = min(completedActCount, acts.count - 1)
        let progress = acts.enumerated().map { index, act in
            DailyReelActProgress(
                actID: act.id,
                role: act.role,
                status: index < completedActCount ? .solved : .playing,
                incorrectAttempts: 0,
                scoreAffectingClues: 0,
                requestedClueIDs: [],
                score: index < completedActCount ? 1_000 : nil
            )
        }
        let isComplete = completedActCount == acts.count

        return DailyReelSessionProjection(
            contractVersion: "1.0",
            sessionID: "debug-preview-session",
            publicationID: publicationID,
            contentVersion: "debug-preview-v1",
            scoringVersion: "daily-reel-v1",
            configID: "debug-preview-control",
            locale: locale,
            mode: .daily,
            assignmentSource: "debug-preview",
            status: isComplete ? "completed" : "active",
            sequence: completedActCount,
            currentActIndex: activeIndex,
            theme: "Blockbuster Connections",
            currentAct: isComplete ? nil : acts[activeIndex],
            acts: progress,
            totalScore: completedActCount * 1_000,
            completedAt: isComplete ? "2026-08-28T12:00:00Z" : nil
        )
    }

    private var previewActs: [DailyReelSessionAct] {
        [
            DailyReelSessionAct(
                id: "decode-titanic",
                role: .decode,
                title: "Decode",
                prompt: "Name the movie hidden in the emoji clue.",
                emojis: ["🚢", "🧊", "💔"],
                assistOptions: previewAssists
            ),
            DailyReelSessionAct(
                id: "connect-cameron",
                role: .connect,
                title: "Connect",
                prompt: "What connects these three films?",
                options: [
                    DailyReelChoice(id: "james-cameron", label: "James Cameron"),
                    DailyReelChoice(id: "best-picture", label: "Best Picture winners"),
                    DailyReelChoice(id: "set-at-sea", label: "Set at sea")
                ],
                items: [
                    DailyReelChoice(id: "terminator-2", label: "Terminator 2"),
                    DailyReelChoice(id: "titanic", label: "Titanic"),
                    DailyReelChoice(id: "avatar", label: "Avatar")
                ],
                assistOptions: previewAssists
            ),
            DailyReelSessionAct(
                id: "arrange-cameron",
                role: .arrange,
                title: "Arrange",
                prompt: "Put these James Cameron films in release order.",
                items: [
                    DailyReelChoice(id: "avatar", label: "Avatar"),
                    DailyReelChoice(id: "terminator", label: "The Terminator"),
                    DailyReelChoice(id: "titanic", label: "Titanic")
                ],
                assistOptions: previewAssists
            )
        ]
    }

    private var previewAssists: [DailyReelAssistOption] {
        [
            DailyReelAssistOption(
                id: "title-length",
                kind: "titleLength",
                label: "Free clue",
                scoreImpact: 0
            ),
            DailyReelAssistOption(
                id: "hint",
                kind: "hint",
                label: "Stronger hint",
                scoreImpact: 150
            )
        ]
    }
}
#endif
