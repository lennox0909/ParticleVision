import Foundation
import Metal
import simd
import Observation
import RealityKit
import QuartzCore
import SwiftUI

@Observable
class ParticleSimulator {
    // ✨ 新增：使用者自訂儲存的宇宙快照清單與當前啟用的快照 ID
    var customPresets: [SimulationPreset] = []
    var activePresetID: UUID? = nil

    /// 防止批次套用預設集時觸發多次 GPU Buffer 更新
    var isBatchUpdating: Bool = false

    var ruleMatrix: [Float] = [] {
        didSet {
            if !isBatchUpdating { updateRuleMatrixBuffer() }
        }
    }

    var rMinMatrix: [Float] = [] {
        didSet {
            if !isBatchUpdating { updateRuleMatrixBuffer() }
        }
    }

    var rMaxMatrix: [Float] = [] {
        didSet {
            if !isBatchUpdating { updateRuleMatrixBuffer() }
        }
    }
    
    // 集中管理左右兩個獨立視窗的開啟狀態
    var showColorWindow: Bool = false
    var showMatrixWindow: Bool = false
    
    // 是否允許手部對透明盒子進行拖曳、旋轉或縮放操作
    var isBoxInteractionEnabled: Bool = true
    
    // ✨ 新增：空間時間控制 (暫停凍結 & 0.1x 慢動作 ~ 2.0x 倍速演化)
    var isPaused: Bool = false
    var timeScale: Float = 1.0 {
        didSet {
            params.dt = 0.016 * timeScale
            updateParamsBuffer()
        }
    }
    
    // ✨ 新增：引力中心奇點模式 (0 = 關閉, 1 = 🌌 星系吸積旋渦, 2 = 🕳️ 黑洞雙極噴流)
    var singularityMode: Int = 0
    
    // ✨ 新增：中心奇點引力強度 (0.2x 微弱引力核 ~ 3.0x 超大質量黑洞)
    var singularityStrength: Float = 1.2
    
    // ✨ 新增：宇宙邊界物理模式 (false = 📦 彈性撈網邊界 Bounce, true = ♾️ 無縫週期穿越 Wrap-around)
    var isWrapBoundary: Bool = false
    
    // ✨ 新增：3D 空間環境音效與指尖力場聲學回饋靜音開關
    var isAudioMuted: Bool = UserDefaults.standard.bool(forKey: "IsAudioMuted") {
        didSet {
            UserDefaults.standard.set(isAudioMuted, forKey: "IsAudioMuted")
        }
    }
    
    // ✨ 左右手「神之手」力場資料 [左手, 右手]（加上 @ObservationIgnored 避免每幀觸發 UI 重繪與巨集歧義）
    @ObservationIgnored
    var handForces: [SIMD4<Float>] = [SIMD4<Float>(repeating: 0), SIMD4<Float>(repeating: 0)]
    
    // 記憶透明盒子在 3D 空間中的座標、大小與旋轉角度
    var boxPosition: SIMD3<Float> = SIMD3<Float>(0.4, 1.1, -0.7)
    var boxScale: SIMD3<Float> = SIMD3<Float>(repeating: 0.1)
    var boxOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    
    // ✨ 新增：透明盒子邊框灰階顏色 (0.0 = 全黑, 0.5 = 灰階, 1.0 = 全白) 與粗細 (0.002 ~ 0.050)
    var boxEdgeGrayscale: Float = 0.85 {
        didSet {
            UserDefaults.standard.set(boxEdgeGrayscale, forKey: "BoxEdgeGrayscale")
        }
    }
    var boxEdgeThickness: Float = 0.012 {
        didSet {
            UserDefaults.standard.set(boxEdgeThickness, forKey: "BoxEdgeThickness")
        }
    }
    
