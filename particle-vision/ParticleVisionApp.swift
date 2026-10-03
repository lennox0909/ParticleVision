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
        // ✨ 將預設高度由 760 提高至 800，給底部留出充裕空間
        .defaultSize(width: 520, height: 800)

        // 2. 左側獨立原生視窗：Color Scheme 選擇器
        WindowGroup(id: "ColorSchemeWindow") {
            ColorSchemeView()
                .environment(simulator)
                .frame(minWidth: 340, minHeight: 580)
        }
        .defaultSize(width: 380, height: 760)

        // 3. 右側獨立原生視窗：Matrix Settings 編輯器
        WindowGroup(id: "MatrixSettingsWindow") {
            RuleMatrixView()
                .environment(simulator)
                .frame(minWidth: 440, minHeight: 640)
        }
        .defaultSize(width: 480, height: 760)

        // 4. 3D 沉浸粒子空間
        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
