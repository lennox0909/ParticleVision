import SwiftUI
import RealityKit

extension ImmersiveView {
    
    func setupParticleVisuals(in parent: Entity) {
        // 1. 直接取得由 Metal 管理的單一 MeshResource
        guard let meshResource = simulator.meshResource else {
            print("無法取得 GPU Mesh 資源")
            return
        }
        
        let numTypes = simulator.numTypes
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow, .systemPurple, .systemOrange]
        
        // 2. 建立對應數量的材質陣列
        var materials: [UnlitMaterial] = []
        for i in 0..<numTypes {
            materials.append(UnlitMaterial(color: colors[i % colors.count]))
        }
        
        // 3. 建立一個包含所有粒子的「超級實體」
        let massiveParticleEntity = ModelEntity()
        massiveParticleEntity.components.set(ModelComponent(
            mesh: meshResource,
            materials: materials // RealityKit 會自動根據 LowLevelMesh.Part 的 materialIndex 套用顏色
        ))
        
        // 4. 加入場景，並存入陣列 (保留陣列是為了相容你原本 UI 重置時的清除邏輯)
        parent.addChild(massiveParticleEntity)
        self.particleEntities = [massiveParticleEntity]
    }
    
    func syncParticlesToVisuals() {
        // 🔥 效能魔法發生在這裡：完全留空！
        // 以前我們要在這裡跑 16,000 次迴圈更新 position。
        // 現在 GPU 每一幀都會直接修改 LowLevelMesh 的頂點資料 (Vertex Buffer)，
        // RealityKit 會自動抓取最新畫面，CPU 再也不用插手粒子的座標同步了！
    }
}
