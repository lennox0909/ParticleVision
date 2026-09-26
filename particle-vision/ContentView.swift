import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 頂部放置空間切換按鈕
            ToggleImmersiveSpaceButton()
                .padding(.top, 20)
            
            Divider()
            
            // 載入我們先前建立好的控制面板
            ControlPanelView()
        }
        .frame(minWidth: 500, minHeight: 650)
    }
}
