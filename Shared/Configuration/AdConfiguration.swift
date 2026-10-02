import Foundation

#if os(iOS)
import AdmobSwiftUI
import GoogleMobileAds
import SwiftUI
import UIKit
#endif

/// Centralized configuration for all AdMob ad units and settings.
enum AdConfiguration {
    /// AdMob ad unit IDs
    enum AdUnitID {
        static let native = "ca-app-pub-7891478850122465/8171033829"
        static let interstitial = "ca-app-pub-7891478850122465/6565020438"
        static let rewarded = "ca-app-pub-7891478850122465/1859860932"
        static let appOpen = "ca-app-pub-7891478850122465/6721664164"
    }

    /// Keep native ads stable long enough to avoid disruptive content changes.
    static let nativeRefreshInterval: Int = 60

    /// Delay before first native ad request on a screen (seconds).
    static let nativeInitialRequestDelay: TimeInterval = 0

    /// Minimum seconds between interstitial presentations
    static let interstitialCooldown: TimeInterval = 150

    /// Minimum seconds between app open ad presentations
    static let appOpenCooldown: TimeInterval = 180

    /// App open frequency window that enforces max per session.
    static let appOpenSessionWindow: TimeInterval = 900
    /// Maximum app-open ads per app session window.
    static let maxAppOpenPresentsPerSession: Int = 1

    /// How often users can see interstitials within a session.
    static let interstitialSessionWindow: TimeInterval = 1_200
    static let maxInterstitialPresentsPerSession: Int = 1

    /// Present an engagement interstitial on every Nth qualifying content action.
    static let engagementInterstitialInterval = 4

    /// Daily Puzzle earns a monetization opportunity only after three completed rounds.
    static let puzzleCompletedInterstitialInterval = 3
}

enum InterstitialEngagementTrigger: String {
    case detailOpen = "detail_open"
    case trailerOpen = "trailer_open"
    case puzzleCompleted = "puzzle_completed"

    var presentationInterval: Int {
        switch self {
        case .detailOpen, .trailerOpen:
            AdConfiguration.engagementInterstitialInterval
        case .puzzleCompleted:
            AdConfiguration.puzzleCompletedInterstitialInterval
        }
    }
}

enum PuzzleAdPolicy {
    static func shouldShowNativeAd(
        hasPurchasedTipJar: Bool,
        monetizationDisabled: Bool
    ) -> Bool {
        !hasPurchasedTipJar && !monetizationDisabled
    }
}

enum HomeAdPolicy {
    static func shouldShowNativeAd(
        hasPurchasedTipJar: Bool,
        monetizationDisabled: Bool,
        isOverlayPresented: Bool = false
    ) -> Bool {
        !hasPurchasedTipJar && !monetizationDisabled && !isOverlayPresented
    }
}

enum DetailAdPolicy {
    static func shouldShowNativeAd(
        hasPurchasedTipJar: Bool,
        monetizationDisabled: Bool
    ) -> Bool {
        !hasPurchasedTipJar && !monetizationDisabled
    }
}

enum SearchAdPolicy {
    static func shouldShowNativeAd(
        hasPurchasedTipJar: Bool,
        monetizationDisabled: Bool,
        resultCount: Int
    ) -> Bool {
        resultCount > 0 && !hasPurchasedTipJar && !monetizationDisabled
    }
}

#if os(iOS)
/// Native card renderer that keeps every registered Google ad asset inside the
/// `NativeAdView` bounds. The third-party card renderer can place advertiser
/// assets outside those bounds on iPad, which the AdMob validator rejects.
@MainActor
struct CronicaNativeAdCardView: UIViewRepresentable {
    @ObservedObject var nativeViewModel: NativeAdViewModel

    func makeUIView(context: Context) -> CronicaNativeAdCardContainer {
        CronicaNativeAdCardContainer(frame: .zero)
    }

    func updateUIView(_ nativeAdView: CronicaNativeAdCardContainer, context: Context) {
        nativeAdView.render(nativeViewModel.nativeAd)
    }
}

