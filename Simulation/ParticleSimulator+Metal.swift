import Foundation
import Metal

extension ParticleSimulator {
    
    func setupMetal() {
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
    
    func setupBuffers() {
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
        
        // 記憶體 16 bytes 對齊
        let gridBufferSize = 4096 * 16
        gridBuffer = device.makeBuffer(length: gridBufferSize, options: .storageModePrivate)
    }
    
    func updateRuleMatrixBuffer() {
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
}
