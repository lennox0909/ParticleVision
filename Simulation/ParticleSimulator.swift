import Foundation
import Metal
import simd
import Observation
import RealityKit
import QuartzCore
import SwiftUI

// MARK: - 1. 系統與外觀設定 (SRP: System Settings)
@Observable
class SystemSettings {
    var isZenMode: Bool = UserDefaults.standard.object(forKey: "isZenMode") as? Bool ?? true {
        didSet { UserDefaults.standard.set(isZenMode, forKey: "isZenMode") }
    }
    var particleScale: Float = UserDefaults.standard.object(forKey: "particleScale") as? Float ?? 0.005 {
        didSet { UserDefaults.standard.set(particleScale, forKey: "particleScale") }
    }
    var velocityStretch: Float = UserDefaults.standard.object(forKey: "velocityStretch") as? Float ?? 1.0 {
        didSet { UserDefaults.standard.set(velocityStretch, forKey: "velocityStretch") }
    }
    var glowIntensity: Float = UserDefaults.standard.object(forKey: "glowIntensity") as? Float ?? 2.0 {
        didSet { UserDefaults.standard.set(glowIntensity, forKey: "glowIntensity") }
    }
    var isAudioMuted: Bool = UserDefaults.standard.bool(forKey: "IsAudioMuted") {
        didSet { UserDefaults.standard.set(isAudioMuted, forKey: "IsAudioMuted") }
    }
    var boxEdgeGrayscale: Float = 0.85 {
        didSet { UserDefaults.standard.set(boxEdgeGrayscale, forKey: "BoxEdgeGrayscale") }
    }
    var boxEdgeThickness: Float = 0.012 {
        didSet { UserDefaults.standard.set(boxEdgeThickness, forKey: "BoxEdgeThickness") }
    }
}

// MARK: - 2. 物理與環境狀態 (SRP: Physics Environment)
@Observable
class PhysicsEnvironment {
    @ObservationIgnored var onParamsChanged: (() -> Void)?
    @ObservationIgnored var onMatrixChanged: (() -> Void)?
    @ObservationIgnored var isBatchUpdating: Bool = false
    
    var isPaused: Bool = false
    var isWrapBoundary: Bool = false
    var singularityMode: Int = 0
    var singularityStrength: Float = 1.2
    
    var timeScale: Float = 1.0 {
        didSet { onParamsChanged?() }
    }
    var friction: Float = 0.65 {
        didSet { onParamsChanged?() }
    }
    
    var ruleMatrix: [Float] = [] {
        didSet { if !isBatchUpdating { onMatrixChanged?() } }
    }
    var rMinMatrix: [Float] = [] {
        didSet { if !isBatchUpdating { onMatrixChanged?() } }
    }
    var rMaxMatrix: [Float] = [] {
        didSet { if !isBatchUpdating { onMatrixChanged?() } }
    }
}

// MARK: - 3. 空間與互動狀態 (SRP: Spatial Interaction)
@Observable
class SpatialInteraction {
    var isBoxInteractionEnabled: Bool = true
    var boxPosition: SIMD3<Float> = SIMD3<Float>(0.4, 1.1, -0.7)
    var boxScale: SIMD3<Float> = SIMD3<Float>(repeating: 0.1)
    var boxOrientation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    
    @ObservationIgnored
    var handForces: [SIMD4<Float>] = [SIMD4<Float>(repeating: 0), SIMD4<Float>(repeating: 0)]
}

// MARK: - 4. 視覺與色彩狀態 (SRP: Appearance State)
@Observable
class AppearanceState {
    var showColorWindow: Bool = false
    var showMatrixWindow: Bool = false
    
    var isKineticColorMode: Bool = false
    var typeKineticEnergies: [Float] = Array(repeating: 0.0, count: 8)
    
    var selectedPaletteID: Int = 1
    var currentColors: [Color] = []
}

// MARK: - 5. 主引擎 Coordinator (CARP: Particle Simulator)
@Observable
class ParticleSimulator {
    
    // ✨ CARP：將不同職責的模組作為元件「組合」進來
    var settings = SystemSettings()
    var physics = PhysicsEnvironment()
    var spatial = SpatialInteraction()
    var appearance = AppearanceState()
    
    // 全域宇宙快照狀態
    var customPresets: [SimulationPreset] = []
    var activePresetID: UUID? = nil
    var needsVisualRebuild: Bool = false
    
    // 內部基礎設定
    var particleCount: Int
    var numTypes: Int
    var params: SimParams
    
