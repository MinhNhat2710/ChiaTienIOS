import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            QuickSplitView()
                .tabItem {
                    Label("Chia nhanh", systemImage: "divide")
                }
            GroupSplitView()
                .tabItem {
                    Label("Nhóm", systemImage: "person.3")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(SplitStore())
}
