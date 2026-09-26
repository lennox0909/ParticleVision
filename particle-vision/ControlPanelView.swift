import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator

    var body: some View {
        VStack(spacing: 24) {
            Text("Particle Life 物理控制台")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading) {
                Text("最大作用半徑 (rMax): \(simulator.params.rMax, specifier: "%.2f")")
                Slider(value: Binding(
                    get: { simulator.params.rMax },
                    set: { simulator.params.rMax = $0; simulator.updateParamsBuffer() }
                ), in: 0.1...1.0)
            }
            
            VStack(alignment: .leading) {
                Text("最小排斥半徑 (rMin): \(simulator.params.rMin, specifier: "%.2f")")
                Slider(value: Binding(
                    get: { simulator.params.rMin },
                    set: { simulator.params.rMin = $0; simulator.updateParamsBuffer() }
                ), in: 0.01...0.2)
            }
            
            VStack(alignment: .leading) {
                Text("宇宙摩擦力: \(simulator.params.friction, specifier: "%.3f")")
                Slider(value: Binding(
                    get: { simulator.params.friction },
                    set: { simulator.params.friction = $0; simulator.updateParamsBuffer() }
                ), in: 0.80...0.99)
            }
            
            VStack(alignment: .leading) {
                Text("粒子大小 (Scale): \(simulator.particleScale, specifier: "%.3f")")
                Slider(value: Binding(
                    get: { simulator.particleScale },
                    set: { simulator.particleScale = $0 }
                ), in: 0.001...0.015)
            }
            
            Button("🌌 重新生成宇宙規則 (Randomize)") {
                simulator.randomizeRules()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
        .padding(32)
        .frame(width: 400)
        .glassBackgroundEffect()
    }
}
