import SwiftUI
import RealityKit

extension ImmersiveView {
    
    /// ✨ 建立 visionOS 專屬的高質感透明玻璃材質
    private func createGlassMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        
        // 1. 基礎底色設為極度透明的白色，讓光線穿透
        material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor(white: 1.0, alpha: 0.02))
        
        // 2. 關鍵：開啟透明混合模式，透明度設為 0.15 呈現薄玻璃感
        material.blending = .transparent(opacity: 0.15)
        
        // 3. 玻璃特性：極低粗糙度 (全光滑) 與高金屬度 (增強環境反射)
        material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.0)
        material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.9)
        
        // 4. 關鍵：開啟透明塗層 (Clearcoat)，這能在 visionOS 空間中呈現邊緣的高光折射感
        material.clearcoat = PhysicallyBasedMaterial.Clearcoat(floatLiteral: 1.0)
        material.clearcoatRoughness = PhysicallyBasedMaterial.ClearcoatRoughness(floatLiteral: 0.0)
        
        return material
    }
    
    /// ✨ 初始化盒子正中央 (0, 0, 0) 的 3D 黑洞事件視界核心與外層光子環光暈
    func setupSingularityOrb(in box: Entity) {
        // ✨ 改用透明玻璃球作為核心
        let coreMesh = MeshResource.generateSphere(radius: 0.18) // 稍微放大，使其更具存在感
        let glassMaterial = createGlassMaterial()
        let coreEntity = ModelEntity(mesh: coreMesh, materials: [glassMaterial])
        
        // 外層：保留半透明發光的「吸積光子環光暈 (Photon Ring Halo)」
        let haloMesh = MeshResource.generateSphere(radius: 0.16) // 原本的 halo 稍微縮小，與玻璃球體層次交疊
        let haloMat = UnlitMaterial(color: UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.15)) // 調低 halo 的不透明度
        singularityOrb = ModelEntity(mesh: haloMesh, materials: [haloMat])
        singularityOrb.addChild(coreEntity)
        singularityOrb.position = SIMD3<Float>(0, 0, 0)
        
        box.addChild(singularityOrb)
        updateSingularityVisual()
    }
    
    /// ✨ 根據奇點模式 (0: 關閉, 1: 星系吸積旋渦, 2: 黑洞雙極噴流) 與強度動態更新 3D 中心奇點外觀
    func updateSingularityVisual() {
        guard simulator.singularityMode > 0 else {
            singularityOrb.isEnabled = false
            return
        }
        
        singularityOrb.isEnabled = true
        // ✨ 加入強度控制縮放，讓奇點大小隨著控制面板的滑桿變化
        let scale = 0.75 + simulator.singularityStrength * 0.25
        singularityOrb.scale = SIMD3<Float>(repeating: scale)
        
        // 模式 1 為青色星系引力光暈，模式 2 為紫紅高能黑洞視界光暈
        let haloColor = simulator.singularityMode == 1
        ? UIColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 0.38)
        : UIColor(red: 0.95, green: 0.20, blue: 0.85, alpha: 0.45)
        singularityOrb.model?.materials = [UnlitMaterial(color: haloColor)]
    }
}
