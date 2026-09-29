import Foundation
import Metal
import simd
import Observation
import RealityKit
import QuartzCore

@Observable
class ParticleSimulator {
    // ✨ 新增這行：發光效果開關
    var glowIntensity: Float = 0.0
    var meshResource: MeshResource!
    var lowLevelMesh: LowLevelMesh?
    var updateMeshPipeline: MTLComputePipelineState!
    // 移除 private，讓 Extension 可以跨檔案存取
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
    
    // ✨ 新增：FPS 相關狀態
    var currentFPS: Int = 0
    private var frameCount: Int = 0
    private var lastFPSUpdateTime: TimeInterval = 0
    
    var needsVisualRebuild: Bool = false
    
    var particleScale: Float = 0.015 {
        didSet {
            guard oldValue > 0 else { return }
            let scaleRatio = particleScale / oldValue
            params.rMax *= scaleRatio
            params.rMin *= scaleRatio
            updateParamsBuffer()
        }
    }
    
    var friction: Float = 0.95 {
        didSet {
            params.friction = friction
            updateParamsBuffer()
        }
    }
    
    var ruleMatrix: [Float] = [] {
        didSet { updateRuleMatrixBuffer() }
    }
    
    init(particleCount: Int = 50000, numTypes: Int = 6) {
        self.particleCount = particleCount
        self.numTypes = numTypes
        self.params = SimParams(
            dt: 0.016,
            friction: 0.95,
            rMax: 0.12,   // ✨ 核心修改：嚴格小於 0.125，確保不跨越相鄰網格邊界
            rMin: 0.035,  // ✨ 對應縮小：大約是 rMax 的 30%，保持細胞薄膜的厚度比例
            numTypes: UInt32(numTypes),
            particleCount: UInt32(particleCount)
        )
        
        setupMetal()
        setupBuffers()
    }
    
    func randomizeRules() {
        let matrixSize = numTypes * numTypes
        self.ruleMatrix = (0..<matrixSize).map { _ in Float.random(in: -1...1) }
    }
    
    func resetSimulation(newCount: Int, newTypes: Int) {
        self.particleCount = newCount
        self.numTypes = newTypes
        
        self.params.particleCount = UInt32(newCount)
        self.params.numTypes = UInt32(newTypes)
        self.params.friction = self.friction
        
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
            
            // 每過 1 秒鐘，結算一次過去一秒內跑了幾幀
            if currentTime - lastFPSUpdateTime >= 1.0 {
                // 切換到 Main Thread 更新 UI 狀態
                DispatchQueue.main.async {
                    self.currentFPS = self.frameCount
                    self.frameCount = 0
                }
                lastFPSUpdateTime = currentTime
            }
    }
    
}
