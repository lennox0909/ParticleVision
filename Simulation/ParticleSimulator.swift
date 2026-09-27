import Foundation
import Metal
import simd
import Observation
import RealityKit

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
            rMax: 0.3,
            rMin: 0.05,
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
}