    // 👇 螢光強度的預設值在這裡 (範圍 0.0 ~ 5.0)
    var glowIntensity: Float = 2.0
    var meshResource: MeshResource!
    var lowLevelMesh: LowLevelMesh?
    var updateMeshPipeline: MTLComputePipelineState!
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    
    var clearGridPipeline: MTLComputePipelineState!
    var countGridPipeline: MTLComputePipelineState!
    var prefixSumPipeline: MTLComputePipelineState!
    var reorderPipeline: MTLComputePipelineState!
    var computeGridPipeline: MTLComputePipelineState!
    
    var particleBuffer: MTLBuffer!
    var sortedParticleBuffer: MTLBuffer!
    
    var ruleMatrixBuffer: MTLBuffer!
    var paramsBuffer: MTLBuffer!
    var gridBuffer: MTLBuffer!
    
    var params: SimParams
    var particleCount: Int
    var numTypes: Int
    
    var currentFPS: Int = 0
    private var frameCount: Int = 0
    private var lastFPSUpdateTime: TimeInterval = 0
    
    var needsVisualRebuild: Bool = false
    
    // 👇 粒子大小的預設值在這裡 (範圍 0.005 ~ 0.050) 只負責控制 3D 視覺外觀大小，與物理半徑完全解耦
    var particleScale: Float = 0.005
    
    // ✨ 新增：動能流體拉伸強度 (0.0 = 維持原狀, 1.0 ~ 5.0 = 依速度向量自動拉長為彗星光梭)
    var velocityStretch: Float = 1.0
    
    // ✨ 是否啟用「熱力能量著色模式 (Kinetic Heatmap Mode)」
    var isKineticColorMode: Bool = false
    
    // ✨ 新增：各種類粒子的「即時真實動能測速值 (0.0 極冷靜止 ~ 1.0 極熱高速)」
    var typeKineticEnergies: [Float] = Array(repeating: 0.0, count: 8)
    
    /// ✨ 從 GPU 共享的 particleBuffer 即時抽樣計算各種類粒子的真實運動速度
    func updateLiveKineticEnergies() {
        guard isKineticColorMode,
              let buffer = particleBuffer,
              numTypes > 0,
              particleCount > 0 else { return }
        
        let ptr = buffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        let particlesPerType = max(1, particleCount / numTypes)
        let sampleCount = min(256, particlesPerType) // 每種粒子均勻抽樣 256 顆，耗時不到 0.05ms！
        let step = max(1, particlesPerType / sampleCount)
        
        // 在此物理系統中，jitter 靜止微幅震動約為 0.015，高速追擊或神之手加速約為 0.18 ~ 0.45
        let idleSpeedFloor: Float = 0.018
        let maxRefSpeed: Float = 0.28
        
        var newEnergies = [Float](repeating: 0.0, count: numTypes)
        
        for t in 0..<numTypes {
            let startIdx = t * particlesPerType
            var totalSpeed: Float = 0.0
            var count: Int = 0
            
            var idx = startIdx
            let endIdx = min(particleCount, startIdx + particlesPerType)
            while idx < endIdx {
                let v = ptr[idx].velocity
                totalSpeed += simd_length(v)
                count += 1
                idx += step
            }
            
            let avgSpeed = count > 0 ? (totalSpeed / Float(count)) : 0.0
            // 扣除基礎微擾動 (jitter)，將真實移動速度正規化至 0.0 (靜止深藍) ~ 1.0 (高速白熱紅)
            let normalized = max(0.0, min(1.0, (avgSpeed - idleSpeedFloor) / (maxRefSpeed - idleSpeedFloor)))
            
            // 與上一幀進行指數平滑 (EMA)，讓顏色隨速度升溫/冷卻過渡極度絲滑不閃爍
            let prev = t < typeKineticEnergies.count ? typeKineticEnergies[t] : 0.0
            newEnergies[t] = prev * 0.82 + normalized * 0.18
        }
        
        self.typeKineticEnergies = newEnergies
    }
    
    // 空間摩擦力預設值
    var friction: Float = 0.65 {
        didSet {
            params.friction = friction
            updateParamsBuffer()
        }
    }
    
