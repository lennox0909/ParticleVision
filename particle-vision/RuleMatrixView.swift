import SwiftUI

struct RuleMatrixView: View {
    @Environment(ParticleSimulator.self) var simulator
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    @State var selectedTab: MatrixTab = .forces
    @State var selection: MatrixSelection = .cell(row: 0, col: 0)
    @State var activeHelpTab: MatrixTab? = nil
    
    // ✨ 新增：控制「儲存自訂快照」命名彈窗的狀態
    @State var showSavePresetAlert: Bool = false
    @State var newPresetName: String = ""
    
    var body: some View {
        let count = simulator.numTypes
        let cellSize: CGFloat = count <= 6 ? 42 : 34
        
        VStack(alignment: .leading, spacing: 12) {
            // 1. 頂部標題與重置按鈕列
            headerSection
            
            // 2. ✨ 新增：經典生命宇宙預設集與自訂快照橫向畫廊
            presetGallerySection
            
            // 3. 模式切換器與 Popover 氣泡說明
            tabPickerSection
            
            // 4. 2D 互動式矩陣熱力圖網格
            matrixGridSection(count: count, cellSize: cellSize)
            
            // 5. 即時物理環境（空間摩擦力）控制卡片
            frictionControlSection
            
            Spacer(minLength: 0)
            
            // 6. 底部矩陣滑桿與 － / ＋ 精準微調控制列
            bottomControlSection
        }
        .padding(26)
        .alert("儲存宇宙快照", isPresented: $showSavePresetAlert) {
            TextField("輸入快照名稱（例如：雙螺旋星雲）", text: $newPresetName)
            Button("取消", role: .cancel) {
                newPresetName = ""
            }
            Button("儲存") {
                simulator.saveCurrentAsPreset(name: newPresetName)
                newPresetName = ""
            }
        } message: {
            Text("將目前的引力與半徑矩陣、粒子種類數、空間摩擦力與色票完整保存為自訂預設集。")
        }
        .onChange(of: count) { _, newCount in
            validateSelection(for: newCount)
        }
        .onAppear {
            if !simulator.showMatrixWindow {
                openWindow(id: "MainControlWindow")
                dismissWindow(id: "MatrixSettingsWindow")
            }
        }
        .onDisappear {
            simulator.showMatrixWindow = false
        }
    }
}
