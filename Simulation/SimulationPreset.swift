import Foundation

/// 宇宙快照資料結構（完整記錄種類數、作用力矩陣、最小/最大半徑矩陣、摩擦力與色票 ID）
struct SimulationPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var subtitle: String
    var icon: String
    var isBuiltIn: Bool
    
    var numTypes: Int
    var friction: Float
    var paletteID: Int
    
    /// 長度為 numTypes * numTypes 的一維陣列，對應 ParticleSimulator 的三個矩陣
    var ruleMatrix: [Float]
    var rMinMatrix: [Float]
    var rMaxMatrix: [Float]
}

enum PresetLibrary {
    
    /// 內建 5 大經典生命宇宙預設集（專為 3D 空間湧現結構精調）
    static let builtInPresets: [SimulationPreset] = [
        makeCyclicWorms(),
        makeCellMitosis(),
        makeSymbiosisGalaxies(),
        makePredatorPrey(),
        makeCrystalLattice()
    ]
    
    // MARK: - 1. 游動蠕蟲 (3D 彩色體節推進鏈)
    /// 關鍵：先讓同類強力凝聚成「體節球 (0.85)」，並透過非對稱前後拉扯 (+0.75 / -0.65) 與適度阻尼 (0.78) 形成穩定游動的節肢長蟲
    private static func makeCyclicWorms() -> SimulationPreset {
        let n = 6
        let count = n * n
        var f = [Float](repeating: 0.0, count: count)
        var minR = [Float](repeating: 0.028, count: count)
        var maxR = [Float](repeating: 0.095, count: count)
        
        for r in 0..<n {
            for c in 0..<n {
                let idx = r * n + c
                if r == c {
                    // 1. 同顏色強烈凝聚成飽滿的「蟲體節點」
                    f[idx] = 0.85
                    minR[idx] = 0.018
                    maxR[idx] = 0.075
                } else if c == (r + 1) % n {
                    // 2. 緊密吸附下一個顏色節點（車頭拉車廂）
                    f[idx] = 0.75
                    minR[idx] = 0.032
                    maxR[idx] = 0.110
                } else if c == (r + n - 1) % n {
                    // 3. 被前一個顏色推著走，但排斥力小於吸引力（產生單向游動推進力，且不斷裂）
                    f[idx] = -0.50
                    minR[idx] = 0.035
                    maxR[idx] = 0.105
                } else {
                    // 4. 與其他非相鄰節點保持排斥，避免整條蟲捲成一團球
                    f[idx] = -0.45
                    minR[idx] = 0.040
                    maxR[idx] = 0.115
                }
            }
        }
        return SimulationPreset(
            name: "游動蠕蟲",
            subtitle: "3D 體節推進鏈",
            icon: "scribble.variable",
            isBuiltIn: true,
            numTypes: n,
            friction: 0.88, // 關鍵：適度阻尼防止高速甩飛斷裂
            paletteID: 1,   // Rainbow
            ruleMatrix: f,
            rMinMatrix: minR,
            rMaxMatrix: maxR
        )
    }
    
    // MARK: - 2. 細胞有絲分裂 (Cell Mitosis) — 保留你驗證效果極佳的參數
    /// 雙層包覆結構：內核緊密聚合，外膜包圍內核但彼此排斥，聚集成大細胞後會不斷分裂
    private static func makeCellMitosis() -> SimulationPreset {
        let n = 4
        let count = n * n
        var f = [Float](repeating: 0.0, count: count)
        var minR = [Float](repeating: 0.022, count: count)
        var maxR = [Float](repeating: 0.105, count: count)
        
        for r in 0..<n {
            for c in 0..<n {
                let idx = r * n + c
                if r == c {
                    f[idx] = (r % 2 == 0) ? 0.85 : -0.35 // 偶數為細胞核(凝聚)，奇數為細胞膜(擴散)
                    maxR[idx] = 0.095
                } else if abs(r - c) == 1 && min(r, c) % 2 == 0 {
                    f[idx] = 0.75 // 細胞核與專屬細胞膜互相吸引包覆
                    minR[idx] = 0.032
                    maxR[idx] = 0.120
                } else {
                    f[idx] = -0.60 // 不同細胞群之間強烈排斥
                    maxR[idx] = 0.125
                }
            }
        }
        return SimulationPreset(
            name: "細胞分裂",
            subtitle: "有機核膜結構",
            icon: "circle.grid.cross.fill",
            isBuiltIn: true,
            numTypes: n,
            friction: 0.90,
            paletteID: 6, // Pastel
            ruleMatrix: f,
            rMinMatrix: minR,
            rMaxMatrix: maxR
        )
    }
    
