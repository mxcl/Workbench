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
        content.subtitle = error.localizedDescription
        content.body = "\(error)"

        let id = UUID().uuidString
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("\(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
