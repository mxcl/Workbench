import UserNotifications
import SwiftUI
import Path

let sink = Path.home.Library.join("Mobile Documents/com~apple~CloudDocs/.workbench")

extension PathStruct {
    var rebased: PathStruct {
        sink.join(relative(to: Path.home))
    }
}

@main
class App: SwiftUI.App, FSWatcherDelegate {
    required init() {

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            print(granted, error ?? "")
        }

        let paths = [
            ".netrc",
            ".local",
            ".gnupg",
            ".ssh",
            ".gnpg",
            ".gitconfig",
            ".aws",
            ".config",
            ".zshrc"
        ].map(Path.home.join)

        for file in paths {
            let dst = file.rebased
            if !dst.exists {
                _ = try? file.copy(to: dst)
            }
        }

        watcher.delegate = self
        watcher.observe = Set(paths)
    }

    let watcher = FSWatcher()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    func fsWatcher(diff: FSWatcher.Diff) {
        do {
            for filename in diff.changed {
                guard filename.isFile else { continue }
                try filename.copy(into: sink.join(filename.relative(to: Path.home)).parent.mkdir(.p))
            }
            for filename in diff.renamed {
                print(filename)
            }
            for filename in diff.deleted {
                try sink.join(filename.relative(to: Path.home)).delete()
            }
        } catch {
            let content = UNMutableNotificationContent()
            content.title = "Error"
            content.body = error.localizedDescription

            let uuidString = UUID().uuidString
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.01, repeats: false)
            let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("error:", error)
                }
            }
        }
    }
}
