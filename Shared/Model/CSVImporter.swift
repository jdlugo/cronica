import Foundation
import CoreData

struct CSVImporter {
    enum CSVFormat {
        case cronica
        case letterboxd
    }

    struct ImportResult {
        var added: Int = 0
        var skipped: Int = 0
        var failed: Int = 0
    }

    @MainActor
    static func importCSV(_ csvString: String, format: CSVFormat = .cronica) async -> ImportResult {
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return ImportResult() }

        let dataLines = Array(lines.dropFirst()) // Skip header
        var result = ImportResult()
        let persistence = PersistenceController.shared

        for line in dataLines {
            let columns = parseCSVLine(line)
            let title: String
            switch format {
            case .cronica:
                guard columns.count >= 2 else { result.failed += 1; continue }
                title = columns[0]
            case .letterboxd:
                // Letterboxd CSV format: Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
                guard columns.count >= 2 else { result.failed += 1; continue }
                title = columns.count > 1 ? columns[1] : columns[0]
            }

            do {
                let searchResults = try await NetworkService.shared.search(query: title, page: "1")
                let matched: SearchItemContent? = searchResults.first { item in
                    item.mediaType == "movie" || item.mediaType == "tv"
                }
                guard let matched else {
                    result.failed += 1
                    continue
                }

                let contentType: MediaType = matched.mediaType == "tv" ? .tvShow : .movie
                let item = try await NetworkService.shared.fetchItem(id: matched.id, type: contentType)

                if persistence.isItemSaved(id: item.itemContentID) {
                    result.skipped += 1
                } else {
                    persistence.save(item)
                    result.added += 1
                }
            } catch {
                result.failed += 1
            }
        }

        return result
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields = [String]()
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    static func detectFormat(from csvString: String) -> CSVFormat {
        let firstLine = csvString.components(separatedBy: .newlines).first ?? ""
        if firstLine.lowercased().contains("letterboxd") || firstLine.lowercased().contains("watched date") {
            return .letterboxd
        }
        return .cronica
    }
}