    var currentFPS: Int = 0
    private var frameCount: Int = 0
    private var lastFPSUpdateTime: TimeInterval = 0
    
    // MARK: - Metal 與 GPU 資源
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
        
        // 註冊物理環境的回調事件，解耦 Metal API
        self.physics.onParamsChanged = { [weak self] in
            guard let self = self else { return }
            self.params.dt = 0.016 * self.physics.timeScale
            self.params.friction = self.physics.friction
            self.updateParamsBuffer()
        }
        
        self.physics.onMatrixChanged = { [weak self] in
            self?.updateRuleMatrixBuffer()
        }
        
        // 初始化色票
        self.appearance.currentColors = ColorPaletteGenerator.generateColors(optionID: appearance.selectedPaletteID, numTypes: numTypes)
        
        // 啟動 Metal 流程與讀取記憶狀態
        setupMetal()
        setupBuffers()
        loadBoxTransformFromDisk()
        loadCustomPresetsFromDisk()
    }
    
    // MARK: - 核心邏輯橋接方法
    
    func updateLiveKineticEnergies() {
        guard appearance.isKineticColorMode, let buffer = particleBuffer, numTypes > 0, particleCount > 0 else { return }
        
        let ptr = buffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        let particlesPerType = max(1, particleCount / numTypes)
        let sampleCount = min(256, particlesPerType)
        let step = max(1, particlesPerType / sampleCount)
        
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
                totalSpeed += simd_length(ptr[idx].velocity)
                count += 1
                idx += step
            }
            
            let avgSpeed = count > 0 ? (totalSpeed / Float(count)) : 0.0
            let normalized = max(0.0, min(1.0, (avgSpeed - idleSpeedFloor) / (maxRefSpeed - idleSpeedFloor)))
            
            let prev = t < appearance.typeKineticEnergies.count ? appearance.typeKineticEnergies[t] : 0.0
            newEnergies[t] = prev * 0.82 + normalized * 0.18
        }
        
        self.appearance.typeKineticEnergies = newEnergies
    }
    
    func applyPalette(id: Int) {
        self.appearance.selectedPaletteID = id
        self.appearance.currentColors = ColorPaletteGenerator.generateColors(optionID: id, numTypes: numTypes)
    }
    
    func randomizeRules() {
        let matrixSize = numTypes * numTypes
        self.physics.isBatchUpdating = true
        self.physics.rMinMatrix = (0..<matrixSize).map { _ in Float.random(in: 0.010...0.045) }
        self.physics.rMaxMatrix = (0..<matrixSize).map { _ in Float.random(in: 0.060...0.125) }
        self.physics.ruleMatrix = (0..<matrixSize).map { _ in Float.random(in: -1...1) }
        self.physics.isBatchUpdating = false
        self.updateRuleMatrixBuffer()
    }
    
    func resetSimulation(newCount: Int, newTypes: Int) {
        self.particleCount = newCount
        self.numTypes = newTypes
        self.params.particleCount = UInt32(newCount)
        self.params.numTypes = UInt32(newTypes)
        self.params.dt = 0.016 * self.physics.timeScale
        
        self.activePresetID = nil
        
        if let randomPalette = ColorPaletteGenerator.palettes.randomElement() {
            self.appearance.selectedPaletteID = randomPalette.id
        }
        self.appearance.currentColors = ColorPaletteGenerator.generateColors(optionID: self.appearance.selectedPaletteID, numTypes: newTypes)
        
        self.physics.friction = Float.random(in: 0.30...0.95)
        self.params.friction = self.physics.friction
        
        setupBuffers()
        self.randomizeRules()
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
    
    func resetFPS() { currentFPS = 0 }
    
    // MARK: - 矩陣存取與修改控制 API
    
    func getRule(from typeA: Int, to typeB: Int) -> Float {
        let idx = typeA * numTypes + typeB
        guard idx >= 0 && idx < physics.ruleMatrix.count else { return 0.0 }
        return physics.ruleMatrix[idx]
    }
    func setRule(from typeA: Int, to typeB: Int, value: Float) {
        let idx = typeA * numTypes + typeB
        guard idx >= 0 && idx < physics.ruleMatrix.count else { return }
        physics.ruleMatrix[idx] = value
    }
    func setRowRules(row: Int, value: Float) {
        guard row >= 0 && row < numTypes else { return }
        var updated = physics.ruleMatrix
        for col in 0..<numTypes { updated[row * numTypes + col] = value }
        physics.ruleMatrix = updated
    }
    func setColRules(col: Int, value: Float) {
        guard col >= 0 && col < numTypes else { return }
        var updated = physics.ruleMatrix
        for row in 0..<numTypes { updated[row * numTypes + col] = value }
        physics.ruleMatrix = updated
    }
    func setAllRules(value: Float = 0.0) {
        self.physics.ruleMatrix = Array(repeating: value, count: numTypes * numTypes)
    }
    
    func getMinRadius(from typeA: Int, to typeB: Int) -> Float {
        let idx = typeA * numTypes + typeB
        guard idx >= 0 && idx < physics.rMinMatrix.count else { return 0.035 }
        return physics.rMinMatrix[idx]
    }
    func setMinRadius(from typeA: Int, to typeB: Int, value: Float) {
        let idx = typeA * numTypes + typeB
        guard idx >= 0 && idx < physics.rMinMatrix.count else { return }
        physics.rMinMatrix[idx] = value
    }
    func setRowMinRadius(row: Int, value: Float) {
        guard row >= 0 && row < numTypes else { return }
        var updated = physics.rMinMatrix
        for col in 0..<numTypes { updated[row * numTypes + col] = value }
        physics.rMinMatrix = updated
    }
    func setColMinRadius(col: Int, value: Float) {
        guard col >= 0 && col < numTypes else { return }
        var updated = physics.rMinMatrix
        for row in 0..<numTypes { updated[row * numTypes + col] = value }
        physics.rMinMatrix = updated
    }
    func setAllMinRadius(value: Float = 0.035) {
        self.physics.rMinMatrix = Array(repeating: value, count: numTypes * numTypes)
    }
    
    func getMaxRadius(from typeA: Int, to typeB: Int) -> Float {
        let idx = typeA * numTypes + typeB
        guard idx >= 0 && idx < physics.rMaxMatrix.count else { return 0.120 }
        return physics.rMaxMatrix[idx]
    }
    func setMaxRadius(from typeA: Int, to typeB: Int, value: Float) {
        let idx = typeA * numTypes + typeB
        guard idx >= 0 && idx < physics.rMaxMatrix.count else { return }
        physics.rMaxMatrix[idx] = value
    }
    func setRowMaxRadius(row: Int, value: Float) {
        guard row >= 0 && row < numTypes else { return }
        var updated = physics.rMaxMatrix
        for col in 0..<numTypes { updated[row * numTypes + col] = value }
        physics.rMaxMatrix = updated
    }
    func setColMaxRadius(col: Int, value: Float) {
        guard col >= 0 && col < numTypes else { return }
        var updated = physics.rMaxMatrix
        for row in 0..<numTypes { updated[row * numTypes + col] = value }
        physics.rMaxMatrix = updated
    }
    func setAllMaxRadius(value: Float = 0.120) {
        self.physics.rMaxMatrix = Array(repeating: value, count: numTypes * numTypes)
    }
    
    func colorForType(_ type: Int) -> Color {
        guard !appearance.currentColors.isEmpty else { return .white }
        return appearance.currentColors[type % appearance.currentColors.count]
    }
    
    // MARK: - 儲存與還原
    
    func loadBoxTransformFromDisk() {
        if let savedScale = UserDefaults.standard.array(forKey: "BoxScale") as? [Float], savedScale.count == 3 {
            self.spatial.boxScale = SIMD3<Float>(savedScale[0], savedScale[1], savedScale[2])
        }
        if let savedPos = UserDefaults.standard.array(forKey: "BoxPosition") as? [Float], savedPos.count == 3 {
            self.spatial.boxPosition = SIMD3<Float>(savedPos[0], savedPos[1], savedPos[2])
        }
        if let savedRot = UserDefaults.standard.array(forKey: "BoxRotation") as? [Float], savedRot.count == 4 {
            self.spatial.boxOrientation = simd_quatf(ix: savedRot[0], iy: savedRot[1], iz: savedRot[2], r: savedRot[3])
        }
        
        if UserDefaults.standard.object(forKey: "BoxEdgeGrayscale") != nil {
            self.settings.boxEdgeGrayscale = UserDefaults.standard.float(forKey: "BoxEdgeGrayscale")
        }
        if UserDefaults.standard.object(forKey: "BoxEdgeThickness") != nil {
            self.settings.boxEdgeThickness = UserDefaults.standard.float(forKey: "BoxEdgeThickness")
        }
    }
    
    func saveBoxTransform(from box: Entity) {
        self.spatial.boxPosition = box.position
        self.spatial.boxScale = box.scale
        self.spatial.boxOrientation = box.orientation
        
        UserDefaults.standard.set([box.scale.x, box.scale.y, box.scale.z], forKey: "BoxScale")
        UserDefaults.standard.set([box.position.x, box.position.y, box.position.z], forKey: "BoxPosition")
        UserDefaults.standard.set([
            box.orientation.vector.x,
            box.orientation.vector.y,
            box.orientation.vector.z,
            box.orientation.vector.w
        ], forKey: "BoxRotation")
        
        UserDefaults.standard.set(self.settings.boxEdgeGrayscale, forKey: "BoxEdgeGrayscale")
        UserDefaults.standard.set(self.settings.boxEdgeThickness, forKey: "BoxEdgeThickness")
    }
    
    func applySavedTransform(to box: Entity) {
        box.scale = self.spatial.boxScale
        box.orientation = self.spatial.boxOrientation
        box.position = self.spatial.boxPosition
        
        box.updateBoxEdgesAppearance(
            grayscale: self.settings.boxEdgeGrayscale,
            thickness: self.settings.boxEdgeThickness
        )
    }
}

