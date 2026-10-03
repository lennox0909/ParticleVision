import SwiftUI

@main
struct ParticleVisionApp: App {
    @State private var simulator = ParticleSimulator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(simulator)
        }
        // ✨ 關鍵 1：移除系統預設的大塊毛玻璃背板，讓兩個面板中間的間隙完全透明
        .windowStyle(.plain)
        // ✨ 關鍵 2：將預設寬度加大至 1080，確保並排的兩個毛玻璃視窗一開啟就完整顯示不被裁切
        .defaultSize(width: 1080, height: 760)
        // 讓視窗自動貼合內容尺寸
        .windowResizability(.contentSize)

        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
