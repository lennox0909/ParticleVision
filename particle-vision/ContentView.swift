import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                
                Text("Particle Life 控制台")
                    .font(.extraLargeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                ControlPanelView()
                
                ToggleImmersiveSpaceButton()
                    .padding(.bottom, 20)
            }
            // 1. 加回內縮間距，讓元件不會貼死在玻璃邊緣
            .padding(40)
            // 2. 強制 VStack 內的元件從最上方開始排列，避免跑版
            .frame(maxWidth: .infinity, alignment: .top)
        }
        // 3. 改用明確的寬高，避免 minHeight 過大導致系統裁切畫面頂部
        .frame(width: 600, height: 800)
    }
}
