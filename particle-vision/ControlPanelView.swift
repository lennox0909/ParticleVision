import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    @State private var particleCount: Double = 50000
    @State private var numTypes: Double = 6
    
    private var hasPendingChanges: Bool {
        Int(particleCount) != simulator.particleCount || Int(numTypes) != simulator.numTypes
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("宇宙規模設定", systemImage: "cube.transparent")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if hasPendingChanges {
                    Text("尚未套用變更")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            
            // 1. 粒子數量
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("粒子數量")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(particleCount).formatted())")
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundStyle(.cyan)
                }
                Slider(value: $particleCount, in: 1000...100000, step: 1000)
            }
            
            // 2. 粒子種類
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("粒子種類")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(Int(numTypes)) 種")
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundStyle(.cyan)
                }
                Slider(value: $numTypes, in: 2...8, step: 1)
            }
            
            // 套用並重置宇宙按鈕
            Button {
                simulator.resetSimulation(newCount: Int(particleCount), newTypes: Int(numTypes))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("套用並重置宇宙")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(hasPendingChanges ? .orange : .white.opacity(0.22))
            .controlSize(.regular)
            .padding(.top, 2)
        }
        .padding(16)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            particleCount = Double(simulator.particleCount)
            numTypes = Double(simulator.numTypes)
        }
    }
}
