import SwiftUI
import OSLog

struct LogView: View {
    @State var entries = [String]()

    var body: some View {
        VStack {
            List(entries, id: \.self) {
                Text($0)
            }
            Button(action: updateEntries) {
                Text("Refresh")
            }.padding(.bottom)
        }.onAppear(perform: updateEntries)
    }

    func updateEntries() {
        entries = {
            do {
                if #available(macOS 12.0, *) {
                    return try OSLogStore(scope: .currentProcessIdentifier)
                        .getEntries()
                        .compactMap { $0 as? OSLogEntryLog }
                        .filter { $0.subsystem == "dev.mxcl.workbench" }
                        .map(\.composedMessage)
                } else {
                    throw CocoaError(.coderInvalidValue)
                }
            } catch {
                return []
            }
        }()
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
