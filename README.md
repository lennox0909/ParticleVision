# 🌌 Particle Life visionOS

![Platform](https://img.shields.io/badge/Platform-visionOS-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343?logo=swift)
![Metal](https://img.shields.io/badge/Technology-Metal%20%7C%20ARKit%20%7C%20RealityKit-blue)

- 為 Apple Vision Pro 打造的「粒子生命 (Particle Life)」模擬器。
- 透過結合 **`Metal Compute Shader`** 的 GPU 平行運算、**`ARKit`** 骨架手勢追蹤，以及 **`RealityKit`** 的沉浸式渲染，玩家可以直接用雙手在空間中「撈取」並擾動這個由數千顆微小粒子組成的浮游生態系。


---

## 📂 專案結構 (Project Structure)

本專案採用清晰的架構，將 UI 介面、渲染層與底層 GPU 物理引擎完全解耦：

```text
.
├── particle-vision/                  # 主要的 App 模組資料夾 (UI 與 3D 視圖)
│   ├── AppModel.swift                # 全域的 App 狀態模型 (通常用來跨 View 共享基礎狀態)
│   ├── Assets.xcassets/              # 靜態資源庫 (包含 AppIcon 3D 圖示層與全域色彩設定)
│   │   ├── AccentColor.colorset/...
│   │   └── AppIcon.solidimagestack/...
│   ├── ContainerDragGesture.swift    # 處理透明盒子拖曳移動的客製化手勢 (分離出的乾淨 ViewModifier)
│   ├── ContainerMagnifyGesture.swift # 處理透明盒子雙手縮放的客製化手勢 (分離出的乾淨 ViewModifier)
│   ├── ContentView.swift             # App 開啟時的主要 2D 視窗 (包含標題、控制面板與啟動按鈕)
│   ├── ControlPanelView.swift        # 控制台 UI 面板 (調整粒子數量、螢光強度、摩擦力、顯示 FPS 等)
│   ├── Entity+Extensions.swift       # RealityKit 實體擴充功能 (例如生成 12 根隱形碰撞邊框的語法糖)
│   ├── ImmersiveView.swift           # 主核心 3D 視圖 (負責建構 RealityView 與掛載空間音效、碰撞體)
│   ├── ImmersiveView+HandTracking.swift # 擴充檔案：專門處理 ARKit 雙手追蹤與空間座標轉換邏輯
│   ├── ImmersiveView+Particles.swift    # 擴充檔案：專門負責將底層模擬器資料同步到 RealityKit 視覺效果
│   ├── Info.plist                    # App 的系統設定檔 (權限宣告、版本號等)
│   ├── ParticleVisionApp.swift       # App 進入點 (@main 宣告，負責註冊 WindowGroup 與 ImmersiveSpace)
│   ├── Resources/                    # RealityKit 專屬的 3D 資源資料夾
│   │   ├── Immersive.usda            # 預設的沉浸式場景設定檔
│   │   ├── Materials/
│   │   │   └── GridMaterial.usda     # 網格或特定外觀的材質設定檔
│   │   └── Scene.usda                # 預設的 3D 場景檔
│   ├── SimulationSettings.swift      # 模擬器的常數設定或偏好設定模型
│   ├── Sphere.usda                   # 粒子的核心 USDA 模型模板 (我們後來改用 GPU 生成網格，此檔可能作為備用或參考)
│   └── ToggleImmersiveSpaceButton.swift # 負責切換 ImmersiveSpace 啟動/關閉的 UI 按鈕組件
│
├── particle-vision.xcodeproj/        # Xcode 專案核心設定檔 (包含編譯設定、套件依賴與 target 資訊)
│   ├── project.pbxproj
│   └── project.xcworkspace/...
│
├── particle-visionTests/             # 單元測試資料夾
│   └── ParticleVisionTests.swift     # 用於撰寫基礎邏輯測試的檔案
│
├── README.md                         # 專案說明文件
│
└── Simulation/                       # 高效能粒子引擎模組 (底層物理與 Metal GPU 運算核心)
    ├── GridSorting.metal             # Metal Shader：負責空間網格 (Spatial Hashing) 的前置排序與計數 (包含 Prefix Sum)
    ├── particle-vision-Bridging-Header.h # 橋接標頭檔：讓 Swift 能讀取並使用 C/C++ 結構 (用於引入 ParticleTypes.h)
    ├── ParticlePhysics.metal         # Metal Shader：負責計算粒子引力/斥力規則、速度更新、邊界碰撞與四面體頂點輸出
    ├── ParticleSimulator.swift       # 模擬器主類別 (@Observable)：管理 CPU 端的狀態 (如 FPS計數、碰撞脈衝、UI 綁定狀態)
    ├── ParticleSimulator+Metal.swift # 模擬器 Metal 擴充：專職負責建立 MTLBuffer、設定 Pipeline 與發送 GPU Command Encoder 指令
    ├── ParticleTypes.h               # Metal 與 Swift 共享的資料結構定義 (如 Particle, SimParams, Cell 等，確保記憶體佈局一致)
    ├── SharedTypes.h                 # 其他共享的常數或基礎型別定義
    └── SimulationModels.swift        # 純 Swift 端的物理運算輔助模型或資料結構
```



## ✨ 核心特色 (Key Features)

### 🚀 突破極限的 GPU 物理運算 (Metal Compute Shader)
- **十萬級粒子渲染 (`LowLevelMesh`)**：捨棄傳統的獨立實體 (Entity)，改用純 GPU 驅動的自訂網格。透過「四面體幾何降級 (4 頂點/12 索引)」，成功在 visionOS 上流暢渲染 **100,000 顆** PBR 發光粒子。
- **空間雜湊 (Spatial Hashing)**：將 $O(N^2)$ 的碰撞複雜度降至 $O(N)$，並將空間網格最佳化至 $32^3$ (32,768 格)，完美平衡 Prefix Sum 負載與記憶體快取命中率。
- **GPU 空間排序 (Spatial Sorting)**：實作計數排序與前綴和，確保物理空間相近的粒子在 GPU 記憶體中絕對連續，榨出極致的硬體效能。

### 🖐️ 沉浸式實體反饋 (Scoop Net Physics)
- **撈魚網物理學**：當使用者移動透明盒子時，Metal 端會即時計算相對慣性 (Inertia) 與穿透動能 (Penetration Impulse)，讓邊界具備將粒子「推擠撈起」的真實物理手感。
- **精確骨架追蹤**：基於 ARKit 的手部骨架節點分析，實現穩定且無死角的單手 6-DOF 空間拖曳與雙手縮放。

### 🎛️ 即時動態控制面板 (SwiftUI)
提供無邊緣裁切、完美適配玻璃背景的空間浮動視窗，支援即時監測與調整：
- **即時 FPS 監控**：內建每秒幀率顯示器，精準掌握硬體負載與視覺流暢度。
- **粒子數量與種類**：動態增減 (1,000 ~ 100,000 顆)，支援高達 8 種屬性的粒子互相吸引/排斥。
- **螢光強度 (Glow Intensity)**：即時調整 PBR 材質的發光強度，呈現絢麗的自發光星系視覺效果。
- **空間摩擦力 (Friction)**：即時調整宇宙的「黏滯感」(0.01 泥漿阻力 ~ 0.99 太空滑行)。

---

## 🛠️ 技術細節 (Technical Details)

本專案解決了 visionOS 開發中多個高難度的效能與渲染痛點：
1. **Zero CPU Overhead 渲染機制**：利用 Metal Compute Shader 每個 Frame 直接更新 `LowLevelMesh` 的頂點與法線緩衝區 (Vertex Buffer)，實現十萬顆粒子 90 FPS 零掉幀的驚人表現。
2. **解決射線偵測 (Raycast) 盲區**：將單一實心碰撞體重構為 12 道精準的邊緣碰撞條 (Edge Shapes)，不僅消除 UI 遮蔽死角，更大幅提升手勢命中的穩定度。
3. **視窗排版完美適配**：捨棄雙重 `padding` 與寫死的背景，改用適當的最小長寬限制搭配安全邊距，根除系統預設圓角造成的 UI 跑版與邊緣裁切問題。

---

## 💻 系統需求 (Requirements)

* **硬體**: Apple Vision Pro (實機測試表現最佳) 或 visionOS Simulator
* **系統**: visionOS 2.0+ (需支援 `LowLevelMesh` 相關 API)
* **開發環境**: Xcode 16.0+ (請確保以 **Release Mode** 建置以獲得最佳物理模擬幀率)

---

## 🎮 如何操作 (How to Play)

1. 點擊主畫面的 **「啟動十萬粒子宇宙」** 進入沉浸式空間。
2. 觀察高達 10 萬顆的四面體粒子，依據隨機生成的引力矩陣逐漸聚集成細胞、薄膜或絢麗的星系結構。
3. **調整與觀察**：在控制面板即時監看 FPS，隨意拉動數量與發光強度，並隨時點擊「隨機引力規則」重組基因矩陣。
4. **互動與碰撞**：單手捏合 (Pinch) 邊界盒子的任一處並拖曳，像拿著網子一樣在空間中撈取粒子，體驗真實的推擠與反彈動能。

---
## ⚙️ 運作原理 (Under the Hood)

- 在 Apple Vision Pro 的主畫面（Home View）點擊這個 App 的 3D 圖示（`AppIcon.solidimagestack`）時，visionOS 系統會啟動一連串精密的軟硬體協作程序。以下是依照時間序展開的檔案載入、相依性建立與硬體資源調用流程：

### 1. App 進入點與生命週期註冊
visionOS 讀取 `Info.plist` 確認系統權限與環境配置後，進入 `@main` 標記的 `ParticleVisionApp.swift`。系統會在此向作業系統註冊兩個核心場景容器：一個是用於顯示 2D UI 的 `WindowGroup`（負責載入 `ContentView`），另一個是預備用來渲染 3D 空間的 `ImmersiveSpace`（綁定 `ImmersiveView`），並同步初始化全域的環境狀態。

```mermaid
---
title: "階段一：App 進入點與生命週期註冊 (Stage 1: App Entry & Lifecycle)"
---
flowchart TD
    classDef fileNode fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#000;
    classDef actionNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#000;
    classDef stateNode fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000;
    classDef startEnd fill:#cfd8dc,stroke:#455a64,stroke-width:2px,color:#000,rx:10,ry:10;

    S(["系統啟動<br/>(System Launch)"]):::startEnd
    F_Plist[("設定檔確認<br/>(Info.plist)")]:::fileNode
    F_App[("主程式進入點<br/>(ParticleVisionApp)")]:::fileNode
    
    A1(["註冊核心場景<br/>(Register Scenes)"]):::actionNode
    A2(["初始化全域狀態<br/>(Init Global State)"]):::actionNode

    subgraph "場景容器 (Scene Containers)"
        direction LR
        S_Win[("2D 視窗容器<br/>(WindowGroup)")]:::stateNode
        S_Imm[("3D 空間容器<br/>(ImmersiveSpace)")]:::stateNode
    end

    S --> F_Plist
    F_Plist -->|"讀取權限<br/>(Read Perms)"| F_App
    F_App --> A2
    F_App --> A1
    A1 --> S_Win & S_Imm
```

### 2. 2D 視窗渲染與 UI 實例化
系統接著繪製 `ContentView.swift`，並根據程式碼中設定的 `frame(width: 750, height: 850)` 向 visionOS 請求一塊精確大小的 2D 視窗，並套用系統原生的玻璃背景效果（Glass Background）。此時 `ControlPanelView.swift` 內的各項滑桿與按鈕也一併實例化，進入等待使用者互動的就緒狀態。

```mermaid
---
title: "階段二：2D 視窗渲染與 UI 實例化 (Stage 2: 2D UI Render & Init)"
---
flowchart TD
    classDef fileNode fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#000;
    classDef actionNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#000;
    classDef visualNode fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#000;

    F_Content[("主視圖渲染<br/>(ContentView)")]:::fileNode
    
    subgraph "視窗建構 (Window Build)"
        direction LR
        A1(["請求精確尺寸<br/>(Request Frame)"]):::actionNode
        V_Glass(["套用玻璃背景<br/>(Glass Background)"]):::visualNode
        A1 --> V_Glass
    end

    subgraph "控制介面實例化 (UI Controls Init)"
        direction LR
        F_Panel[("控制面板<br/>(ControlPanelView)")]:::fileNode
        A2(["綁定滑桿與按鈕<br/>(Bind Sliders/Btns)"]):::actionNode
        F_Panel --> A2
    end

    S_Ready(["等待使用者互動<br/>(Ready for Interaction)"]):::visualNode

    F_Content --> A1
    F_Content --> F_Panel
    V_Glass --> S_Ready
    A2 --> S_Ready
```

### 3. Metal GPU 引擎與記憶體預熱
當負責核心運算的 `ParticleSimulator` 被實例化時，會立即觸發底層的 `setupMetal()` 與 `setupBuffers()`。此階段 CPU 會向 Apple Silicon 晶片請求建立 Command Queue，編譯 `ParticlePhysics.metal` 與 `GridSorting.metal` 成可執行的 Compute Pipeline，並在實體記憶體中配置容納 10 萬顆粒子與 32³ 空間網格所需的 `MTLBuffer`，最後建立 `LowLevelMesh` 準備承接巨量的頂點資料。

```mermaid
---
title: "階段三：Metal GPU 引擎與記憶體預熱 (Stage 3: Metal GPU & Memory)"
---
flowchart TD
    classDef fileNode fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#000;
    classDef actionNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#000;
    classDef hwNode fill:#e0f7fa,stroke:#0097a7,stroke-width:2px,color:#000;

    F_Sim[("模擬器實例化<br/>(ParticleSimulator)")]:::fileNode
    A1(["觸發硬體設定<br/>(Trigger Setup)"]):::actionNode

    subgraph "GPU 管線編譯 (GPU Pipeline)"
        direction LR
        HW_Queue(["建立指令佇列<br/>(Command Queue)"]):::hwNode
        A2(["編譯著色器<br/>(Compile Shaders)"]):::actionNode
        HW_Queue --> A2
    end

    subgraph "記憶體配置 (Memory Allocation)"
        direction LR
        A3(["配置十萬粒子緩衝<br/>(Alloc MTLBuffer)"]):::actionNode
        HW_Mesh(["建立底層網格<br/>(LowLevelMesh)"]):::hwNode
        A3 --> HW_Mesh
    end

    F_Sim --> A1
    A1 --> HW_Queue
    A1 --> A3
```

### 4. 沉浸式空間轉換 (Immersive Transition)
當使用者點擊「啟動十萬粒子宇宙」時，按鈕觸發 `openImmersiveSpace` API。visionOS 接到指令後，會平滑地將應用程式狀態切換至沉浸模式（Mixed Reality），解鎖立體空間的渲染權限，並開始執行 `ImmersiveView.swift` 的載入邏輯。

```mermaid
---
title: "階段四：沉浸式空間轉換 (Stage 4: Immersive Transition)"
---
flowchart TD
    classDef trigger fill:#ffebee,stroke:#c62828,stroke-width:2px,color:#000;
    classDef actionNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#000;
    classDef stateNode fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000;

    T_Btn(["點擊啟動宇宙按鈕<br/>(Tap Start Button)"]):::trigger
    A1(["呼叫空間 API<br/>(openImmersiveSpace)"]):::actionNode
    
    subgraph "系統狀態切換 (OS State Switch)"
        direction LR
        S_MR(["切換至混合實境<br/>(Switch to MR)"]):::stateNode
        A2(["解鎖 3D 渲染權限<br/>(Unlock 3D Render)"]):::actionNode
        S_MR --> A2
    end

    F_Imm[("載入沉浸視圖邏輯<br/>(Load ImmersiveView)")]:::stateNode

    T_Btn --> A1 --> S_MR
    A2 --> F_Imm
```

### 5. RealityKit 場景建構與 ARKit 啟動
在 `ImmersiveView` 中，RealityKit 會先生成核心的透明實體 `containerBox`，並利用 `Entity+Extensions.swift` 附加 12 道隱形的碰撞邊界組件（CollisionComponent）。同時，非同步任務（Task）會向系統請求手部骨架追蹤權限，啟動 `ARKitSession` 與 `HandTrackingProvider`，開始捕捉雙手的 6-DOF 空間座標。

```mermaid
---
title: "階段五：RealityKit 場景與 ARKit (Stage 5: RealityKit & ARKit)"
---
flowchart TD
    classDef fileNode fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#000;
    classDef actionNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#000;
    classDef arNode fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#000;

    F_Imm[("沉浸視圖執行<br/>(ImmersiveView)")]:::fileNode

    subgraph "實體建構 (Entity Build)"
        direction LR
        A1(["生成透明容器<br/>(Gen containerBox)"]):::actionNode
        A2(["附加 12 道碰撞邊界<br/>(Add Collision)"]):::actionNode
        A1 --> A2
    end

    subgraph "ARKit 感測器 (ARKit Sensors)"
        direction LR
        A3(["請求手部追蹤權限<br/>(Request Hand Tracking)"]):::actionNode
        AR_Sys(["啟動骨架捕捉<br/>(ARKit & HandTracking)"]):::arNode
        A3 --> AR_Sys
    end

    F_Imm --> A1
    F_Imm --> A3
```

### 6. 渲染迴圈 (Render Loop) 與 GPU 交接
一切就緒後，視圖會訂閱 `SceneEvents.Update.self`，將每秒最高 90 次的畫面更新權正式交棒給模擬器。在每一個 Frame 中，系統會嚴格依序執行：透過客製化手勢更新盒子座標 $\rightarrow$ 派發 GPU 運算指令 (`updateSimulation`) 進行空間雜湊與碰撞計算 $\rightarrow$ 將算好的頂點與法線資料同步回 RealityKit 的 `LowLevelMesh`。至此，整個粒子宇宙開始無縫運轉。

```mermaid
---
title: "階段六：渲染迴圈與 GPU 交接 (Stage 6: Render Loop & GPU)"
---
flowchart TD
    classDef loopNode fill:#fff9c4,stroke:#fbc02d,stroke-width:2px,color:#000;
    classDef actionNode fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#000;
    classDef hwNode fill:#e0f7fa,stroke:#0097a7,stroke-width:2px,color:#000;
    classDef endNode fill:#cfd8dc,stroke:#455a64,stroke-width:2px,color:#000,rx:10,ry:10;

    L_Start{"90Hz 更新迴圈<br/>(SceneEvents.Update)"}:::loopNode

    subgraph "每幀執行步驟 (Per-Frame Steps)"
        direction TB
        A1(["客製手勢更新座標<br/>(Update Box via Gesture)"]):::actionNode
        A2(["派發 GPU 運算指令<br/>(Dispatch updateSimulation)"]):::actionNode
        HW_Calc(["空間雜湊與碰撞計算<br/>(Spatial Hash & Collision)"]):::hwNode
        A3(["同步頂點至網格<br/>(Sync to LowLevelMesh)"]):::actionNode
        
        A1 --> A2 --> HW_Calc --> A3
    end

    E_Run(["粒子宇宙無縫運轉<br/>(Universe Running)"]):::endNode

    L_Start --> A1
    A3 --> L_Start
    A3 --> E_Run
```



---

## 📄 授權協議 (License)

- 本專案採用 [MIT License](LICENSE) 授權。歡迎自由 Fork、修改與應用於你的 visionOS 專案中！
---
