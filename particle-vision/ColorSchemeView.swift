import SwiftUI

struct ColorSchemeView: View {
    @Environment(ParticleSimulator.self) private var simulator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var showHelpPopover: Bool = false
    @State private var selectedCategory: String = "All"
    
    private let categoryTabs = ["All", "Static", "Generative", "Experimental"]
    
    /// 依據目前選取的分類篩選滾輪項目（選 All 時可一鏡到底滾動全部 37 種色票）
    private var filteredPalettes: [PaletteOption] {
        if selectedCategory == "All" {
            return ColorPaletteGenerator.palettes
        } else {
            return ColorPaletteGenerator.palettes.filter { $0.category == selectedCategory }
        }
    }
    
    var body: some View {
        @Bindable var bindableSimulator = simulator
        let count = simulator.numTypes
        
        VStack(alignment: .leading, spacing: 12) {
            
            // MARK: - 1. 標題列與 ⓘ 說明氣泡 + 重新骰色按鈕
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                
                Text("Color Scheme")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Button {
                    showHelpPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHelpPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("轉動滾輪即可即時切換色票。")
                            .font(.callout.bold())
                        Text("**Static** 為固定漸層；**Generative** 與 **Experimental** 每次選中或點擊骰子都會生成全新的主題變體。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(width: 290)
                }
                
                Spacer()
                
                Button {
                    simulator.applyPalette(id: simulator.selectedPaletteID)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dice.fill")
                        Text("隨機變體")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .tint(.cyan)
                .controlSize(.small)
                .help("重新生成當前色票變化")
            }
            
            // MARK: - 2. 當前啟用的粒子色票預覽列 + 粒子大小與螢光強度控制
            VStack(alignment: .leading, spacing: 10) {
                // 色票圓點預覽
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("目前套用色票:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(currentPalette?.name ?? "Rainbow")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                        Spacer()
                        Text(currentPalette?.category.uppercased() ?? "STATIC")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 10) {
                        ForEach(0..<count, id: \.self) { typeIdx in
                            Circle()
                                .fill(simulator.colorForType(typeIdx))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                        }
                        Spacer()
                    }
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.15))
                
                // 控制項 1：粒子大小
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
                
                // 控制項 2：螢光強度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("螢光強度")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(String(format: "%.1f", simulator.glowIntensity))
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundStyle(simulator.glowIntensity > 0 ? .cyan : .secondary)
                    }
                    
                    HStack(spacing: 10) {
                        Slider(value: $bindableSimulator.glowIntensity, in: 0...5, step: 0.1)
                            .tint(.cyan)
                        
                        Button {
                            let next = max(0, simulator.glowIntensity - 0.1)
                            simulator.glowIntensity = (next * 10).rounded() / 10
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        
                        Button {
                            let next = min(5, simulator.glowIntensity + 0.1)
                            simulator.glowIntensity = (next * 10).rounded() / 10
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
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
            .fixedSize(horizontal: false, vertical: true)
            
            // MARK: - 3. ✨ 分類選單 (修正壓縮與點選問題) + 3D 滾輪色票選擇器
            VStack(alignment: .leading, spacing: 10) {
                // 改用 visionOS 原生 Segmented Picker，並鎖定高度與優先層級 (zIndex)，防止被壓縮或被滾輪遮擋
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categoryTabs, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: 36)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
                .onChange(of: selectedCategory) { _, _ in
                    // 切換分類時，若當前色票不在該分類內，自動跳至該分類第一個色票並立即套用
                    if let firstInCat = filteredPalettes.first,
                       !filteredPalettes.contains(where: { $0.id == simulator.selectedPaletteID }) {
                        simulator.applyPalette(id: firstInCat.id)
                    }
                }
                
                // 3D 滾輪選單：固定高度 190pt，並限制觸控區域不超出外框
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.55), lineWidth: 1.5)
                        .fill(Color.cyan.opacity(0.10))
                        .frame(height: 38)
                        .padding(.horizontal, 10)
                        .allowsHitTesting(false)
                    
                    Picker("Color Palette", selection: $bindableSimulator.selectedPaletteID) {
                        ForEach(filteredPalettes) { option in
                            HStack(spacing: 8) {
                                Text(option.name)
                                    .font(.headline)
                                
                                if option.category != "Static" && option.category != "Default" {
                                    Image(systemName: "sparkles")
                                        .font(.caption)
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .tag(option.id)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
                    .contentShape(Rectangle())
                    .onChange(of: simulator.selectedPaletteID) { _, newID in
                        simulator.applyPalette(id: newID)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
            }
            
            Spacer(minLength: 0)
        }
        .padding(24)
        .onAppear {
            if !simulator.showColorWindow {
                openWindow(id: "MainControlWindow")
                dismissWindow(id: "ColorSchemeWindow")
            }
        }
        .onDisappear {
            simulator.showColorWindow = false
        }
    }
    
    private var currentPalette: PaletteOption? {
        ColorPaletteGenerator.palettes.first(where: { $0.id == simulator.selectedPaletteID })
    }
}
