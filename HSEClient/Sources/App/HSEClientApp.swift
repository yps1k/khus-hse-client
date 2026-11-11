import SwiftUI

@main
struct HSEClientApp: App {
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowStyle(.titleBar)
    }
}