    // ✨ 新增：當前選中的色票 ID 與生成的顏色陣列 (預設為 1: Rainbow)
    var selectedPaletteID: Int = 1
    var currentColors: [Color] = []
    
    init(particleCount: Int = 50000, numTypes: Int = 6) {
        self.particleCount = particleCount
        self.numTypes = numTypes
        self.params = SimParams(
            dt: 0.016,
            friction: 0.95,
            rMax: 0.12,
            rMin: 0.035,
            numTypes: UInt32(numTypes),
            particleCount: UInt32(particleCount)
        )
        
        // 初始化預設色票
        self.currentColors = ColorPaletteGenerator.generateColors(optionID: selectedPaletteID, numTypes: numTypes)
        
        setupMetal()
        setupBuffers()
        loadBoxTransformFromDisk()
        loadCustomPresetsFromDisk() // ✨ 載入使用者自訂快照
    }
    
    /// ✨ 套用或重新生成指定的 Color Scheme
    func applyPalette(id: Int) {
        self.selectedPaletteID = id
        self.currentColors = ColorPaletteGenerator.generateColors(optionID: id, numTypes: numTypes)
    }
    
    func randomizeRules() {
        let matrixSize = numTypes * numTypes
        
        // ✨ 開啟批次更新標記，避免重複重建 Buffer
        self.isBatchUpdating = true
        
        self.rMinMatrix = (0..<matrixSize).map { _ in Float.random(in: 0.010...0.045) }
        self.rMaxMatrix = (0..<matrixSize).map { _ in Float.random(in: 0.060...0.125) }
        self.ruleMatrix = (0..<matrixSize).map { _ in Float.random(in: -1...1) }
        
        self.isBatchUpdating = false
        self.updateRuleMatrixBuffer() // 統一寫入 GPU
    }
    
    func resetSimulation(newCount: Int, newTypes: Int) {
        self.particleCount = newCount
        self.numTypes = newTypes
        
        self.params.particleCount = UInt32(newCount)
        self.params.numTypes = UInt32(newTypes)
        self.params.friction = self.friction
        self.params.dt = 0.016 * self.timeScale // ✨ 保持當前時間流速倍率
        
        // ✨ 當粒子種類數改變時，根據當前選中的色票重新生成對應數量的顏色
        self.currentColors = ColorPaletteGenerator.generateColors(optionID: selectedPaletteID, numTypes: newTypes)
        
        setupBuffers()
        self.needsVisualRebuild = true
    }
    
    func applyInertia(oldBoxMatrix: simd_float4x4, newBoxMatrix: simd_float4x4) {
        let relativeTransform = newBoxMatrix.inverse * oldBoxMatrix
        
        let rotOld = simd_float3x3(
            SIMD3<Float>(oldBoxMatrix.columns.0.x, oldBoxMatrix.columns.0.y, oldBoxMatrix.columns.0.z),
            SIMD3<Float>(oldBoxMatrix.columns.1.x, oldBoxMatrix.columns.1.y, oldBoxMatrix.columns.1.z),
            SIMD3<Float>(oldBoxMatrix.columns.2.x, oldBoxMatrix.columns.2.y, oldBoxMatrix.columns.2.z)
        )
        let rotNew = simd_float3x3(
            SIMD3<Float>(newBoxMatrix.columns.0.x, newBoxMatrix.columns.0.y, newBoxMatrix.columns.0.z),
            SIMD3<Float>(newBoxMatrix.columns.1.x, newBoxMatrix.columns.1.y, newBoxMatrix.columns.1.z),
            SIMD3<Float>(newBoxMatrix.columns.2.x, newBoxMatrix.columns.2.y, newBoxMatrix.columns.2.z)
        )
        let relativeRotation = rotNew.inverse * rotOld
        
        let pointer = particleBuffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        
        for i in 0..<particleCount {
            var p = pointer[i]
            let pos4 = SIMD4<Float>(p.position, 1.0)
            let newPos4 = relativeTransform * pos4
            p.position = SIMD3<Float>(newPos4.x, newPos4.y, newPos4.z)
            p.velocity = relativeRotation * p.velocity
            pointer[i] = p
        }
    }
    
