import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(ParticleSimulator.self) private var simulator
    @State private var particleEntities: [Entity] = []
    
    // 將訂閱存放在這裡，避免被系統回收
    @State private var frameSubscription: EventSubscription?

    var body: some View {
        RealityView { content in
            let rootEntity = Entity()
            // 將粒子群中心放在使用者正前方 1.5 公尺，高度 1.2 公尺處
            rootEntity.position = SIMD3<Float>(0, 1.2, -1.5)
            content.add(rootEntity)
            
            // 1. 生成彩色的立體圓球實體
            setupParticleVisuals(in: rootEntity)
            
            // 2. 先在同步環境下使用 inout 參數 (content) 建立訂閱
            let subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                // 觸發 GPU 計算物理
                simulator.updateSimulation()
                // 抓取 GPU 最新座標更新到 3D 圓球上
                syncParticlesToVisuals()
            }
            
            // 3. 透過 Task 將訂閱物件非同步存入 @State，完美避開記憶體安全限制與 SwiftUI 警告
            Task { @MainActor in
                self.frameSubscription = subscription
            }
            
        }
        .onDisappear {
            // 離開沉浸空間時手動清理迴圈資源
            frameSubscription?.cancel()
            frameSubscription = nil
        }
    }
    
    // MARK: - 初始化粒子視覺
    private func setupParticleVisuals(in root: Entity) {
        let count = simulator.particleCount
        let numTypes = simulator.numTypes
        
        // 設定科技感顏色 (對應 Particle 的 type)
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow, .systemPurple, .systemOrange]
        var materials: [SimpleMaterial] = []
        for i in 0..<numTypes {
            let color = colors[i % colors.count]
            // 使用無光照材質，維持鮮豔度
            var material = SimpleMaterial(color: color, isMetallic: false)
            materials.append(material)
        }
        
        // 建立 1.5 公分的立體圓球網格
        let sphereMesh = MeshResource.generateSphere(radius: 0.015)
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        
        // 依照模擬器初始化的資料建立實體
        for i in 0..<count {
            let particle = pointer[i]
            let typeIndex = Int(particle.type) % materials.count
            
            let entity = ModelEntity(mesh: sphereMesh, materials: [materials[typeIndex]])
            entity.position = particle.position
            
            root.addChild(entity)
            particleEntities.append(entity)
        }
    }
    
    // MARK: - 每一幀同步座標
    private func syncParticlesToVisuals() {
        let count = simulator.particleCount
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        
        // 將 GPU 算好的新座標賦值給 RealityKit 的實體
        for i in 0..<count {
            particleEntities[i].position = pointer[i].position
        }
    }
}
