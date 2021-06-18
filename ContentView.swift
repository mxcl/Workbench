import SwiftUI
import Path

struct ContentView: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        VStack(spacing: 20) {
            Text("""
                `cp` files or directories from your home directory to
                the `.workbench` directory in your iCloud Drive.
                Workbench detects changes to either copy and maintains
                synchronization between them. Thus changes propogate to
                your other computers.

                We have installed ourselves as a Login Item, you can
                close this Window.
                """
            ).lineSpacing(3)
            Button("Open `.workbench` Folder") {
                NSWorkspace.shared.open(
                    [Path.sink.url],
                    withApplicationAt: .terminal,
                    configuration: .init()) { _, error in
                        if let error = error {
                            NSAlert(error: error).runModal()
                        }
                    }
                NSWorkspace.shared.open(Path.sink.url)
            }
        }.padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

private extension URL {
    static var terminal: Self {
        .init(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
    }
}