    func updateFPS() {
        let currentTime = CACurrentMediaTime()
        frameCount += 1
        
        if currentTime - lastFPSUpdateTime >= 1.0 {
            DispatchQueue.main.async {
                self.currentFPS = self.frameCount
                self.frameCount = 0
            }
            lastFPSUpdateTime = currentTime
        }
    }
    
    /// 重置 FPS 計數器（於關閉 3D 粒子空間時呼叫）
    func resetFPS() {
        currentFPS = 0
        // 若你有定義 frameCount = 0 也一併在此歸零
    }
    
    // MARK: - 1. Forces (引力矩陣) 控制 API
    
    func getRule(from typeA: Int, to typeB: Int) -> Float {
        let index = typeA * numTypes + typeB
        guard index >= 0 && index < ruleMatrix.count else { return 0.0 }
        return ruleMatrix[index]
    }
    
    func setRule(from typeA: Int, to typeB: Int, value: Float) {
        let index = typeA * numTypes + typeB
        guard index >= 0 && index < ruleMatrix.count else { return }
        ruleMatrix[index] = value
    }
    
    func setRowRules(row: Int, value: Float) {
        guard row >= 0 && row < numTypes else { return }
        var updated = ruleMatrix
        for col in 0..<numTypes { updated[row * numTypes + col] = value }
        ruleMatrix = updated
    }
    
    func setColRules(col: Int, value: Float) {
        guard col >= 0 && col < numTypes else { return }
        var updated = ruleMatrix
        for row in 0..<numTypes { updated[row * numTypes + col] = value }
        ruleMatrix = updated
    }
    
    func setAllRules(value: Float = 0.0) {
        self.ruleMatrix = Array(repeating: value, count: numTypes * numTypes)
    }
    
    // MARK: - 2. Min. Radius (最小排斥半徑矩陣) 控制 API
    
    func getMinRadius(from typeA: Int, to typeB: Int) -> Float {
        let index = typeA * numTypes + typeB
        guard index >= 0 && index < rMinMatrix.count else { return 0.035 }
        return rMinMatrix[index]
    }
    
    func setMinRadius(from typeA: Int, to typeB: Int, value: Float) {
        let index = typeA * numTypes + typeB
        guard index >= 0 && index < rMinMatrix.count else { return }
        rMinMatrix[index] = value
    }
    
    func setRowMinRadius(row: Int, value: Float) {
        guard row >= 0 && row < numTypes else { return }
        var updated = rMinMatrix
        for col in 0..<numTypes { updated[row * numTypes + col] = value }
        rMinMatrix = updated
    }
    
    func setColMinRadius(col: Int, value: Float) {
        guard col >= 0 && col < numTypes else { return }
        var updated = rMinMatrix
        for row in 0..<numTypes { updated[row * numTypes + col] = value }
        rMinMatrix = updated
    }
    
    func setAllMinRadius(value: Float = 0.035) {
        self.rMinMatrix = Array(repeating: value, count: numTypes * numTypes)
    }
    
    // MARK: - 3. Max. Radius (最大感知半徑矩陣) 控制 API
    
    func getMaxRadius(from typeA: Int, to typeB: Int) -> Float {
        let index = typeA * numTypes + typeB
        guard index >= 0 && index < rMaxMatrix.count else { return 0.120 }
        return rMaxMatrix[index]
    }
    
    func setMaxRadius(from typeA: Int, to typeB: Int, value: Float) {
        let index = typeA * numTypes + typeB
        guard index >= 0 && index < rMaxMatrix.count else { return }
        rMaxMatrix[index] = value
    }
    
