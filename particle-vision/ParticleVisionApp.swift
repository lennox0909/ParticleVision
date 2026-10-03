import SwiftUI

@main
struct ParticleVisionApp: App {
    @State private var simulator = ParticleSimulator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(simulator)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1480, height: 760)
        .windowResizability(.contentSize)

        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
