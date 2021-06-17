import UserNotifications
import SwiftUI
import Path
import os

@main
class App: SwiftUI.App, SynctronDelegate {
    required init() {
        synctron = Synctron(logger: logger)
        registerAsLoginItem()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if let error = error {
                self.logger.error("\("\(error)", privacy: .public)")
            }
        }
    }

    let synctron: Synctron
    let logger = Logger()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    func on(error: Error) {
        logger.error("\("\(error)", privacy: .public)")

        let content = UNMutableNotificationContent()
        content.title = "Error"
        content.body = error.localizedDescription

        let uuidString = UUID().uuidString
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("\(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
