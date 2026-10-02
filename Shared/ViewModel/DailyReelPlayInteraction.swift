import Foundation
import Observation

@MainActor
@Observable
final class DailyReelPlayInteraction {
    private(set) var actID: String?
    var textAnswer = ""
    var selectedChoiceID: String?
    private(set) var arrangedItems: [DailyReelChoice] = []

    func prepare(for act: DailyReelSessionAct?) {
        guard actID != act?.id else { return }
        actID = act?.id
        textAnswer = ""
        selectedChoiceID = nil
        arrangedItems = act?.items ?? []
    }

    func select(_ choiceID: String) {
        selectedChoiceID = choiceID
    }

    func move(_ choiceID: String, by offset: Int) {
        guard let source = arrangedItems.firstIndex(where: { $0.id == choiceID }) else { return }
        let destination = source + offset
        guard arrangedItems.indices.contains(destination) else { return }
        arrangedItems.swapAt(source, destination)
    }

    func answer(for role: DailyReelActRole) -> DailyReelAnswer? {
        switch role {
        case .decode:
            let answer = textAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            return answer.isEmpty ? nil : .text(answer)
        case .connect:
            return selectedChoiceID.map(DailyReelAnswer.choice)
        case .arrange:
            return arrangedItems.isEmpty ? nil : .order(arrangedItems.map(\.id))
        }
    }
}
