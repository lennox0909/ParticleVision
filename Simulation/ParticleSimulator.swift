import Foundation
import Metal
import simd
import Observation

struct Particle {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var type: UInt32
    var originalIndex: UInt32
    var pad2: UInt32
    var pad3: UInt32
}

struct SimParams {
    var dt: Float
    var friction: Float
    var rMax: Float
    var rMin: Float
    var numTypes: UInt32
    var particleCount: UInt32
}

@Observable
class ParticleSimulator {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    
    private var clearGridPipeline: MTLComputePipelineState!
    private var countGridPipeline: MTLComputePipelineState!
    private var prefixSumPipeline: MTLComputePipelineState!
    private var reorderPipeline: MTLComputePipelineState!
    private var computeGridPipeline: MTLComputePipelineState!
    
    private(set) var particleBuffer: MTLBuffer!
    private var sortedParticleBuffer: MTLBuffer!
    
    private var ruleMatrixBuffer: MTLBuffer!
    private var paramsBuffer: MTLBuffer!
    private var gridBuffer: MTLBuffer!
    
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
    
    // 【新增】空間摩擦力屬性，變更時即時同步給 GPU
    var friction: Float = 0.95 {
        didSet {
            params.friction = friction
            updateParamsBuffer()
        }
    }
    
    var ruleMatrix: [Float] = [] {
        didSet { updateRuleMatrixBuffer() }
    }
    
    init(particleCount: Int = 2500, numTypes: Int = 6) {
        self.particleCount = particleCount
        self.numTypes = numTypes
        self.params = SimParams(
            dt: 0.016,
            friction: 0.95, // 初始預設摩擦力
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
        // 重置時確保摩擦力參數同步
        self.params.friction = self.friction
        
        setupBuffers()
        self.needsVisualRebuild = true
    }
    
    private func setupMetal() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice(),
              let queue = defaultDevice.makeCommandQueue() else {
            fatalError("無法初始化 Metal 裝置。")
        }
        self.device = defaultDevice
        self.commandQueue = queue
        
        guard let library = device.makeDefaultLibrary() else {
            fatalError("找不到 default.metallib。")
        }
        
        do {
            clearGridPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "clearGrid")!)
            countGridPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "countGrid")!)
            prefixSumPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "prefixSumGrid")!)
            reorderPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "reorderParticles")!)
            computeGridPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "computeGridParticles")!)
        } catch {
            fatalError("Pipeline 初始化失敗: \(error)")
        }
    }
    
    private func setupBuffers() {
        var initialParticles = [Particle]()
        for i in 0..<particleCount {
            let type = UInt32.random(in: 0..<UInt32(numTypes))
            let p = Particle(
                position: SIMD3<Float>(
                    Float.random(in: -1...1),
                    Float.random(in: -1...1),
                    Float.random(in: -1...1)
                ),
                velocity: SIMD3<Float>(0, 0, 0),
                type: type,
                originalIndex: UInt32(i),
                pad2: 0,
                pad3: 0
            )
            initialParticles.append(p)
        }
        
        let bufferSize = MemoryLayout<Particle>.stride * particleCount
        particleBuffer = device.makeBuffer(bytes: initialParticles, length: bufferSize, options: .storageModeShared)
        sortedParticleBuffer = device.makeBuffer(length: bufferSize, options: .storageModePrivate)
        
        let matrixSize = numTypes * numTypes
        self.ruleMatrix = (0..<matrixSize).map { _ in Float.random(in: -1...1) }
        
        paramsBuffer = device.makeBuffer(length: MemoryLayout<SimParams>.stride, options: .storageModeShared)
        updateParamsBuffer()
        
        // 記憶體 16 bytes 對齊 (防止 GPU 溢位)
        let gridBufferSize = 4096 * 16
        gridBuffer = device.makeBuffer(length: gridBufferSize, options: .storageModePrivate)
    }
    
    private func updateRuleMatrixBuffer() {
        let size = MemoryLayout<Float>.stride * ruleMatrix.count
        ruleMatrixBuffer = device.makeBuffer(bytes: ruleMatrix, length: size, options: .storageModeShared)
    }
    
    func updateParamsBuffer() {
        let pointer = paramsBuffer.contents().bindMemory(to: SimParams.self, capacity: 1)
        pointer.pointee = params
    }
    
    func updateSimulation() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        let numCells = 4096
        var w = clearGridPipeline.maxTotalThreadsPerThreadgroup
        
        computeEncoder.setComputePipelineState(clearGridPipeline)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 0)
        computeEncoder.dispatchThreadgroups(MTLSize(width: (numCells + w - 1) / w, height: 1, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        
        computeEncoder.memoryBarrier(scope: .buffers)
        
        w = countGridPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.setComputePipelineState(countGridPipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        computeEncoder.dispatchThreadgroups(MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        
        computeEncoder.memoryBarrier(scope: .buffers)
        
        computeEncoder.setComputePipelineState(prefixSumPipeline)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 0)
        computeEncoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
        
        computeEncoder.memoryBarrier(scope: .buffers)
        
        w = reorderPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.setComputePipelineState(reorderPipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(sortedParticleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 3)
        computeEncoder.dispatchThreadgroups(MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        
        computeEncoder.memoryBarrier(scope: .buffers)
        
        w = computeGridPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.setComputePipelineState(computeGridPipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(sortedParticleBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(ruleMatrixBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 4)
        computeEncoder.dispatchThreadgroups(MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
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
