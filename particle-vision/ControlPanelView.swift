import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    @State private var particleCount: Double = 50000
    @State private var numTypes: Double = 6
    
    private var hasPendingChanges: Bool {
        Int(particleCount) != simulator.particleCount || Int(numTypes) != simulator.numTypes
    }
    
    var body: some View {
        @Bindable var bindableSimulator = simulator
        
        VStack(spacing: 12) {
            
            // MARK: - 區塊 1：宇宙規模設定（需點擊重置套用）
            VStack(alignment: .leading, spacing: 10) {
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
            .padding(14)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
            
            // MARK: - 區塊 2：即時物理與視覺微調（拉動立即生效）
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("即時物理與視覺", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("即時生效")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // 3. 粒子大小
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("粒子大小")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.3f", simulator.particleScale))
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $bindableSimulator.particleScale, in: 0.005...0.050, step: 0.001)
                }
                
                // 4. 空間摩擦力
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("空間摩擦力")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.2f", simulator.friction))
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $bindableSimulator.friction, in: 0.01...0.99, step: 0.01)
                }
                
                // 5. 螢光強度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("螢光強度")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.1f", simulator.glowIntensity))
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(simulator.glowIntensity > 0 ? .cyan : .secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Slider(value: $bindableSimulator.glowIntensity, in: 0...5, step: 0.5)
                            .tint(.cyan)
                        
                        Button {
                            simulator.glowIntensity = max(0, simulator.glowIntensity - 0.1)
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        
                        Button {
                            simulator.glowIntensity = min(5, simulator.glowIntensity + 0.1)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear {
            particleCount = Double(simulator.particleCount)
            numTypes = Double(simulator.numTypes)
        }
    }
}
