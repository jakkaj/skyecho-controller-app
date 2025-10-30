import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Fetch API key from Info.plist (set per build config via xcconfig).
    let key = Bundle.main.object(forInfoDictionaryKey: "GMS_API_KEY") as? String
    guard let apiKey = key, !apiKey.isEmpty else {
      fatalError("Missing GMS_API_KEY in Info.plist")
    }

    GMSServices.provideAPIKey(apiKey)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
