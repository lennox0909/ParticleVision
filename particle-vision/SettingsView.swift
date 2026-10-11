import SwiftUI

struct SettingsView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    var body: some View {
        @Bindable var bindableSim = simulator
        
        VStack(alignment: .leading, spacing: 20) {
            
            // 標題
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.gray)
                
                Text("環境與系統設定")
                    .font(.title3.weight(.bold))
            }
            .padding(.bottom, 5)
            
            // MARK: - 區塊 1：沉浸空間與專注模式
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $bindableSim.isZenMode) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("深度專注模式 (Zen Mode)")
                                .font(.headline)
                            Text("大幅壓暗真實世界的背景亮度，消除實體環境的視覺干擾，讓焦點完全鎖定在發光的 3D 粒子與透明黑洞上。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .tint(.purple)
            }
            .padding(16)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
            
            // MARK: - 區塊 2：全域視覺與渲染參數
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.secondary)
                    Text("全域視覺參數 (自動記憶)")
                        .font(.headline)
                }
                .padding(.bottom, -4)
                
                // 1. 粒子大小
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("粒子大小")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(String(format: "%.3f", simulator.particleScale))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $bindableSim.particleScale, in: 0.005...0.050, step: 0.001)
                        .controlSize(.small)
                }
                
                // 2. 流體速度拉伸
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Label("流體速度拉伸 (彗星尾跡)", systemImage: "wind")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(simulator.velocityStretch == 0 ? "關閉" : String(format: "%.1fx", simulator.velocityStretch))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(simulator.velocityStretch > 0 ? .orange : .secondary)
                    }
                    Slider(value: $bindableSim.velocityStretch, in: 0.0...5.0, step: 0.1)
                        .tint(.orange)
                        .controlSize(.small)
                }
                
                // 3. 螢光強度
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("螢光強度")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(String(format: "%.1f", simulator.glowIntensity))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(simulator.glowIntensity > 0 ? .cyan : .secondary)
                    }
                    
                    HStack(spacing: 8) {
                        Slider(value: $bindableSim.glowIntensity, in: 0...5, step: 0.1)
                            .tint(.cyan)
                            .controlSize(.small)
                        
                        Button {
                            let next = max(0, simulator.glowIntensity - 0.1)
                            simulator.glowIntensity = (next * 10).rounded() / 10
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.mini)
                        
                        Button {
                            let next = min(5, simulator.glowIntensity + 0.1)
                            simulator.glowIntensity = (next * 10).rounded() / 10
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.mini)
                    }
                }
            }
            .padding(16)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .padding(24)
    }
}
