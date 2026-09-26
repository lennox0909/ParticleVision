import SwiftUI

@main
struct ParticleVisionApp: App {
    @State private var simulator = ParticleSimulator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(simulator)
                // 【新增】強制視窗的最小尺寸，確保資訊絕對不會被裁切
                .frame(minWidth: 500, minHeight: 700)
        }
        // 【修改】將預設大小加大 (原本可能是 width: 450, height: 750 等等)
        .defaultSize(width: 500, height: 700)
        // 讓視窗自動貼合內容尺寸
        .windowResizability(.contentSize)

        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
