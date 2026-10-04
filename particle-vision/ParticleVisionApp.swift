import SwiftUI

@main
struct ParticleVisionApp: App {
    @State private var simulator = ParticleSimulator()

    var body: some Scene {
        // 1. 主視窗：Particle Life 控制台
        WindowGroup(id: "MainControlWindow") {
            ContentView()
                .environment(simulator)
        }
        .defaultSize(width: 500, height: 680)

        // 2. 左側獨立原生視窗：Color Scheme 選擇器（✨ 高度由 760 收斂至 560，完美貼合 3D 滾輪）
        WindowGroup(id: "ColorSchemeWindow") {
            ColorSchemeView()
                .environment(simulator)
                .frame(minWidth: 340, minHeight: 540)
        }
        .defaultSize(width: 380, height: 560)

        // 3. 右側獨立原生視窗：Matrix Settings 編輯器
        WindowGroup(id: "MatrixSettingsWindow") {
            RuleMatrixView()
                .environment(simulator)
                .frame(minWidth: 440, minHeight: 740)
        }
        .defaultSize(width: 480, height: 820)

        // 4. 3D 沉浸粒子空間
        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
