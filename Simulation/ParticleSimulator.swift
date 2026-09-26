import Foundation
import Metal
import simd
import Observation

@Observable
class ParticleSimulator {
    // MARK: - Metal 核心物件
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    
    // 三個運算管線 (空間雜湊專用)
    private var clearGridPipeline: MTLComputePipelineState!
    private var buildGridPipeline: MTLComputePipelineState!
    private var computeGridPipeline: MTLComputePipelineState!
    
    // MARK: - GPU 緩衝區 (Buffers)
    private(set) var particleBuffer: MTLBuffer!
    private var ruleMatrixBuffer: MTLBuffer!
    private var paramsBuffer: MTLBuffer!
    private var gridBuffer: MTLBuffer!
    
    // MARK: - 模擬參數與狀態
    var params: SimParams
    var particleCount: Int
    var numTypes: Int
    
    // 控制圓球大小的屬性 (最大值為 0.015)
    var particleScale: Float = 0.004 {
            didSet {
                // 確保舊數值大於 0，避免除以零的錯誤
                guard oldValue > 0 else { return }
                
                // 1. 計算縮放倍率 (新大小 / 舊大小)
                let scaleRatio = particleScale / oldValue
                
                // 2. 將交互作用距離等比例乘上倍率
                params.rMax *= scaleRatio
                params.rMin *= scaleRatio
                
                // 3. 立即將更新後的參數推送到 GPU 緩衝區
                updateParamsBuffer()
            }
    }
    
    var ruleMatrix: [Float] = [] {
        didSet { updateRuleMatrixBuffer() }
    }
    
    // 配合 Entity 實體同步架構，將數量鎖定在 2,500 顆
    init(particleCount: Int = 4000, numTypes: Int = 4) {
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
    
    // MARK: - Metal 初始化
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
            buildGridPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "buildGrid")!)
            computeGridPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "computeGridParticles")!)
        } catch {
            fatalError("Pipeline 初始化失敗: \(error)")
        }
    }
    
    // MARK: - 記憶體配置
    private func setupBuffers() {
        var initialParticles = [Particle]()
        for _ in 0..<particleCount {
            let type = UInt32.random(in: 0..<UInt32(numTypes))
            let p = Particle(
                position: SIMD3<Float>(
                    Float.random(in: -1...1),
                    Float.random(in: -1...1),
                    Float.random(in: -1...1)
                ),
                velocity: SIMD3<Float>(0, 0, 0),
                type: type,
                pad1: 0, pad2: 0, pad3: 0
            )
            initialParticles.append(p)
        }
        
        particleBuffer = device.makeBuffer(bytes: initialParticles,
                                           length: MemoryLayout<Particle>.stride * particleCount,
                                           options: .storageModeShared)
        
        let matrixSize = numTypes * numTypes
        self.ruleMatrix = (0..<matrixSize).map { _ in Float.random(in: -1...1) }
        
        paramsBuffer = device.makeBuffer(length: MemoryLayout<SimParams>.stride,
                                         options: .storageModeShared)
        updateParamsBuffer()
        
        let gridBufferSize = 4096 * 260
        gridBuffer = device.makeBuffer(length: gridBufferSize, options: .storageModePrivate)
    }
    
    private func updateRuleMatrixBuffer() {
        let size = MemoryLayout<Float>.stride * ruleMatrix.count
        ruleMatrixBuffer = device.makeBuffer(bytes: ruleMatrix,
                                             length: size,
                                             options: .storageModeShared)
    }
    
    func updateParamsBuffer() {
        let pointer = paramsBuffer.contents().bindMemory(to: SimParams.self, capacity: 1)
        pointer.pointee = params
    }
    
    // MARK: - 執行 GPU 物理運算 (三階段管線)
    func updateSimulation() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        let numCells = 4096
        
        // 1. 清空網格計數器
        computeEncoder.setComputePipelineState(clearGridPipeline)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 0)
        var w = clearGridPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.dispatchThreadgroups(
            MTLSize(width: (numCells + w - 1) / w, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1)
        )
        
        // 2. 建立網格
        computeEncoder.setComputePipelineState(buildGridPipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        w = buildGridPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.dispatchThreadgroups(
            MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1)
        )
        
        // 3. 網格化物理運算
        computeEncoder.setComputePipelineState(computeGridPipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(ruleMatrixBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(gridBuffer, offset: 0, index: 3)
        w = computeGridPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.dispatchThreadgroups(
            MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1)
        )
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        
        // 卡住 CPU，確保 RealityKit 抓取座標前 GPU 已計算完畢
        commandBuffer.waitUntilCompleted()
    }
}
