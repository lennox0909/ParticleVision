import SwiftUI

struct RuleMatrixView: View {
    @Environment(ParticleSimulator.self) var simulator
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    @State var selectedTab: MatrixTab = .forces
    @State var selection: MatrixSelection = .cell(row: 0, col: 0)
    @State var activeHelpTab: MatrixTab? = nil
    
    var body: some View {
        let count = simulator.numTypes
        let cellSize: CGFloat = count <= 6 ? 44 : 35
        
        VStack(alignment: .leading, spacing: 14) {
            // 1. 頂部標題與重置按鈕列
            headerSection
            
            // 2. 模式切換器與 Popover 氣泡說明
            tabPickerSection
            
            // 3. 2D 互動式矩陣熱力圖網格
            matrixGridSection(count: count, cellSize: cellSize)
            
            // 4. ✨ 移入：即時物理環境（空間摩擦力）控制卡片，位於矩陣網格正下方
            frictionControlSection
            
            Spacer(minLength: 0)
            
            // 5. 底部矩陣滑桿與 － / ＋ 精準微調控制列
            bottomControlSection
        }
        .padding(30)
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