    func setRowMaxRadius(row: Int, value: Float) {
        guard row >= 0 && row < numTypes else { return }
        var updated = rMaxMatrix
        for col in 0..<numTypes { updated[row * numTypes + col] = value }
        rMaxMatrix = updated
    }
    
    func setColMaxRadius(col: Int, value: Float) {
        guard col >= 0 && col < numTypes else { return }
        var updated = rMaxMatrix
        for row in 0..<numTypes { updated[row * numTypes + col] = value }
        rMaxMatrix = updated
    }
    
    func setAllMaxRadius(value: Float = 0.120) {
        self.rMaxMatrix = Array(repeating: value, count: numTypes * numTypes)
    }
    
    /// ✨ 取得對應粒子種類的代表色（直接回傳當前動態色票陣列的顏色）
    func colorForType(_ type: Int) -> Color {
        guard !currentColors.isEmpty else { return .white }
        return currentColors[type % currentColors.count]
    }
    
    // MARK: - 透明盒子空間狀態與外觀 (Position / Scale / Orientation / Edge Color & Thickness) 儲存與還原
    
    /// 從 UserDefaults 讀取上次儲存的盒子空間狀態與邊框設定
    func loadBoxTransformFromDisk() {
        if let savedScale = UserDefaults.standard.array(forKey: "BoxScale") as? [Float], savedScale.count == 3 {
            self.boxScale = SIMD3<Float>(savedScale[0], savedScale[1], savedScale[2])
        }
        if let savedPos = UserDefaults.standard.array(forKey: "BoxPosition") as? [Float], savedPos.count == 3 {
            self.boxPosition = SIMD3<Float>(savedPos[0], savedPos[1], savedPos[2])
        }
        if let savedRot = UserDefaults.standard.array(forKey: "BoxRotation") as? [Float], savedRot.count == 4 {
            self.boxOrientation = simd_quatf(ix: savedRot[0], iy: savedRot[1], iz: savedRot[2], r: savedRot[3])
        }
        
        // ✨ 讀取邊框灰階顏色與邊框粗細（若曾儲存過則還原）
        if UserDefaults.standard.object(forKey: "BoxEdgeGrayscale") != nil {
            self.boxEdgeGrayscale = UserDefaults.standard.float(forKey: "BoxEdgeGrayscale")
        }
        if UserDefaults.standard.object(forKey: "BoxEdgeThickness") != nil {
            self.boxEdgeThickness = UserDefaults.standard.float(forKey: "BoxEdgeThickness")
        }
    }
    
    /// 即時記錄並儲存 containerBox 當前的空間座標、縮放大小、旋轉角度與邊框設定
    func saveBoxTransform(from box: Entity) {
        self.boxPosition = box.position
        self.boxScale = box.scale
        self.boxOrientation = box.orientation
        
        UserDefaults.standard.set([box.scale.x, box.scale.y, box.scale.z], forKey: "BoxScale")
        UserDefaults.standard.set([box.position.x, box.position.y, box.position.z], forKey: "BoxPosition")
        UserDefaults.standard.set([
            box.orientation.vector.x,
            box.orientation.vector.y,
            box.orientation.vector.z,
            box.orientation.vector.w
        ], forKey: "BoxRotation")
        
        // ✨ 同步確保邊框顏色與粗細寫入磁碟
        UserDefaults.standard.set(self.boxEdgeGrayscale, forKey: "BoxEdgeGrayscale")
        UserDefaults.standard.set(self.boxEdgeThickness, forKey: "BoxEdgeThickness")
    }
    
    /// 將記憶的空間狀態（大小、旋轉、座標）與邊框外觀一併套用至 containerBox
    func applySavedTransform(to box: Entity) {
        box.scale = self.boxScale
        box.orientation = self.boxOrientation
        box.position = self.boxPosition
        
        // 同步套用記憶的邊框灰階顏色與粗細
        box.updateBoxEdgesAppearance(
            grayscale: self.boxEdgeGrayscale,
            thickness: self.boxEdgeThickness
        )
    }
}
