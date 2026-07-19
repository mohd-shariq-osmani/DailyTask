import Flutter
import UIKit
import WidgetKit

private var channelReference: FlutterMethodChannel?

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.dailytask/widget",
                                        binaryMessenger: controller.binaryMessenger)
      channelReference = channel
      
      // Register Darwin notification observer to receive instant widget updates
      let center = CFNotificationCenterGetDarwinNotifyCenter()
      CFNotificationCenterAddObserver(
          center,
          nil,
          { (center, observer, name, object, userInfo) in
              DispatchQueue.main.async {
                  channelReference?.invokeMethod("widgetUpdated", arguments: nil)
              }
          },
          "com.dailytask.widget.update" as CFString,
          nil,
          .deliverImmediately
      )
      
      channel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "refreshWidget" {
          if let jsonString = call.arguments as? String {
              let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
              defaults?.set(jsonString, forKey: "widget_data")
              defaults?.synchronize()
          }
          if #available(iOS 14.0, *) {
              WidgetCenter.shared.reloadAllTimelines()
          }
          result(nil)
        } else if call.method == "getWidgetData" {
          let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
          let jsonString = defaults?.string(forKey: "widget_data")
          result(jsonString)
        } else if call.method == "refreshRemindersWidget" {
          if let jsonString = call.arguments as? String {
              let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
              defaults?.set(jsonString, forKey: "reminders_data")
              defaults?.synchronize()
          }
          if #available(iOS 14.0, *) {
              WidgetCenter.shared.reloadAllTimelines()
          }
          result(nil)
        } else if call.method == "getRemindersData" {
          let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
          let jsonString = defaults?.string(forKey: "reminders_data")
          result(jsonString)
        } else {
          result(FlutterMethodNotImplemented)
        }
      })
    }

    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
