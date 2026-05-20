import SwiftUI

@main
struct EvenG1CompanionApp: App {
    @StateObject private var bluetooth = GlassesBluetoothStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bluetooth)
        }
    }
}

