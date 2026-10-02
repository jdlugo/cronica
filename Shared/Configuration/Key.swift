import Foundation

/// The Keys used for the TMDb API and analytics integrations.
///
/// The values for each key is defined in an environment variable.
struct Key {
    static let tmdbApi = "6c70144f4415b691e0c0ac24b68f786e"
    static let posthogProjectToken: String? = "phc_BLdyicSixZuappyemExRRxzABikUHqvhyskpTjDYZGkX"
    static let authorizationHeader: String? = ""
    static let firebaseProjectID = "admob-app-id-9658087638"
    static let firebaseWebAPIKey = "AIzaSyAdt_EM52cUKuMTsPyKyQJUYiawde2pOjY"
    static let dailyPuzzleLatestURL: URL? = URL(string: "https://us-central1-admob-app-id-9658087638.cloudfunctions.net/getLatestDailyPuzzle")
    static let dailyPuzzleRandomURL: URL? = URL(string: "https://us-central1-admob-app-id-9658087638.cloudfunctions.net/getRandomDailyPuzzle")
    static let dailyPuzzleAdminConfigURL: URL? = URL(string: "https://us-central1-admob-app-id-9658087638.cloudfunctions.net/updateDailyPuzzleAdminConfig")
    static let dailyPuzzleAdminTestPushURL: URL? = URL(string: "https://us-central1-admob-app-id-9658087638.cloudfunctions.net/sendDailyPuzzleTestPush")
    static let dailyReelAPIBaseURL: URL? = URL(
        string: "https://us-central1-admob-app-id-9658087638.cloudfunctions.net/dailyReelAPI/"
    )
    static let dailyPuzzleFirestoreLatestURL: URL? = URL(
        string: "https://firestore.googleapis.com/v1/projects/\(firebaseProjectID)/databases/(default)/documents/dailyPuzzles/latest?key=\(firebaseWebAPIKey)"
    )
    static let dailyPuzzleFirestoreCollectionURL: URL? = URL(
        string: "https://firestore.googleapis.com/v1/projects/\(firebaseProjectID)/databases/(default)/documents/dailyPuzzles?key=\(firebaseWebAPIKey)"
    )
}
