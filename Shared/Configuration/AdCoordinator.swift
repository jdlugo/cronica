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
      GADInterstitialAd.load(withAdUnitID:"ca-app-pub-7891478850122465/6565020438",
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

  func presentAd() {
      print("\(#function) called")
      let scenes = UIApplication.shared.connectedScenes
      let windowScene = scenes.first as? UIWindowScene
      let window = windowScene?.windows.first
      let root = window?.rootViewController
      
      interstitial?.present(fromRootViewController: root!)
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
