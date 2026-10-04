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
        
        VStack(alignment: .leading, spacing: 10) {
            
            // MARK: - 1. 標題列與 ⓘ 說明氣泡 + 重新骰色按鈕
            HStack(spacing: 6) {
                Image(systemName: simulator.isKineticColorMode ? "flame.fill" : "paintpalette.fill")
                    .font(.title3)
                    .foregroundStyle(simulator.isKineticColorMode ? .orange : .cyan)
                    .contentTransition(.symbolEffect(.replace))
                
                Text("Color Scheme")
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Button {
                    showHelpPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(2)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHelpPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎨 色票與動能視覺指南")
                            .font(.callout.bold())
                        Text("• **種類色票模式**：依下方滾輪選取的色票為各粒子種類上色。\n• **🔥 熱力能階模式**：依各粒子群的活躍度自動映射為「深海冷藍 ➔ 烈焰橘紅」熱力漸層。\n• **☄️ 流體速度拉伸**：高速運動的粒子會沿速度方向自動拉伸為彗星光梭。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(width: 310)
                }
                
                Spacer(minLength: 4)
                
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
                .disabled(simulator.isKineticColorMode)
                .help("重新生成當前色票變化")
            }
            
            // MARK: - 2. 著色模式切換 + 粒子外觀與動能拉伸控制 (緊湊化排版)
            VStack(alignment: .leading, spacing: 8) {
                
                // 種類色票 vs 熱力能量模式 Segmented 切換器
                Picker("著色模式", selection: $bindableSimulator.isKineticColorMode) {
                    Text("🎨 種類色票").tag(false)
                    Text("🔥 熱力能階").tag(true)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                
                // 色票圓點預覽（或熱力光譜預覽）
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(simulator.isKineticColorMode ? "熱力光譜 (低能 ➔ 高能):" : "目前套用色票:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(simulator.isKineticColorMode ? "Thermal Plasma" : (currentPalette?.name ?? "Rainbow"))
                            .font(.caption.bold())
                            .foregroundStyle(simulator.isKineticColorMode ? .orange : .cyan)
                            .lineLimit(1)
                        Spacer()
                        Text(simulator.isKineticColorMode ? "KINETIC" : (currentPalette?.category.uppercased() ?? "STATIC"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    
                    if simulator.isKineticColorMode {
                        // 顯示連續熱力漸層條 + 各粒子群即時真實動能游標
                        ZStack(alignment: .leading) {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.04, green: 0.12, blue: 0.48),
                                    .cyan,
                                    .green,
                                    .yellow,
                                    .red
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 20)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                            
                            // 即時標示目前最高動能位置
                            GeometryReader { geo in
                                let maxEnergy = simulator.typeKineticEnergies.prefix(count).max() ?? 0.0
                                Circle()
                                    .fill(.white)
                                    .frame(width: 14, height: 14)
                                    .shadow(color: .black.opacity(0.6), radius: 2)
                                    .offset(x: max(3, min(geo.size.width - 17, CGFloat(maxEnergy) * (geo.size.width - 14))), y: 3)
                            }
                        }
                        .frame(height: 20)
                    } else {
                        HStack(spacing: 8) {
                            ForEach(0..<count, id: \.self) { typeIdx in
                                Circle()
                                    .fill(simulator.colorForType(typeIdx))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                            }
                            Spacer()
                        }
                    }
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.15))
                
                // 控制項 1：粒子大小
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("粒子大小")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(String(format: "%.3f", simulator.particleScale))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $bindableSimulator.particleScale, in: 0.005...0.050, step: 0.001)
                        .controlSize(.small)
                }
                
                // 控制項 2：流體速度拉伸 (Velocity Stretch)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Label("流體速度拉伸 (彗星尾跡)", systemImage: "wind")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Text(simulator.velocityStretch == 0 ? "關閉" : String(format: "%.1fx", simulator.velocityStretch))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(simulator.velocityStretch > 0 ? .orange : .secondary)
                    }
                    Slider(value: $bindableSimulator.velocityStretch, in: 0.0...5.0, step: 0.1)
                        .tint(.orange)
                        .controlSize(.small)
                }
                
                // 控制項 3：螢光強度
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
                        Slider(value: $bindableSimulator.glowIntensity, in: 0...5, step: 0.1)
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
            .padding(12)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
            
            // MARK: - 3. 分類選單 + 3D 滾輪色票選擇器
            VStack(alignment: .leading, spacing: 8) {
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("All")
                    Text("Static").tag("Static")
                    Text("Gen").tag("Generative")
                    Text("Exp").tag("Experimental")
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .zIndex(1)
                .onChange(of: selectedCategory) { _, _ in
                    if let firstInCat = filteredPalettes.first,
                       !filteredPalettes.contains(where: { $0.id == simulator.selectedPaletteID }) {
                        simulator.applyPalette(id: firstInCat.id)
                    }
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.55), lineWidth: 1.5)
                        .fill(Color.cyan.opacity(0.10))
                        .frame(height: 34)
                        .padding(.horizontal, 10)
                        .allowsHitTesting(false)
                    
                    Picker("Color Palette", selection: $bindableSimulator.selectedPaletteID) {
                        ForEach(filteredPalettes) { option in
                            HStack(spacing: 6) {
                                Text(option.name)
                                    .font(.subheadline.weight(.semibold))
                                
                                if option.category != "Static" && option.category != "Default" {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .tag(option.id)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 135)
                    .clipped()
                    .contentShape(Rectangle())
                    .onChange(of: simulator.selectedPaletteID) { _, newID in
                        simulator.isKineticColorMode = false // 轉動色票滾輪時自動切回色票模式
                        simulator.applyPalette(id: newID)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 135)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
                .opacity(simulator.isKineticColorMode ? 0.5 : 1.0)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
