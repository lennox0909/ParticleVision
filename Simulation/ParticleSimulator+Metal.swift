import Foundation
import Metal
import RealityKit

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
            // ✨ 註冊 Mesh 更新管線
            updateMeshPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "updateMeshVertices")!)
        } catch {
            fatalError("Pipeline 初始化失敗: \(error)")
        }
    }
    
    func setupBuffers() {
        var initialParticles = [Particle]()
        
        // ✨ 修正 1：計算每種顏色的粒子數量，依序發放身分證，不使用 random
        let particlesPerType = particleCount / numTypes
        
        for i in 0..<particleCount {
            // 讓前 1/8 的粒子是 Type 0，接下來是 Type 1... 確保與 Mesh 顏色切塊完美對齊
            let type = UInt32(i / particlesPerType)
            
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
        
        // 擴大為 32768 格
        let gridBufferSize = 32768 * 16
        gridBuffer = device.makeBuffer(length: gridBufferSize, options: .storageModePrivate)
        
        setupMesh()
    }
        
    func setupMesh() {
        var descriptor = LowLevelMesh.Descriptor()
        
        // ✨ 修改：頂點與索引的容量降級為四面體 (4 頂點, 12 索引)
        descriptor.vertexCapacity = particleCount * 4
        descriptor.indexCapacity = particleCount * 12
        descriptor.indexType = .uint32
        
        // 加入 Normal 屬性，並設定記憶體偏移量 (16 Bytes)
        descriptor.vertexAttributes = [
            LowLevelMesh.Attribute(semantic: .position, format: .float3, offset: 0),
            LowLevelMesh.Attribute(semantic: .normal, format: .float3, offset: 16)
        ]
        // 每個頂點的資料總長度變為 32 Bytes (Position 16 + Normal 16)
        descriptor.vertexLayouts = [
            LowLevelMesh.Layout(bufferIndex: 0, bufferStride: 32)
        ]
        
        do {
            let mesh = try LowLevelMesh(descriptor: descriptor)
            let particlesPerType = particleCount / numTypes
            
            // ✨ 修改：每種顏色的索引數量變更為 12 (4 個面 x 3 個點)
            let indicesPerType = particlesPerType * 12
            
            let safeBounds = BoundingBox(
                min: SIMD3<Float>(-2.5, -2.5, -2.5),
                max: SIMD3<Float>(2.5, 2.5, 2.5)
            )
            
            mesh.parts.replaceAll((0..<numTypes).map { typeIndex in
                LowLevelMesh.Part(
                    // 乘上 4 (Bytes) 確保每種顏色的索引範圍不重疊
                    indexOffset: typeIndex * indicesPerType * MemoryLayout<UInt32>.stride,
                    indexCount: indicesPerType,
                    topology: .triangle,
                    materialIndex: typeIndex,
                    bounds: safeBounds
                )
            })
            
            self.lowLevelMesh = mesh
            
            mesh.withUnsafeMutableIndices { rawIndices in
                let typedIndices = rawIndices.bindMemory(to: UInt32.self)
                for i in 0..<particleCount {
                    // ✨ 修改：每個粒子只需偏移 4 個頂點與 12 個索引
                    let vOffset = UInt32(i * 4)
                    let iOffset = i * 12
                    
                    // ✨ 建立四面體的 4 個面
                    // 第 1 面
                    typedIndices[iOffset + 0] = vOffset + 0
                    typedIndices[iOffset + 1] = vOffset + 1
                    typedIndices[iOffset + 2] = vOffset + 2
                    // 第 2 面
                    typedIndices[iOffset + 3] = vOffset + 0
                    typedIndices[iOffset + 4] = vOffset + 3
                    typedIndices[iOffset + 5] = vOffset + 1
                    // 第 3 面
                    typedIndices[iOffset + 6] = vOffset + 0
                    typedIndices[iOffset + 7] = vOffset + 2
                    typedIndices[iOffset + 8] = vOffset + 3
                    // 第 4 面
                    typedIndices[iOffset + 9] = vOffset + 1
                    typedIndices[iOffset + 10] = vOffset + 3
                    typedIndices[iOffset + 11] = vOffset + 2
                }
            }
            self.meshResource = try MeshResource(from: mesh)
            
        } catch {
            print("建立 LowLevelMesh 失敗：\(error)")
        }
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
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let mesh = lowLevelMesh else { return }
        
        let numCells = 32768
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
        
        // 更新 GPU 頂點網格
        let currentVertexBuffer = mesh.replace(bufferIndex: 0, using: commandBuffer)
        w = updateMeshPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.setComputePipelineState(updateMeshPipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(currentVertexBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        computeEncoder.dispatchThreadgroups(MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
