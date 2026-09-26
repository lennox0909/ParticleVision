import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    @State private var draftCount: Double = 4000
    @State private var draftTypes: Int = 4

    var body: some View {
        VStack(spacing: 24) {
            Text("Particle Life 物理控制台")
                .font(.title2).bold()
            
            VStack(alignment: .leading) {
                Text("粒子大小: \(String(format: "%.3f", simulator.particleScale))")
                Slider(value: Bindable(simulator).particleScale, in: 0.005...0.03)
            }
            
            VStack(alignment: .leading) {
                Text("最大排斥半徑 (rMax): \(String(format: "%.2f", simulator.params.rMax))")
                Slider(value: Bindable(simulator).params.rMax, in: 0.1...1.0) { _ in
                    simulator.updateParamsBuffer()
                }
            }
            
            VStack(alignment: .leading) {
                Text("空間摩擦力: \(String(format: "%.2f", simulator.params.friction))")
                Slider(value: Bindable(simulator).params.friction, in: 0.5...1.0) { _ in
                    simulator.updateParamsBuffer()
                }
            }
            
            Button(action: {
                simulator.randomizeRules()
            }) {
                Text("隨機重置引力矩陣")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Divider().padding(.vertical, 8)
            
            VStack(alignment: .leading) {
                Text("粒子數量: \(Int(draftCount)) 顆")
                Slider(value: $draftCount, in: 500...8000, step: 500)
            }
            
            VStack(alignment: .leading) {
                Text("粒子種類 (顏色): \(draftTypes) 種")
                Stepper(value: $draftTypes, in: 1...6) {
                    Text("調整種類")
                }
            }
            
            Button(action: {
                simulator.resetSimulation(newCount: Int(draftCount), newTypes: draftTypes)
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("套用設定並重置宇宙")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.top, 10)
        }
        .padding(32)
        .frame(width: 400)
        .glassBackgroundEffect()
        .onAppear {
            draftCount = Double(simulator.particleCount)
            draftTypes = simulator.numTypes
        }
    }
}
