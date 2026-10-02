import Foundation

/// Migrate to extension based formatters and functions to get release dates and format the result.
class DatesManager {
	static let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		decoder.dateDecodingStrategy = .formatted(dateFormatter)
		return decoder 
	}()
	static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
        formatter.timeZone = .current
		formatter.dateFormat = "y,MM,dd"
		return formatter
	}()
	static let dateString: DateFormatter = {
		let formatter = DateFormatter()
        formatter.timeZone = .current
		formatter.dateStyle = .medium
		formatter.timeStyle = .none
		return formatter
	}()
	private static var releaseDateFormatter: ISO8601DateFormatter {
		let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
		formatter.formatOptions = .withFullDate
		return formatter
	}
    static func preferredReleaseRegion(
        availableRegions: [String],
        userRegion: String,
        productionRegion: String?
    ) -> String? {
        let candidates: [String?] = [userRegion, productionRegion, "US"]
        for candidate in candidates.compactMap({ $0 }).filter({ !$0.isEmpty }) {
            if let match = availableRegions.first(where: {
                $0.caseInsensitiveCompare(candidate) == .orderedSame
            }) {
                return match
            }
        }
        return nil
    }

    static func getDetailedReleaseDateFormatted(
        results: [ReleaseDatesResult],
        productionRegion: String?,
        userRegion: String = Locale.userRegion
    ) -> String? {
        guard let preferredRegion = preferredReleaseRegion(
            availableRegions: results.compactMap { $0.iso31661 },
            userRegion: userRegion,
            productionRegion: productionRegion
        ),
              let result = results.first(where: {
                  $0.iso31661?.caseInsensitiveCompare(preferredRegion) == .orderedSame
              }),
              let dates = result.releaseDates else {
            return nil
        }

        let content = dates.first(where: {
            $0.type == ReleaseDateType.theatrical.toInt
        })?.releaseDate ?? dates.first?.releaseDate
        guard let content,
              let releaseDate = releaseDateFormatter.date(from: content) else {
            return nil
        }
        return dateString.string(from: releaseDate)
    }
}
