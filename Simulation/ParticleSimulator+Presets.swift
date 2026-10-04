import Foundation

extension ParticleSimulator {
    
    private static let customPresetsKey = "SavedCustomPresets_v2"
    
    /// 取得所有預設集（內建 5 大經典 + 使用者自訂存檔）
    var allPresets: [SimulationPreset] {
        PresetLibrary.builtInPresets + customPresets
    }
    
    /// 從 UserDefaults 載入使用者儲存的快照
    func loadCustomPresetsFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.customPresetsKey),
              let decoded = try? JSONDecoder().decode([SimulationPreset].self, from: data) else {
            return
        }
        self.customPresets = decoded
    }
    
    /// 將使用者自訂快照寫入 UserDefaults
    private func saveCustomPresetsToDisk() {
        if let encoded = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(encoded, forKey: Self.customPresetsKey)
        }
    }
    
    /// ✨ 套用指定的宇宙預設集 / 快照（強制重新分佈粒子，確保 100% 展現湧現結構）
    func applyPreset(_ preset: SimulationPreset) {
        self.activePresetID = preset.id
        self.friction = preset.friction
        self.selectedPaletteID = preset.paletteID
        
        // 1. 無論種類數是否相同，都重置宇宙粒子位置（讓粒子重新均勻洗牌，避免卡在舊結構死角）
        self.resetSimulation(newCount: self.particleCount, newTypes: preset.numTypes)
        
        // 2. 將預設集的 N x N 矩陣覆蓋寫入 simulator（didSet 會自動呼叫 updateRuleMatrixBuffer 寫入 GPU）
        let expectedCount = preset.numTypes * preset.numTypes
        if preset.ruleMatrix.count == expectedCount {
            self.ruleMatrix = preset.ruleMatrix
        }
        if preset.rMinMatrix.count == expectedCount {
            self.rMinMatrix = preset.rMinMatrix
        }
        if preset.rMaxMatrix.count == expectedCount {
            self.rMaxMatrix = preset.rMaxMatrix
        }
    }
    
    /// ✨ 將目前的「矩陣規則 + 粒子種類 + 空間摩擦力 + 色票」儲存為自訂快照
    func saveCurrentAsPreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "自訂宇宙 #\(customPresets.count + 1)" : trimmed
        
        let newPreset = SimulationPreset(
            name: finalName,
            subtitle: "\(numTypes) 種粒子 · 摩擦 \(String(format: "%.2f", friction))",
            icon: "bookmark.fill",
            isBuiltIn: false,
            numTypes: self.numTypes,
            friction: self.friction,
            paletteID: self.selectedPaletteID,
            ruleMatrix: self.ruleMatrix,
            rMinMatrix: self.rMinMatrix,
            rMaxMatrix: self.rMaxMatrix
        )
        
        customPresets.insert(newPreset, at: 0)
        activePresetID = newPreset.id
        saveCustomPresetsToDisk()
    }
    
    /// 刪除指定的自訂快照
    func deleteCustomPreset(_ preset: SimulationPreset) {
        guard !preset.isBuiltIn else { return }
        customPresets.removeAll { $0.id == preset.id }
        if activePresetID == preset.id {
            activePresetID = nil
        }
        saveCustomPresetsToDisk()
    }
}
