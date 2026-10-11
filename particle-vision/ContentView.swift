import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    var body: some View {
        // ✨ 使用 TabView 來打造 visionOS 的原生左側邊欄
        TabView {
            // 頁籤 1：主控制台
            MainDashboardView()
                .tabItem {
                    Label("控制台", systemImage: "sparkles")
                }
            
            // 頁籤 2：顏色與熱力模式
            ColorSchemeView()
                .tabItem {
                    Label("顏色主題", systemImage: "paintpalette.fill")
                }
            
            // 頁籤 3：物理矩陣設定
            RuleMatrixView()
                .tabItem {
                    Label("物理矩陣", systemImage: "grid")
                }
                
            // ✨ 頁籤 4：系統環境設定 (新增)
            SettingsView()
                .tabItem {
                    Label("環境設定", systemImage: "gearshape")
                }
        }
    }
}

// ✨ 將您原本在 ContentView 中的 UI 原封不動地搬到這個新的 MainDashboardView 中
struct MainDashboardView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    var body: some View {
        @Bindable var bindableSim = simulator
        
        VStack(alignment: .leading, spacing: 8) {
            
            // MARK: - 1. 頂部標題列 + 空間音效開關 + FPS 狀態膠囊
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.cyan)
                
                Text("Particle Life 控制台")
                    .font(.title3.weight(.bold))
                
                Spacer()
                
                // 3D 空間音效靜音切換膠囊按鈕
                Button {
                    simulator.isAudioMuted.toggle()
                } label: {
                    let audioColor: Color = simulator.isAudioMuted ? .gray : .cyan
                    HStack(spacing: 4) {
                        Image(systemName: simulator.isAudioMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                            .font(.caption2.weight(.bold))
                        Text(simulator.isAudioMuted ? "靜音" : "空間音效")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(audioColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .overlay(
                        Capsule().stroke(audioColor.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // FPS 即時監控膠囊標籤
                HStack(spacing: 6) {
                    Circle()
                        .fill(fpsStatusColor)
                        .frame(width: 7, height: 7)
                    Text("FPS \(simulator.currentFPS)")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.35), in: Capsule())
                .overlay(
                    Capsule().stroke(fpsStatusColor.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.top, 2)
            
            // ✨ ✨ 注意：這裡移除了原本開啟獨立視窗的兩個 Toggle 按鈕！
            
            // MARK: - 2. 透明盒子手部操作 vs 神之手力場切換橫幅
            Button {
                simulator.isBoxInteractionEnabled.toggle()
            } label: {
                let modeColor: Color = simulator.isBoxInteractionEnabled ? .cyan : .orange
                HStack(spacing: 8) {
                    Image(systemName: simulator.isBoxInteractionEnabled ? "hand.draw.fill" : "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(modeColor)
                    
                    Text(simulator.isBoxInteractionEnabled ? "手勢模式：允許搬移與縮放透明盒子" : "手勢模式：已鎖定盒子 (雙手神之手力場啟用中)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(simulator.isBoxInteractionEnabled ? "點擊鎖定 🔒" : "點擊解鎖 🖐️")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(modeColor.opacity(0.22), in: Capsule())
                        .foregroundStyle(modeColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(modeColor.opacity(0.45), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            // MARK: - 3. 核心參數控制面板（宇宙規模 / 時空邊界 / 透明盒子外觀）
            ScrollView { // 加入 ScrollView 避免內容在視窗高度變化時被截斷
                ControlPanelView()
                    .padding(.bottom, 20)
            }
            
            Spacer(minLength: 0)
            
            // MARK: - 4. 底部 3D 空間啟動鈕
            HStack {
                Spacer()
                ToggleImmersiveSpaceButton()
                    .controlSize(.regular)
                Spacer()
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    private var fpsStatusColor: Color {
        if simulator.currentFPS >= 75 {
            return .green
        } else if simulator.currentFPS >= 50 {
            return .yellow
        } else if simulator.currentFPS > 0 {
            return .orange
        } else {
            return .gray
        }
    }
}