// MARK: - 🚀 舊版 API 無痛相容層 (Facade)
// 提供向下相容：讓 Extension 與尚未修改的 UI 能把 ParticleSimulator 當成以前那樣直接操作！
extension ParticleSimulator {
    // 映射 SystemSettings
    var isZenMode: Bool { get { settings.isZenMode } set { settings.isZenMode = newValue } }
    var particleScale: Float { get { settings.particleScale } set { settings.particleScale = newValue } }
    var velocityStretch: Float { get { settings.velocityStretch } set { settings.velocityStretch = newValue } }
    var glowIntensity: Float { get { settings.glowIntensity } set { settings.glowIntensity = newValue } }
    var isAudioMuted: Bool { get { settings.isAudioMuted } set { settings.isAudioMuted = newValue } }
    var boxEdgeGrayscale: Float { get { settings.boxEdgeGrayscale } set { settings.boxEdgeGrayscale = newValue } }
    var boxEdgeThickness: Float { get { settings.boxEdgeThickness } set { settings.boxEdgeThickness = newValue } }
    
    // 映射 PhysicsEnvironment
    var isPaused: Bool { get { physics.isPaused } set { physics.isPaused = newValue } }
    var isWrapBoundary: Bool { get { physics.isWrapBoundary } set { physics.isWrapBoundary = newValue } }
    var singularityMode: Int { get { physics.singularityMode } set { physics.singularityMode = newValue } }
    var singularityStrength: Float { get { physics.singularityStrength } set { physics.singularityStrength = newValue } }
    var timeScale: Float { get { physics.timeScale } set { physics.timeScale = newValue } }
    var friction: Float { get { physics.friction } set { physics.friction = newValue } }
    var ruleMatrix: [Float] { get { physics.ruleMatrix } set { physics.ruleMatrix = newValue } }
    var rMinMatrix: [Float] { get { physics.rMinMatrix } set { physics.rMinMatrix = newValue } }
    var rMaxMatrix: [Float] { get { physics.rMaxMatrix } set { physics.rMaxMatrix = newValue } }
    var isBatchUpdating: Bool { get { physics.isBatchUpdating } set { physics.isBatchUpdating = newValue } }
    
