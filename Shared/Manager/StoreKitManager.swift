import StoreKit

/// Compatibility for previous buyers. The app no longer offers purchases.
enum LegacyAdFreeEntitlements {
    static let productID = "com.dlugokecki.qscan.adfree"

    static func preservesBenefit(existingFlag: Bool, verifiedProductIDs: Set<String>) -> Bool {
        existingFlag || verifiedProductIDs.contains(productID)
    }

    @MainActor
    static func restorePreviousBenefit() async {
        var ownedIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                ownedIDs.insert(transaction.productID)
            }
        }
        if preservesBenefit(existingFlag: SettingsStore.shared.hasPurchasedTipJar, verifiedProductIDs: ownedIDs) {
            SettingsStore.shared.hasPurchasedTipJar = true
        }
    }
}
