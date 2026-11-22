import Flutter
import UIKit

/// Deep links: the URL the app was opened with, a stream of links
/// received while running, launching (`openURL`) and probing (`canOpenURL`) other apps.
public class CommunityFlutterDeeplinkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, FlutterSceneLifeCycleDelegate {
  private var sink: FlutterEventSink?
  private var lastDeepLinkUrl: String?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CommunityFlutterDeeplinkPlugin()
    let channel = FlutterMethodChannel(name: "community_flutter_deeplink", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(name: "community_flutter_deeplink/links", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getLastDeepLink":
      result(lastDeepLinkUrl)
    case "launchApp":
      guard let args = call.arguments as? [String: Any], let s = args["url"] as? String, let url = URL(string: s) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "url is required", details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { ok in result(ok) }  // false: no app handles the link
    case "isAppInstalled":
      guard let args = call.arguments as? [String: Any], let s = args["url"] as? String, let url = URL(string: s) else {
        result(false)
        return
      }
      result(UIApplication.shared.canOpenURL(url))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func receive(_ url: URL, emit: Bool) {
    lastDeepLinkUrl = url.absoluteString
    if emit { sink?(url.absoluteString) }
  }

  // Application delegate (apps without a scene manifest).
  public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    receive(url, emit: true)
    return false
  }

  public func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      receive(url, emit: true)
    }
    return false
  }

  // Scene delegate (UIApplicationSceneManifest apps, which all three Flutter apps are).
  public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    guard let connectionOptions = connectionOptions else { return false }
    if let url = connectionOptions.urlContexts.first?.url { receive(url, emit: false) }
    if let url = connectionOptions.userActivities.first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL {
      receive(url, emit: false)
    }
    return false
  }

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = URLContexts.first?.url else { return false }
    receive(url, emit: true)
    return false
  }

  public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      receive(url, emit: true)
    }
    return false
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
