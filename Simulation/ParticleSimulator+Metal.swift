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
            // 註冊 Mesh 更新管線
            updateMeshPipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "updateMeshVertices")!)
        } catch {
            fatalError("Pipeline 初始化失敗: \(error)")
        }
    }
    
    func setupBuffers() {
        var initialParticles = [Particle]()
        
        // 計算每種顏色的粒子數量，依序發放身分證，確保與 Mesh 顏色切塊完美對齊
        let particlesPerType = particleCount / numTypes
        
        for i in 0..<particleCount {
            let type = min(UInt32(numTypes - 1), UInt32(i / particlesPerType))
            
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
        
        // ✨ 初始化三組獨立的 N x N 矩陣 (Forces / Min. Radius / Max. Radius)
        let matrixSize = numTypes * numTypes
        self.rMinMatrix = Array(repeating: 0.035, count: matrixSize)
        self.rMaxMatrix = Array(repeating: 0.120, count: matrixSize)
        self.ruleMatrix = (0..<matrixSize).map { _ in Float.random(in: -1...1) }
        updateRuleMatrixBuffer()
        
        paramsBuffer = device.makeBuffer(length: MemoryLayout<SimParams>.stride, options: .storageModeShared)
        updateParamsBuffer()
        
        // 32^3 = 32768 格空間網格
        let gridBufferSize = 32768 * 16
        gridBuffer = device.makeBuffer(length: gridBufferSize, options: .storageModePrivate)
        
        setupMesh()
    }
    
    func setupMesh() {
        var descriptor = LowLevelMesh.Descriptor()
        
        // 頂點與索引的容量為四面體 (4 頂點, 12 索引)
        descriptor.vertexCapacity = particleCount * 4
        descriptor.indexCapacity = particleCount * 12
        descriptor.indexType = .uint32
        
        // 加入 Position 與 Normal 屬性 (偏移量 16 Bytes)
        descriptor.vertexAttributes = [
            LowLevelMesh.Attribute(semantic: .position, format: .float3, offset: 0),
            LowLevelMesh.Attribute(semantic: .normal, format: .float3, offset: 16)
        ]
        descriptor.vertexLayouts = [
            LowLevelMesh.Layout(bufferIndex: 0, bufferStride: 32)
        ]
        
        do {
            let mesh = try LowLevelMesh(descriptor: descriptor)
            let particlesPerType = particleCount / numTypes
            let indicesPerType = particlesPerType * 12
            
            let safeBounds = BoundingBox(
                min: SIMD3<Float>(-2.5, -2.5, -2.5),
                max: SIMD3<Float>(2.5, 2.5, 2.5)
            )
            
            mesh.parts.replaceAll((0..<numTypes).map { typeIndex in
                LowLevelMesh.Part(
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
                    let vOffset = UInt32(i * 4)
                    let iOffset = i * 12
                    
                    // 建立四面體的 4 個面
                    typedIndices[iOffset + 0] = vOffset + 0
                    typedIndices[iOffset + 1] = vOffset + 1
                    typedIndices[iOffset + 2] = vOffset + 2
                    
                    typedIndices[iOffset + 3] = vOffset + 0
                    typedIndices[iOffset + 4] = vOffset + 3
                    typedIndices[iOffset + 5] = vOffset + 1
                    
                    typedIndices[iOffset + 6] = vOffset + 0
                    typedIndices[iOffset + 7] = vOffset + 2
                    typedIndices[iOffset + 8] = vOffset + 3
                    
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
    
    /// ✨ 將 Forces、rMin、rMax 三個矩陣交錯打包進同一個 Buffer (符合 GPU float4 的 16-byte 對齊)
    func updateRuleMatrixBuffer() {
        guard device != nil else { return }
        let matrixSize = numTypes * numTypes
        guard ruleMatrix.count == matrixSize,
              rMinMatrix.count == matrixSize,
              rMaxMatrix.count == matrixSize else { return }
        
        // ✨ 修正打包邏輯：交錯寫入 [rule, rMin, rMax, padding]
        var packedData = [SIMD4<Float>](repeating: .zero, count: matrixSize)
        for i in 0..<matrixSize {
            packedData[i] = SIMD4<Float>(
                ruleMatrix[i],
                rMinMatrix[i],
                rMaxMatrix[i],
                0.0 // Padding
            )
        }
        
        let byteSize = MemoryLayout<SIMD4<Float>>.stride * packedData.count
        
        if let buffer = ruleMatrixBuffer, buffer.length == byteSize {
            let ptr = buffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: packedData.count)
            for i in 0..<packedData.count {
                ptr[i] = packedData[i]
            }
        } else {
            ruleMatrixBuffer = device.makeBuffer(bytes: packedData, length: byteSize, options: .storageModeShared)
        }
    }
    
    func updateParamsBuffer() {
        guard let buffer = paramsBuffer else { return }
        let pointer = buffer.contents().bindMemory(to: SimParams.self, capacity: 1)
        pointer.pointee = params
    }
    
    func updateSimulation() {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
              let mesh = lowLevelMesh else { return }
        
        var w = clearGridPipeline.maxTotalThreadsPerThreadgroup
        
        // ✨ 只有在「未暫停」且「時間流速 > 0」時，才執行物理碰撞與座標更新
        // 暫停時保留粒子當下的真實速度向量，讓「彗星光梭拉伸」與「熱力色彩」完美定格在空中供微距觀察！
        if !isPaused && timeScale > 0.001 {
            let numCells = 32768
            
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
            
            // 傳入左右手「神之手」力場座標與狀態至 buffer(5)
            var currentHandForces = self.handForces
            computeEncoder.setBytes(&currentHandForces, length: MemoryLayout<SIMD4<Float>>.stride * 2, index: 5)
            
            // ✨ 新增：傳入宇宙邊界物理模式至 buffer(6) (0 = 彈性撈網 Bounce, 1 = 無縫環形穿越 Wrap-around)
            var boundaryMode: UInt32 = self.isWrapBoundary ? 1 : 0
            computeEncoder.setBytes(&boundaryMode, length: MemoryLayout<UInt32>.stride, index: 6)
            
            // ✨ 新增：傳入中心奇點力場參數至 buffer(7) (x: 模式 0/1/2, y: 奇點強度)
            var singularityParams = SIMD2<Float>(Float(self.singularityMode), self.singularityStrength)
            computeEncoder.setBytes(&singularityParams, length: MemoryLayout<SIMD2<Float>>.stride, index: 7)
            
            computeEncoder.dispatchThreadgroups(MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
                                                threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
            computeEncoder.memoryBarrier(scope: .buffers)
        }
        
        // 更新 GPU 頂點網格（即使在時間暫停時也會執行，讓使用者在凍結瞬間仍可即時調整粒子大小與彗星尾跡滑桿）
        let currentVertexBuffer = mesh.replace(bufferIndex: 0, using: commandBuffer)
        var meshVisualParams = SIMD2<Float>(self.particleScale, self.velocityStretch)
        w = updateMeshPipeline.maxTotalThreadsPerThreadgroup
        computeEncoder.setComputePipelineState(updateMeshPipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(currentVertexBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        computeEncoder.setBytes(&meshVisualParams, length: MemoryLayout<SIMD2<Float>>.stride, index: 3)
        computeEncoder.dispatchThreadgroups(MTLSize(width: (particleCount + w - 1) / w, height: 1, depth: 1),
                                            threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
