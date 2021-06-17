import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("""
            `cp` files or directories from your home directory to
            the `.workbench` directory in your iCloud Drive.
            Workbench detects changes to either copy and maintains
            synchronization between them. Thus changes propogate to
            your other computers.

            We have installed ourselves as a Login Item, you can
            close this Window.
            """
        ).padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
