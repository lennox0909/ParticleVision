import SwiftUI

@main
struct ParticleVisionApp: App {
    // 建立全域唯一的 Metal 粒子模擬器實體
    @State private var simulator = ParticleSimulator()

    var body: some Scene {
        // 主要的 2D 玻璃視窗群組 (包含控制面板)
        WindowGroup {
            ContentView()
                .environment(simulator)
        }
        .windowResizability(.contentSize)

        // 定義無邊界的 3D 沉浸式空間
        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
