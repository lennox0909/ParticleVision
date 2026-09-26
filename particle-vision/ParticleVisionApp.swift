import SwiftUI

@main
struct ParticleVisionApp: App {
    @State private var simulator = ParticleSimulator()

    var body: some Scene {
        WindowGroup {
            ContentView() // 這裡包著你的 ControlPanelView 或開啟按鈕
                .environment(simulator)
        }
        .defaultSize(width: 450, height: 750)
        .windowResizability(.contentSize)

        // 【修復】將 id 改為 "ParticleSpace"，對齊按鈕呼叫的名稱
        ImmersiveSpace(id: "ParticleSpace") {
            ImmersiveView()
                .environment(simulator)
        }
    }
}
