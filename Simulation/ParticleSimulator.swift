import Foundation
import Metal
import simd
import Observation

@Observable
class ParticleSimulator {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var computePipelineState: MTLComputePipelineState!
    
    // 開放給 RealityKit 讀取座標
    private(set) var particleBuffer: MTLBuffer!
    private var ruleMatrixBuffer: MTLBuffer!
    private var paramsBuffer: MTLBuffer!
    
    var params: SimParams
    var particleCount: Int
    var numTypes: Int
    
    var ruleMatrix: [Float] = [] {
        didSet { updateRuleMatrixBuffer() }
    }
    
    // 設定黃金數量 2500，視覺效果極佳且絕對不會當機
    init(particleCount: Int = 2500, numTypes: Int = 4) {
        self.particleCount = particleCount
        self.numTypes = numTypes
        self.params = SimParams(dt: 0.016, friction: 0.95, rMax: 0.3, rMin: 0.05, numTypes: UInt32(numTypes), particleCount: UInt32(particleCount))
        
        setupMetal()
        setupBuffers()
    }
    
    private func setupMetal() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice(),
              let queue = defaultDevice.makeCommandQueue() else { fatalError() }
        self.device = defaultDevice
        self.commandQueue = queue
        
        guard let library = device.makeDefaultLibrary(),
              let computeFunction = library.makeFunction(name: "computeParticles") else { fatalError() }
        computePipelineState = try! device.makeComputePipelineState(function: computeFunction)
    }
    
    private func setupBuffers() {
        var initialParticles = [Particle]()
        for _ in 0..<particleCount {
            let type = UInt32.random(in: 0..<UInt32(numTypes))
            let p = Particle(
                position: SIMD3<Float>(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1)),
                velocity: SIMD3<Float>(0, 0, 0),
                type: type, pad1: 0, pad2: 0, pad3: 0
            )
            initialParticles.append(p)
        }
        particleBuffer = device.makeBuffer(bytes: initialParticles, length: MemoryLayout<Particle>.stride * particleCount, options: .storageModeShared)
        
        self.ruleMatrix = (0..<(numTypes * numTypes)).map { _ in Float.random(in: -1...1) }
        paramsBuffer = device.makeBuffer(length: MemoryLayout<SimParams>.stride, options: .storageModeShared)
        updateParamsBuffer()
    }
    
    private func updateRuleMatrixBuffer() {
        ruleMatrixBuffer = device.makeBuffer(bytes: ruleMatrix, length: MemoryLayout<Float>.stride * ruleMatrix.count, options: .storageModeShared)
    }
    
    func updateParamsBuffer() {
        let pointer = paramsBuffer.contents().bindMemory(to: SimParams.self, capacity: 1)
        pointer.pointee = params
    }
    
    // 直接執行運算並等待完成
    func updateSimulation() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        computeEncoder.setComputePipelineState(computePipelineState)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(ruleMatrixBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        
        let w = computePipelineState.maxTotalThreadsPerThreadgroup
        let threadsPerGroup = MTLSize(width: w, height: 1, depth: 1)
        let groupsCount = (particleCount + w - 1) / w
        
        computeEncoder.dispatchThreadgroups(MTLSize(width: groupsCount, height: 1, depth: 1), threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        // 【關鍵修復】卡住 CPU 確保 GPU 算完，這樣 RealityKit 抓到的座標才是最新的
        commandBuffer.waitUntilCompleted()
    }
}