@MainActor
final class CronicaNativeAdCardContainer: GoogleMobileAds.NativeAdView {
    private let mediaAssetView = GoogleMobileAds.MediaView()
    private let iconImageView = UIImageView()
    private let headlineLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let bodyLabel = UILabel()
    private let callToActionButton = UIButton(type: .system)
    private let attributionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViewHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureViewHierarchy()
    }

    func render(_ ad: GoogleMobileAds.NativeAd?) {
        guard let ad else { return }

        headlineLabel.text = ad.headline
        mediaAssetView.mediaContent = ad.mediaContent

        bodyLabel.text = ad.body
        bodyLabel.isHidden = ad.body == nil

        iconImageView.image = ad.icon?.image
        iconImageView.isHidden = ad.icon == nil

        advertiserLabel.text = ad.advertiser
        advertiserLabel.isHidden = ad.advertiser == nil

        callToActionButton.setTitle(ad.callToAction, for: .normal)
        callToActionButton.isHidden = ad.callToAction == nil

        // Register only after every asset has been populated. Re-registering an
        // unchanged ad can produce duplicate impression bookkeeping.
        if nativeAd !== ad {
            nativeAd = ad
        }
    }

    private func configureViewHierarchy() {
        clipsToBounds = true
        layer.cornerRadius = 12

        mediaAssetView.contentMode = .scaleAspectFill
        mediaAssetView.clipsToBounds = true

        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 8

        headlineLabel.font = .preferredFont(forTextStyle: .headline)
        headlineLabel.numberOfLines = 1
        headlineLabel.lineBreakMode = .byTruncatingTail

        advertiserLabel.font = .preferredFont(forTextStyle: .caption1)
        advertiserLabel.textColor = .secondaryLabel
        advertiserLabel.numberOfLines = 1
        advertiserLabel.lineBreakMode = .byTruncatingTail
        advertiserLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.lineBreakMode = .byTruncatingTail

        callToActionButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        callToActionButton.backgroundColor = .systemBlue
        callToActionButton.tintColor = .white
        callToActionButton.layer.cornerRadius = 8
        callToActionButton.isUserInteractionEnabled = false

        attributionLabel.text = "AD"
        attributionLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        attributionLabel.textColor = .white
        attributionLabel.textAlignment = .center
        attributionLabel.backgroundColor = .systemOrange
        attributionLabel.layer.cornerRadius = 3
        attributionLabel.clipsToBounds = true

        let advertiserRow = UIStackView(arrangedSubviews: [attributionLabel, advertiserLabel])
        advertiserRow.axis = .horizontal
        advertiserRow.alignment = .center
        advertiserRow.spacing = 6

        let textStack = UIStackView(arrangedSubviews: [headlineLabel, advertiserRow])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 3

        let identityRow = UIStackView(arrangedSubviews: [iconImageView, textStack])
        identityRow.axis = .horizontal
        identityRow.alignment = .center
        identityRow.spacing = 8

        let detailStack = UIStackView(arrangedSubviews: [identityRow, bodyLabel, callToActionButton])
        detailStack.axis = .vertical
        detailStack.alignment = .fill
        detailStack.spacing = 6
        detailStack.isLayoutMarginsRelativeArrangement = true
        detailStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)

        let contentStack = UIStackView(arrangedSubviews: [mediaAssetView, detailStack])
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        [mediaAssetView, iconImageView, attributionLabel, callToActionButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            mediaAssetView.heightAnchor.constraint(equalToConstant: 150),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            attributionLabel.widthAnchor.constraint(equalToConstant: 25),
            attributionLabel.heightAnchor.constraint(equalToConstant: 16),
            callToActionButton.heightAnchor.constraint(equalToConstant: 40),
        ])

        headlineView = headlineLabel
        advertiserView = advertiserLabel
        bodyView = bodyLabel
        iconView = iconImageView
        callToActionView = callToActionButton
        mediaView = mediaAssetView
    }
}
#endif
