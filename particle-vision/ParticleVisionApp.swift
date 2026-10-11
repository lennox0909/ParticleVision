import SwiftUI

@main
struct ParticleVisionApp: App {
    @State private var simulator = ParticleSimulator()
    
    var body: some Scene {
        // 主視窗：Particle Life 控制台
        WindowGroup(id: "MainControlWindow") {
            ContentView()
                .environment(simulator)
                .frame(minWidth: 500, minHeight: 680)
        }
        .defaultSize(width: 580, height: 850)
        
        // 3D 沉浸粒子空間
        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
                // ✨ 修正：使用 nil 來代表「關閉」暗化效果，恢復預設真實環境
                .preferredSurroundingsEffect(simulator.isZenMode ? .systemDark : nil)
        }
    }
}
