import SwiftUI

struct ToggleImmersiveSpaceButton: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var isShowingImmersiveSpace = false

    var body: some View {
        Button {
            Task {
                if isShowingImmersiveSpace {
                    // 如果已經開啟，則關閉沉浸空間
                    await dismissImmersiveSpace()
                    isShowingImmersiveSpace = false
                } else {
                    // 根據 App 中定義的 ID 開啟沉浸空間
                    let result = await openImmersiveSpace(id: "ImmersiveSpace")
                    if case .opened = result {
                        isShowingImmersiveSpace = true
                    }
                }
            }
        } label: {
            Text(isShowingImmersiveSpace ? "關閉 3D 粒子空間" : "啟動 3D 粒子空間")
                .font(.title2)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(isShowingImmersiveSpace ? .red : .blue)
    }
}
