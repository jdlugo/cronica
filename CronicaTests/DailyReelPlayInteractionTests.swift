import Testing
@testable import StreamingNow

@MainActor
@Suite("Daily Reel play interaction")
struct DailyReelPlayInteractionTests {
    @Test("preparing a new act resets transient answers")
    func prepareResetsAnswers() {
        let interaction = DailyReelPlayInteraction()
        interaction.prepare(for: DailyReelSessionAct(id: "decode", role: .decode))
        interaction.textAnswer = "Titanic"
        interaction.prepare(for: DailyReelSessionAct(
            id: "connect",
            role: .connect,
            options: [DailyReelChoice(id: "o1", label: "Ocean")]
        ))
        #expect(interaction.textAnswer.isEmpty)
        #expect(interaction.selectedChoiceID == nil)
    }

    @Test("each act role produces its server answer shape")
    func roleAnswers() {
        let interaction = DailyReelPlayInteraction()
        interaction.prepare(for: DailyReelSessionAct(id: "decode", role: .decode))
        interaction.textAnswer = "  Titanic  "
        #expect(interaction.answer(for: .decode) == .text("Titanic"))

        interaction.select("choice-b")
        #expect(interaction.answer(for: .connect) == .choice("choice-b"))

        interaction.prepare(for: DailyReelSessionAct(
            id: "arrange",
            role: .arrange,
            items: [
                DailyReelChoice(id: "b", label: "Second"),
                DailyReelChoice(id: "a", label: "First")
            ]
        ))
        #expect(interaction.answer(for: .arrange) == .order(["b", "a"]))
    }

    @Test("accessible ordering controls change only adjacent positions")
    func ordering() {
        let interaction = DailyReelPlayInteraction()
        interaction.prepare(for: DailyReelSessionAct(
            id: "arrange",
            role: .arrange,
            items: [
                DailyReelChoice(id: "a", label: "A"),
                DailyReelChoice(id: "b", label: "B"),
                DailyReelChoice(id: "c", label: "C")
            ]
        ))
        interaction.move("c", by: -1)
        #expect(interaction.arrangedItems.map(\.id) == ["a", "c", "b"])
        interaction.move("a", by: -1)
        #expect(interaction.arrangedItems.map(\.id) == ["a", "c", "b"])
    }
}
