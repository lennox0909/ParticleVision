import SwiftUI

@main
struct ParticleVisionApp: App {
    // 確保整個 App 生命週期只有一個 Simulator 實體
    @State private var simulator = ParticleSimulator()
    
    var body: some Scene {
        // 預設開啟的 2D 視窗 (包含控制台與啟動按鈕)
        WindowGroup {
            ContentView()
                .environment(simulator)
        }
        .defaultSize(width: 850, height: 600)

        // 定義 3D 沉浸空間
        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
