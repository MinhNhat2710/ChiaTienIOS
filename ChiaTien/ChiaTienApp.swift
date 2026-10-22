import SwiftUI

@main
struct ChiaTienApp: App {
    @State private var store = SplitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