    // MARK: - 3. 星系漩渦 (三層同心土星環結構 — 借鑑細胞分裂成功基因 + 旋轉推進)
    /// 關鍵：採用與「細胞分裂」相同的 0.89 活性摩擦力與極端正負反差，形成「緻密金核 + 內層氣態殼 + 外層公轉星環」的三層立體星球！
    private static func makeSymbiosisGalaxies() -> SimulationPreset {
        let n = 4
        // 4x4 極端反差矩陣：
        // Type 0 (恆星核心)：超強自聚 (+1.00)，強力拉住第 1 層內殼 (+0.90)，排斥外環 (-0.80)
        // Type 1 (內層光環)：自身微斥撐開成球殼 (-0.40)，緊貼核心 (+0.95)，並吸引第 2 層星環 (+0.85)
        // Type 2 (外層星環 A)：自身凝聚成衛星團 (+0.80)，受內殼吸引 (+0.75)，並單向追逐 Type 3 (+0.95) 產生旋轉！
        // Type 3 (外層星環 B)：自身凝聚 (+0.80)，被 Type 2 推進 (-0.85) 並繞著內殼 (+0.75) 持續公轉！
        let f: [Float] = [
            1.00,  0.90, -0.80, -0.80,
            0.95, -0.40,  0.85,  0.85,
            -0.70,  0.75,  0.80,  0.95,
            -0.70,  0.75, -0.85,  0.80
        ]
        // 透過明確的 minR 梯度 (0.015 -> 0.035 -> 0.055) 強制撐開內核、中殼、外環三層立體間距！
        let minR: [Float] = [
            0.015, 0.032, 0.055, 0.055,
            0.032, 0.025, 0.038, 0.038,
            0.055, 0.038, 0.020, 0.030,
            0.055, 0.038, 0.030, 0.020
        ]
        // 全數開啟最大感知半徑 (0.115 ~ 0.125)，確保 3D 空間遠處粒子立刻被吸過來組裝
        let maxR: [Float] = [
            0.110, 0.125, 0.125, 0.125,
            0.125, 0.115, 0.125, 0.125,
            0.125, 0.125, 0.105, 0.125,
            0.125, 0.125, 0.125, 0.105
        ]
        
        return SimulationPreset(
            name: "星系漩渦",
            subtitle: "三層同心行星與星環",
            icon: "hurricane",
            isBuiltIn: true,
            numTypes: n,
            friction: 0.89, // ✨ 對齊「細胞分裂 (0.90)」與「幾何晶格 (0.88)」的黃金活性區間！
            paletteID: 8,   // Sci-Fi Spectrum
            ruleMatrix: f,
            rMinMatrix: minR,
            rMaxMatrix: maxR
        )
    }
    
    // MARK: - 4. 生態食物鏈 (變形蟲吞噬與孢子噴發循環)
    /// 關鍵：捨棄會導致粒子亂飛的單純逃逸，改用「廣視角捕食巨獸 (0.125) + 短視角孢子群 (0.075)」與雙向包覆結構，
    /// 肉眼可清晰看見巨型雙色變形蟲將周圍的孢子球吸入體內包裹、消化後再噴發分裂的完整生態循環！
    private static func makePredatorPrey() -> SimulationPreset {
        let n = 4
        // 4x4 矩陣：
        // Type 0 (捕食者內核)：超強自聚 (+0.95)，與外膜 Type 1 雙向緊密結合 (+0.90)，但排斥吞入肚裡的孢子 Type 3 (-0.85) 產生消化噴發！
        // Type 1 (捕食者吞噬外膜)：自斥張開成大網 (-0.35)，緊包內核 (+0.90)，並以最大引力 (+1.00) 遠距捕捉孢子群 Type 3！
        // Type 2 (共生推進尾)：自聚成推進器 (+0.85)，吸附在捕食者內核 (+0.80) 並推開外膜 (-0.60)，驅動捕食者四處游動覓食！
        // Type 3 (營養孢子魚群)：強烈自聚成一顆顆高密度孢子球 (+0.90)，被捕食者外膜吸入包裹 (+0.75)，碰到內核則彈開分裂 (-0.80)！
        let f: [Float] = [
            0.95,  0.90,  0.75, -0.85,
            0.90, -0.35, -0.55,  1.00,
            0.80, -0.60,  0.85, -0.40,
            -0.80,  0.75, -0.40,  0.90
        ]
        // 排斥半徑梯度：讓外膜 (Type 1) 能夠把孢子球 (Type 3) 吸進包覆層內，再由內核 (Type 0) 推擠出來
        let minR: [Float] = [
            0.016, 0.032, 0.028, 0.050,
            0.032, 0.024, 0.042, 0.020,
            0.028, 0.042, 0.018, 0.045,
            0.050, 0.020, 0.045, 0.016
        ]
        // 視野差設計：捕食者外膜對孢子擁有最大視野 (0.125)，而孢子自身凝聚視野集中 (0.085)，確保結成飽滿球體不散開！
        let maxR: [Float] = [
            0.095, 0.120, 0.115, 0.115,
            0.120, 0.105, 0.115, 0.125,
            0.115, 0.115, 0.090, 0.110,
            0.115, 0.120, 0.110, 0.085
        ]
        
        return SimulationPreset(
            name: "生態食物鏈",
            subtitle: "變形蟲吞噬與孢子循環",
            icon: "hare.fill",
            isBuiltIn: true,
            numTypes: n,
            friction: 0.89, // 維持在最清晰的黃金阻尼區間
            paletteID: 2,   // Neon Warm
            ruleMatrix: f,
            rMinMatrix: minR,
            rMaxMatrix: maxR
        )
    }
    
    // MARK: - 5. 幾何晶格脈動 (Crystal Lattice) — 保留你驗證效果極佳的參數
    /// 對稱正負相間的引力與較大最小排斥半徑，使粒子自動排列成呼吸脈動的幾何晶格
    private static func makeCrystalLattice() -> SimulationPreset {
        let n = 6
        let count = n * n
        var f = [Float](repeating: 0.0, count: count)
        let minR = [Float](repeating: 0.045, count: count)
        var maxR = [Float](repeating: 0.105, count: count)
        
        for r in 0..<n {
            for c in 0..<n {
                let idx = r * n + c
                if (r + c) % 2 == 0 {
                    f[idx] = 0.70
                    maxR[idx] = 0.115
                } else {
                    f[idx] = -0.65
                    maxR[idx] = 0.095
                }
            }
        }
        return SimulationPreset(
            name: "幾何晶格",
            subtitle: "對稱分子結晶",
            icon: "hexagon.fill",
            isBuiltIn: true,
            numTypes: n,
            friction: 0.88,
            paletteID: 7, // Cold Blue
            ruleMatrix: f,
            rMinMatrix: minR,
            rMaxMatrix: maxR
        )
    }
}
