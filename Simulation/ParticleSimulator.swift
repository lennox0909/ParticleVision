import Foundation
import Metal
import simd
import Observation
import RealityKit
import QuartzCore
import SwiftUI

@Observable
class ParticleSimulator {
    var showColorWindow: Bool = false
    var showMatrixWindow: Bool = false
    var glowIntensity: Float = 0.0
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
    
    // 只負責控制 3D 視覺外觀大小，與物理半徑完全解耦
    var particleScale: Float = 0.015
    
    var friction: Float = 0.95 {
        didSet {
            params.friction = friction
            updateParamsBuffer()
        }
    }
    
    // 三組獨立的 N x N 矩陣：作用力、最小半徑、最大半徑
    var ruleMatrix: [Float] = [] {
        didSet { updateRuleMatrixBuffer() }
    }
    var rMinMatrix: [Float] = [] {
        didSet { updateRuleMatrixBuffer() }
    }
    var rMaxMatrix: [Float] = [] {
        didSet { updateRuleMatrixBuffer() }
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
    }
    
    /// ✨ 套用或重新生成指定的 Color Scheme
    func applyPalette(id: Int) {
        self.selectedPaletteID = id
        self.currentColors = ColorPaletteGenerator.generateColors(optionID: id, numTypes: numTypes)
    }
    
    func randomizeRules() {
        let matrixSize = numTypes * numTypes
        self.rMinMatrix = (0..<matrixSize).map { _ in Float.random(in: 0.010...0.045) }
        self.rMaxMatrix = (0..<matrixSize).map { _ in Float.random(in: 0.060...0.125) }
        self.ruleMatrix = (0..<matrixSize).map { _ in Float.random(in: -1...1) }
    }
    
    func resetSimulation(newCount: Int, newTypes: Int) {
        self.particleCount = newCount
        self.numTypes = newTypes
        
        self.params.particleCount = UInt32(newCount)
        self.params.numTypes = UInt32(newTypes)
        self.params.friction = self.friction
        
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
}
