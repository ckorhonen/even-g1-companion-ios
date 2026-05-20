import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ControlView()
                .tabItem {
                    Label("Control", systemImage: "eyeglasses")
                }

            DiagnosticsView()
                .tabItem {
                    Label("Diagnostics", systemImage: "waveform.path.ecg")
                }

            LogView()
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
        }
        .accessibilityIdentifier("EvenG1Root")
    }
}

#Preview {
    RootView()
        .environmentObject(GlassesBluetoothStore())
}

