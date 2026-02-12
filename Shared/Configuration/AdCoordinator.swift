import ObjectiveC
import GoogleMobileAds
#if os(iOS)
import UIKit
#endif

class AdCoordinator: NSObject, FullScreenContentDelegate {
    var interstitial: InterstitialAd? = nil
    @Published var isLoaded: Bool = false
        
    override init() {
        print("AdCoordinator init()")
        
        super.init()
        
        self.loadAd()
   }
   
  func loadAd() {
      let request = Request()
      InterstitialAd.load(with:"ca-app-pub-7891478850122465/6565020438",
                                  request: request,
                        completionHandler: { [weak self] ad, error in
                          guard let self else { return }
                          if let error = error {
                            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                            return
                          }
                          self.interstitial = ad
                          self.interstitial?.fullScreenContentDelegate = self
                        })
  }

  func presentAd() {
      print("\(#function) called")
#if os(iOS)
      guard let interstitial, let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let root = window.rootViewController else {
          print("[AdCoordinator] Unable to present ad: missing interstitial or rootViewController")
          return
      }
      interstitial.present(from: root)
#else
      print("[AdCoordinator] Ad presentation not supported on this platform")
#endif
  }
    

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
      print("\(#function) called")
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
      print("\(#function) called")
    }
    
    
    

}

