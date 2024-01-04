import ObjectiveC
import GoogleMobileAds

class AdCoordinator: NSObject, GADFullScreenContentDelegate {
    var interstitial: GADInterstitialAd? = nil
    @Published var isLoaded: Bool = false
        
    override init() {
        print("AdCoordinator init()")
        
        super.init()
        
        self.loadAd()
   }
   
  func loadAd() {
      let request = GADRequest()
      GADInterstitialAd.load(withAdUnitID:"ca-app-pub-3940256099942544/4411468910",
                                  request: request,
                        completionHandler: { [self] ad, error in
                          if let error = error {
                            print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                            return
                          }
                          interstitial = ad
                          interstitial?.fullScreenContentDelegate = self
                        })
  }

  func presentAd(from viewController: UIViewController) {
      print("\(#function) called")
//    guard let fullScreenAd = ad else {
//      return print("Ad wasn't ready")
//    }
      
      interstitial?.present(fromRootViewController: viewController)
  }
    
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adDidRecordClick(_ ad: GADFullScreenPresentingAd) {
      print("\(#function) called")
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
      print("\(#function) called")
    }

    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adWillDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
      print("\(#function) called")
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
      print("\(#function) called")
    }
    

}
