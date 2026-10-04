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
            
            // MARK: - 區塊 2：✨ 透明盒子邊框顏色（全黑~灰階~全白）與粗細調整（位於啟動 3D 粒子空間按鈕正上方）
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("透明盒子外觀", systemImage: "squareshape.split.2x2")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("自動記憶設定")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // 1. 邊框顏色（全黑 0.0 -> 灰階 0.5 -> 全白 1.0）
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("邊框顏色 (黑 ↔ 白)")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Circle()
                            .fill(Color(white: Double(simulator.boxEdgeGrayscale)))
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        Text(edgeColorLabel)
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(.cyan)
                    }
                    
                    HStack(spacing: 10) {
                        Slider(value: $bindableSimulator.boxEdgeGrayscale, in: 0.0...1.0, step: 0.01)
                            .tint(Color(white: Double(max(0.35, simulator.boxEdgeGrayscale))))
                        
                        Button {
                            let next = max(0.0, simulator.boxEdgeGrayscale - 0.05)
                            simulator.boxEdgeGrayscale = (next * 100).rounded() / 100
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        
                        Button {
                            let next = min(1.0, simulator.boxEdgeGrayscale + 0.05)
                            simulator.boxEdgeGrayscale = (next * 100).rounded() / 100
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                    }
                }
                
                // 2. 邊框粗細
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("邊框粗細")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.3f", simulator.boxEdgeThickness))
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(.cyan)
                    }
                    
                    HStack(spacing: 10) {
                        Slider(value: $bindableSimulator.boxEdgeThickness, in: 0.002...0.050, step: 0.001)
                            .tint(.cyan)
                        
                        Button {
                            let next = max(0.002, simulator.boxEdgeThickness - 0.002)
                            simulator.boxEdgeThickness = (next * 1000).rounded() / 1000
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        
                        Button {
                            let next = min(0.050, simulator.boxEdgeThickness + 0.002)
                            simulator.boxEdgeThickness = (next * 1000).rounded() / 1000
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
        // ✨ 當透過預設集快照改變粒子種類數時，同步更新主控制台滑桿顯示
        .onChange(of: simulator.numTypes) { _, newTypes in
            numTypes = Double(newTypes)
        }
    }
    
    private var edgeColorLabel: String {
        let pct = Int((simulator.boxEdgeGrayscale * 100).rounded())
        if pct == 0 { return "全黑 (0%)" }
        if pct == 100 { return "全白 (100%)" }
        return "\(pct)%"
    }
}