    // 映射 SpatialInteraction
    var isBoxInteractionEnabled: Bool { get { spatial.isBoxInteractionEnabled } set { spatial.isBoxInteractionEnabled = newValue } }
    var boxPosition: SIMD3<Float> { get { spatial.boxPosition } set { spatial.boxPosition = newValue } }
    var boxScale: SIMD3<Float> { get { spatial.boxScale } set { spatial.boxScale = newValue } }
    var boxOrientation: simd_quatf { get { spatial.boxOrientation } set { spatial.boxOrientation = newValue } }
    var handForces: [SIMD4<Float>] { get { spatial.handForces } set { spatial.handForces = newValue } }
    
    // 映射 AppearanceState
    var showColorWindow: Bool { get { appearance.showColorWindow } set { appearance.showColorWindow = newValue } }
    var showMatrixWindow: Bool { get { appearance.showMatrixWindow } set { appearance.showMatrixWindow = newValue } }
    var isKineticColorMode: Bool { get { appearance.isKineticColorMode } set { appearance.isKineticColorMode = newValue } }
    var typeKineticEnergies: [Float] { get { appearance.typeKineticEnergies } set { appearance.typeKineticEnergies = newValue } }
    var selectedPaletteID: Int { get { appearance.selectedPaletteID } set { appearance.selectedPaletteID = newValue } }
    var currentColors: [Color] { get { appearance.currentColors } set { appearance.currentColors = newValue } }
}
