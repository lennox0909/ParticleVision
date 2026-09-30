# 🌌 Particle Life visionOS

![Platform](https://img.shields.io/badge/Platform-visionOS-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343?logo=swift)
![Metal](https://img.shields.io/badge/Technology-Metal%20%7C%20ARKit%20%7C%20RealityKit-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

- 為 Apple Vision Pro 打造的「粒子生命 (Particle Life)」模擬器。
- 透過結合 **`Metal Compute Shader`** 的 GPU 平行運算、**`ARKit`** 骨架手勢追蹤，以及 **`RealityKit`** 的沉浸式渲染，玩家可以直接用雙手在空間中「撈取」並擾動這個由數千顆微小粒子組成的浮游生態系。


---

<div align="center">

### Quick Start

**[Technical Summary](#️-技術摘要-technical-summary) · [Project Structure](#-專案結構-project-structure) · [Under the Hood](#️-運作原理-under-the-hood) · [Grid Sorting ](#grid-sorting-and-前綴和-prefix-sum--排序-counting-sort) · [Memory Alignment](#memory-alignment) · [Local Indices](#local-indices) · [40-Byte Stride](#40-byte-stride) · [Grid Artifacts](#️-網格狀排列現象-grid-artifacts) · [Static Wind Field & Directional Bias](#️-靜態風場效應與方向性偏差-static-wind-field--directional-bias)**

</div>

---

---
## ✨ 核心特色 (Key Features)

### 🚀 突破極限的 GPU 物理運算 (Metal Compute Shader)
- **十萬級粒子渲染 (`LowLevelMesh`)**：捨棄傳統的獨立實體 (Entity)，改用純 GPU 驅動的自訂網格。透過「四面體幾何降級 (4 頂點/12 索引)」，在 visionOS 上流暢渲染 **100,000 顆** PBR 發光粒子。
- **空間雜湊 (Spatial Hashing)**：將 $O(N^2)$ 的碰撞複雜度降至 $O(N)$，並將空間網格最佳化至 $32^3$ (32,768 格)美平衡 Prefix Sum 負載與記憶體快取命中率。
- **GPU 空間排序 (Spatial Sorting)**：實作計數排序與前綴和，確保物理空間相近的粒子在 GPU 記憶體中絕對連續，榨出硬體效能。
- **物理模擬崩壞現象 (Algorithm GPU Trap)的因應**：[網格狀排列現象 (Grid Artifacts)](#️-網格狀排列現象-grid-artifacts), [靜態風場效應 (Static Wind Field Effect)](#1-靜態風場效應-static-wind-field-effect), [方向性偏差 (Directional Bias)](#2-方向性偏差-directional-bias)

### 🖐️ 沉浸式實體反饋 (Scoop Net Physics)
- **撈魚網物理學**：當使用者移動透明盒子時，Metal 端會即時計算相對慣性 (Inertia) 與穿透動能 (Penetration Impulse)，讓邊界具備將粒子「推擠撈起」的真實物理手感。
- **骨架追蹤**：基於 ARKit 的手部骨架節點分析，實現單手 6-DOF 空間拖曳與雙手縮放。

### 🎛️ 即時動態控制面板 (SwiftUI)
無邊緣裁切、適配玻璃背景的空間浮動視窗，支援即時監測與調整：
- **即時 FPS 監控**：每秒幀率顯示器，掌握硬體負載與視覺流暢度。
- **粒子數量與種類**：動態增減 (1,000 ~ 100,000 顆)，支援高達 8 種屬性的粒子互相吸引/排斥。
- **螢光強度 (Glow Intensity)**：即時調整 PBR 材質的發光強度，呈現絢麗的自發光星系視覺效果。
- **空間摩擦力 (Friction)**：即時調整宇宙的「黏滯感」(0.01 泥漿阻力 ~ 0.99 太空滑行)。

---

## 🛠️ [技術摘要 (Technical Summary)](#quick-start)

解決 visionOS 多個高難度的效能與渲染痛點：
1. **Zero CPU Overhead 渲染機制**：利用 Metal Compute Shader 每個 Frame 直接更新 `LowLevelMesh` 的`頂點` (`Vertex`) 與`法線`(`Normal Vector`)緩衝區 (`Vertex Buffer`)，實現十萬顆粒子 90 FPS 表現。
2. **解決射線偵測 (Raycast) 盲區**：將單一實心碰撞體重構為 12 道精準的邊緣碰撞條 (Edge Shapes)，消除 UI 遮蔽死角，提升手勢命中的穩定度。
3. **視窗排版**：用適當的最小長寬限制搭配安全邊距，根除系統預設圓角造成的 UI 跑版與邊緣裁切問題。

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
## 📂 [專案結構 (Project Structure)](#quick-start)

- UI 介面、渲染層與底層 GPU 物理引擎完全解耦：

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

---
## ⚙️ [運作原理 (Under the Hood)](#quick-start)

- 在 Apple Vision Pro 的主畫面（Home View）點擊這個 App 的 3D 圖示（`AppIcon.solidimagestack`）時，visionOS 系統會啟動一連串精密的軟硬體協作程序。以下是依照時間序展開的檔案載入、相依性建立與硬體資源調用流程：

### 1. App 進入點與生命週期註冊
- visionOS 讀取 `Info.plist` 確認系統權限與環境配置後，進入 `@main` 標記的 `ParticleVisionApp.swift`。
- 系統會在此向作業系統註冊兩個核心場景容器：
    - 一個是用於顯示 2D UI 的 `WindowGroup`（負責載入 `ContentView`）
    - 另一個是預備用來渲染 3D 空間的 `ImmersiveSpace`（綁定 `ImmersiveView`），並同步初始化全域的環境狀態。

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
- 系統接著繪製 `ContentView.swift`，並根據程式碼中設定的 `frame(width: 750, height: 850)` 向 visionOS 請求一塊精確大小的 2D 視窗，並套用系統原生的玻璃背景效果（Glass Background）。
- 此時 `ControlPanelView.swift` 內的各項滑桿與按鈕也一併實例化，進入等待使用者互動的就緒狀態。

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
- 當負責核心運算的 `ParticleSimulator` 被實例化時，會立即觸發底層的 `setupMetal()` 與 `setupBuffers()`。
- 此階段 CPU 會向 Apple Silicon 晶片請求建立 Command Queue，編譯 `ParticlePhysics.metal` 與 `GridSorting.metal` 成可執行的 Compute Pipeline，並在實體記憶體中配置容納 10 萬顆粒子與 $32^3$ 空間網格所需的 `MTLBuffer`，最後建立 `LowLevelMesh` 準備承接巨量的頂點資料。

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
- 當使用者點擊「啟動十萬粒子宇宙」時，按鈕觸發 `openImmersiveSpace` API。
- visionOS 接到指令後，會平滑地將應用程式狀態切換至沉浸模式（Mixed Reality），解鎖立體空間的渲染權限，並開始執行 `ImmersiveView.swift` 的載入邏輯。

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
- 在 `ImmersiveView` 中，RealityKit 會先生成核心的透明實體 `containerBox`，並利用 `Entity+Extensions.swift` 附加 12 道隱形的碰撞邊界組件（CollisionComponent）。
- 同時，非同步任務（Task）會向系統請求手部骨架追蹤權限，啟動 `ARKitSession` 與 `HandTrackingProvider`，開始捕捉雙手的 6-DOF 空間座標。

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
- 一切就緒後，視圖會訂閱 `SceneEvents.Update.self`，將每秒最高 90 次的畫面更新權正式交棒給模擬器。
- 在每一個 Frame 中，系統會嚴格依序執行：
    - 透過客製化手勢更新盒子座標 $\rightarrow$
    - 派發 GPU 運算指令 (`updateSimulation`) 進行空間雜湊與碰撞計算 $\rightarrow$
    - 將算好的頂點與法線資料同步回 RealityKit 的 `LowLevelMesh`。

- 至此，整個粒子宇宙開始無縫運轉。

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
## [Grid Sorting and （前綴和 Prefix Sum / 排序 Counting Sort）](#quick-start)

- 在 **`GridSorting.metal`** 中實作前綴和排序（Prefix Sum / Counting Sort），是整個模擬器能將物理計算複雜度從 $O(N^2)$ 降低至 $O(N)$ 並保持 90 FPS 的靈魂所在。其核心機制是透過 GPU 平行計算，將空間中的粒子依據所處的網格位置重新排列成**連續的記憶體區段**。

具體的實作機制與流程可分為以下三個核心階段：

### 1. 空間雜湊與細胞計數 (Spatial Hashing & Counting)
* **劃分 $32^3$ 空間網格**：系統將 3D 空間劃分為 $32 \times 32 \times 32$（共 32,768 個格子）的幾何網格。
* **計算 Grid Index**：在第一個 Compute Kernel 中，GPU 會同步讀取 10 萬顆粒子的 3D 座標，並透過雜湊函式計算出每顆粒子落在第幾個格子（Grid Index）。
* **原子加總 (Atomic Addition)**：使用 Metal 的原子操作計數器，累加每個格子內的粒子總數（Cell Count），為計數排序建立直方圖。


### 2. GPU 前綴和計算 (Prefix Sum / Inclusive & Exclusive Scan)
前綴和演算法的核心作用，是將 **「各格子的粒子數量」轉換為「該格子粒子在重排緩衝區中的起始記憶體位移 (Offset)」**：
* **前綴和位移計算**：對 32,768 個格子的數量陣列執行掃描計算。例如：若第 0 格有 5 顆粒子、第 1 格有 3 顆粒子，經 Exclusive Prefix Sum 計算後，第 0 格的起始偏移位址為 `0`，第 1 格為 `5`，第 2 格則為 `8`（`5 + 3`）。
* **定義記憶體邊界**：前綴和運算結果會直接記錄每個 `Cell` 的 `startIndex` 與 `endIndex`，明確劃分出每個網格在全局陣列中的存放區間。


### 3. 粒子記憶體重排 (Particle Scatter & Reordering)
* **寫入連續記憶體 (`Sorted Particle Buffer`)**：根據前綴和算出的起始位移，GPU 再次平行派發指令，將 10 萬顆粒子寫入新的排序緩衝區。
* **極大化快取命中率 (Cache Hit Rate)**：完成排序後，**在物理空間中相近的粒子，在 GPU 記憶體中也會被絕對連續地排列**。


### 🌟 排序完成後的物理計算效益
當後續的物理引擎 `ParticlePhysics.metal` 執行引力與斥力計算時，每顆粒子不再需要搜尋全域 10 萬顆粒子，而是直接查詢目標格子及其周圍相鄰的 27 個格子。由於這些格子的粒子資料在記憶體中高度連續，GPU Thread Group 讀取時能達到極高的 L1/L2 快取命中率，實現零 CPU 開銷的極致效能。

---

## [Memory Alignment](#quick-start)

- 在 **Particle Life visionOS** 中，記憶體對齊（Memory Alignment）是讓 C (`Bridging Header`)`、Swift` (`RealityKit`/`LowLevelMesh`) 與 `Metal` (`Compute Shader`) 三端能**共享同一塊二進位記憶體緩衝區 (`MTLBuffer`)** 的關鍵技術。若對齊不一致，GPU 寫入的位元組會被 `Swift`/`RealityKit` 錯位解析，導致畫面破圖甚至崩潰。

以下是專案中記憶體對齊的核心細節與實作規則：


### 1. 跨語言共享結構定義 (`ParticleTypes.h`)
* **Bridging Header 橋接**：透過 `particle-vision-Bridging-Header.h` 將 C 語言標頭檔 `ParticleTypes.h` 引入 Swift 中。
* **單一真理來源 (Single Source of Truth)**：`ParticleTypes.h` 同時被 Swift (`ParticleSimulator+Metal.swift`) 與 Metal Shader (`ParticlePhysics.metal`) 引入。這確保了兩端在編譯時使用完全相同的 `struct` 欄位順序與型別宣告。


### 2. Metal vector 型別的對齊規則 (Alignment Rules)
Metal Shader 與 C/Swift 對於向量型別的預設對齊方式不同：
* **`float3` vs `packed_float3`**：
  * **`float3`**：在 Metal 中預設以 **16-byte** 對齊（與 `float4` 相同，最後 4-byte 為補齊的 padding）。
  * **`packed_float3`**：精確佔用 **12-byte**（3 個 4-byte float），無強制 16-byte padding。
* **頂點結構 (`VertexData`) 的緊湊佈局**：
  在 `LowLevelMesh` 頂點資料中，專案偏好使用 `packed_float3` 來降低頂點緩衝區大小並優化 GPU 記憶體頻寬：
  ```c
  typedef struct {
      packed_float3 position; // 12 bytes (Offset 0)
      packed_float3 normal;   // 12 bytes (Offset 12)
      float4        color;    // 16 bytes (Offset 24)
  } VertexData; // 總 Stride = 40 bytes
  ```


### 3. Swift 端的 `LowLevelMesh` Layout 映射
為了讓 `RealityKit` 讀懂 `Metal Shader` 直接寫入 `MTLBuffer` 的頂點，`Swift` 端建立 `LowLevelMesh` 時必須嚴格設定 `VertexLayout` 的`位移` (`Offset`) 與`步距` (`Stride`)：

```swift
// Swift 中的 LowLevelMesh 宣告範例
var vertexLayout = LowLevelMesh.VertexLayout()
vertexLayout.attributes = [
    .init(format: .float3, offset: 0,  attribute: .position), // 對應 packed_float3 position (12 bytes)
    .init(format: .float3, offset: 12, attribute: .normal),   // 對應 packed_float3 normal (12 bytes)
    .init(format: .float4, offset: 24, attribute: .color)     // 對應 float4 color (16 bytes)
]
vertexLayout.stride = 40 // 必須精確等於 C/Metal 端 sizeof(VertexData)
```

---

### 4. 記憶體對齊帶來的極致效能
1. **零記憶體拷貝 (Zero Copy)**：Metal Compute Shader 將四面體 4 個頂點的 3D 座標、法線與顏色算好後，直接覆寫映射好的 `MTLBuffer`。
2. **無縫 GPU-to-Render**：RealityKit 依據上述 40-byte 步距的 `VertexLayout` 直接讀取相同的 `MTLBuffer`，實現全 GPU 驅動的零 CPU 開銷渲染 (Zero CPU Overhead)。

---
## [Local Indices](#quick-start)

- 每顆粒子被幾何降級為包含 **4 個頂點** 與 **12 個三角形索引 (Indices)** 的正四面體。這 12 個索引的計算原理分為 **局部幾何面定義** 與 **全域記憶體位移算式**：


### 1. 單一四面體的局部索引構建 (Local Face Indices)

一個正四面體共有 4 個頂點（局部編號為 `0, 1, 2, 3`），這 4 個頂點可組合為 **4 個三角形面**：

* **面 1 (底面)**：由頂點 `(0, 1, 2)` 組成
* **面 2 (側面 1)**：由頂點 `(0, 2, 3)` 組成
* **面 3 (側面 2)**：由頂點 `(0, 3, 1)` 組成
* **面 4 (頂面)**：由頂點 `(1, 3, 2)` 組成

每個三角形面由 3 個頂點索引組成，因此單一四面體的 **12 個局部索引順序** 為：

${LocalIndices} = [\text{ 0, 1, 2,;  0, 2, 3,;  0, 3, 1,;  1, 3, 2 }]$

> **頂點繞序 (Winding Order)**：索引順序嚴格遵循逆時針 (CCW) 順序，確保 GPU 渲染時 4 個面的幾何法線方向皆正確朝向體外。


### 2. 全局 10 萬顆粒子的索引位移公式 (Global Index Offset)

在 `LowLevelMesh` 的索引緩衝區 (Index Buffer) 中，全域共存放了 (100,000 times 12 = 1,200,000) 個整數索引。

對於第 $i$ 顆粒子$(i \in )$：
1. 其 4 個頂點在頂點緩衝區 (Vertex Buffer) 中的**起始編號**為：
   ${baseVertex} = {i \times 4}$
2. 其 12 個全域索引在 Index Buffer 中的寫入公式如下：

```swift
// Swift 初始化階段寫入靜態 Index Buffer 的算式
for i in 0..<particleCount {
    let baseVertex = UInt32(i * 4)
    let baseIndex  = i * 12
    
    // 面 1 (0, 1, 2)
    indices[baseIndex + 0] = baseVertex + 0
    indices[baseIndex + 1] = baseVertex + 1
    indices[baseIndex + 2] = baseVertex + 2
    
    // 面 2 (0, 2, 3)
    indices[baseIndex + 3] = baseVertex + 0
    indices[baseIndex + 4] = baseVertex + 2
    indices[baseIndex + 5] = baseVertex + 3
    
    // 面 3 (0, 3, 1)
    indices[baseIndex + 6] = baseVertex + 0
    indices[baseIndex + 7] = baseVertex + 3
    indices[baseIndex + 8] = baseVertex + 1
    
    // 面 4 (1, 3, 2)
    indices[baseIndex + 9]  = baseVertex + 1
    indices[baseIndex + 10] = baseVertex + 3
    indices[baseIndex + 11] = baseVertex + 2
}
```

### 3. 靜態預計算與效能優勢

* **一次性預計算**：這 1,200,000 個索引在系統初始化的 `setupBuffers()` 階段一次性寫入 `MTLBuffer`。
* **零 CPU 負擔 (Zero CPU Overhead)**：由於拓樸結構固定，執行期索引緩衝區完全維持靜態。每一幀只需由 Metal Compute Shader 動態更新 Vertex Buffer 中的頂點座標，即可達成 90 FPS 零掉幀渲染。

---
## [40-Byte Stride](#quick-start)

- 共享結構定義 **`ParticleTypes.h`** 中，`LowLevelMesh` 的頂點結構 **`VertexData`** 總步距（Stride）為 **40 Bytes**，其計算是由各欄位的型別大小與 Offset 累加而得：


### 1. 欄位記憶體大小拆解

`VertexData` 結構包含三個欄位：`position`、`normal` 與 `color`。各欄位的記憶體佔用計算如下：

* **`packed_float3 position` (12 Bytes / Offset 0)**：
  * 由 3 個 32-bit（4 Bytes）浮點數 `(x, y, z)` 組成。
  * 計算：$$3 \times 4 \text{ Bytes} = 12 \text{ Bytes}$$。
* **`packed_float3 normal` (12 Bytes / Offset 12)**：
  * 由 3 個 32-bit（4 Bytes）浮點數 `(nx, ny, nz)` 組成。
  * 計算：$$3 \times 4 \text{ Bytes} = 12 \text{ Bytes}$$。
  * 位移（Offset）：在 `position` 之後，位移量為 $0 + 12 = 12 \text{ Bytes}$。
* **`float4 color` (16 Bytes / Offset 24)**：
  * 由 4 個 32-bit（4 Bytes）浮點數 `(r, g, b, a)` 組成。
  * 計算：$$4 \times 4 \text{ Bytes} = 16 \text{ Bytes}$$。
  * 位移（Offset）：在 `normal` 之後，位移量為 $12 + 12 = 24 \text{ Bytes}$。


### 2. 總步距（Total Stride）加總算式

- 將三個欄位的位元組相加：

$$\text{Total Stride} = \underbrace{12}_{\text{position}} + \underbrace{12}_{\text{normal}} + \underbrace{16}_{\text{color}} = \mathbf{40 \text{ Bytes}} \quad$$

### 3. 關鍵設計：為何使用 `packed_float3` 而非 `float3`？

* **`float3` 的隱形 Padding**：在 Metal 中，標準的 `float3` 預設以 **16-Byte** 對齊（與 `float4` 相同，末端會強制補滿 4 Bytes 的空白 Padding）。若使用 `float3`，結構會膨脹為 (16 + 16 + 16 = 48 Bytes )。
* **`packed_float3` 的緊湊佈局**：專案改採 `packed_float3`，取消強制 16-Byte 對齊，精確佔用 **12 Bytes**，成功將單一頂點大小縮減至 **40 Bytes**。這不僅節省了 16.7% 的頂點緩衝區記憶體，更極大地提升了 GPU L1/L2 快取的命中率與傳輸頻寬。

在 Swift 端配置 `LowLevelMesh` 時，將 `vertexLayout.stride` 精確指定為 **40**，即可讓 RealityKit 渲染器與 Metal Compute Shader 直接共享同一塊 `MTLBuffer` 進行無縫讀寫。

---

## 🕸️ [網格狀排列現象 (Grid Artifacts)](#quick-start)

### 🔍 現象說明與成因
在基於空間雜湊 (Spatial Hashing) 的粒子系統中，當粒子的引力搜尋半徑 (`rMax`) 大於單一空間網格的物理寬度時，就會在視覺上產生死板的「網格效應」。

在目前的 $32^3$ 網格架構下，宇宙空間總寬度為 4.0，單一網格的寬度為 $4.0 \div 32 = 0.125$。因為 GPU 在運算時為了維持極高幀率，只會搜尋本身與周圍一圈（$3 \times 3 \times 3$）的鄰居網格。若 `rMax` 設定超過 0.125，原本應該是「球狀」的引力場，會在超出鄰居網格的邊界處被硬生生截斷，退化成「正方體」的引力場。粒子為了尋求物理受力平衡，最終就會沿著 X、Y、Z 軸整齊排列，形成如同積木或晶格般的方正結構。


### 🛠️ 解決方法

- 要消除這種不自然的晶格排列，可以根據對效能與視覺的需求採用以下解法：

#### 解法一：限制最大引力半徑 (維持極致效能)
強制讓粒子的「視力」無法穿透相鄰的網格邊界，確保引力場維持完美的球體。
- 將 `rMax` 設定為嚴格小於 0.125 的數值（例如：`0.12`）。
- 同步按比例縮小斥力半徑 `rMin`（約維持在 `rMax` 的 30%，例如 `0.035`）。
- **優點**：能繼續維持 $32^3$ 網格架構，確保 GPU 記憶體快取處於最高效率，支撐十萬顆粒子的運算。

#### 解法二：降級網格密度 (保留長距離引力)
如果希望粒子具備更遠的互動距離，以聚集成更龐大的星系或薄膜結構，就必須擴大單一網格的體積。
- 將空間網格密度從 $32^3$ 降級至 $16^3$。
- 單一網格寬度會擴大為 $4.0 \div 16 = 0.25$，此時 `rMax` 即可安全地上調至 0.25 以內而不產生切面。
- **缺點**：每個網格內包含的粒子數量會變多，導致鄰居搜尋的迴圈次數增加，效能會面臨些微考驗。

#### 解法三：引入微小擾動 (打破對稱性)
即使半徑設定正確，在完美的數學對稱計算下，粒子偶爾仍會形成微弱的晶體排列。透過引入物理學中的布朗運動 (Brownian Motion) 可以徹底打破這種現象。
- 在 Metal Compute Shader 計算完總受力 (`force`) 後，利用空間座標與粒子 ID 產生極微小的偽隨機向量。
- 將此隨機擾動 (Jitter) 疊加到受力中。
- **優點**：能以極低的運算成本破壞不自然的完美對稱，讓細胞群聚與排斥的邊緣顯得更加有機且真實。通常建議與「解法一」搭配使用，以達到效能與視覺的最佳平衡。
---
## 🌪️ [靜態風場效應與方向性偏差 (Static Wind Field & Directional Bias)](#quick-start)

### ⚠️ 錯誤成因分析

在 GPU 物理模擬中，當我們試圖用數學函數 (如 `sin` 與 `fract`) 為粒子加入隨機擾動來打破網格對稱性時，極易落入兩個經典的隨機數陷阱，導致粒子全部被擠壓到透明盒子的某一面：

#### 1. 靜態風場效應 (Static Wind Field Effect)
如果你依賴「空間座標 (`p.position`)」作為亂數種子，會產生一個致命問題：**在空間中同一個座標點上，產生的隨機向量永遠是相同的。**
這等於在透明盒子裡建立了一個「隱形的 3D 向量風場」。當粒子游走到特定位置時，總是會被同一股力量往同一個方向推。隨著時間推移，粒子就會像落葉順著海流一樣，全部被「吹」到風場的盡頭（也就是盒子的特定牆面），而無法形成原地隨機震動。

#### 2. 方向性偏差 (Directional Bias)
使用 `fract(sin(dot(...)))` 這種基於浮點數的偽隨機函數，在 GPU 硬體上存在先天的缺陷。
由於浮點數精度的限制與 `sin` 函數的分佈特性，它產生的數值**並不是絕對均勻的**。這意味著長時間加總下來，這股隨機力量的平均值不是 `(0, 0, 0)`，而是帶有微弱的淨推力 (Net Force)。這個不為零的平均值，讓粒子感受到彷彿有某一面牆壁具備異常的「重力」。

---

### 🛠️ 終極解決方案：動態種子與高品質整數雜湊

要實作真正的物理「布朗運動 (Brownian Motion)」，我們必須滿足兩個條件：**擾動方向每幀都在變 (動態性)**，且**長期平均受力必須為零 (均勻對稱性)**。

以下是工業級 GPU 渲染中標準的解法：

#### 1. 引入動態種子 (Dynamic Seed)
將粒子的「當前速度 (`p.velocity`)」與「粒子編號 (`id`)」透過 XOR 位元運算結合。因為粒子的速度在每一幀都會被引力或摩擦力改變，這保證了即使粒子停留在同一個空間座標，下一幀的擾動方向也會瞬間改變，徹底打破靜態風場。

#### 2. 改用 PCG 變體的高品質整數雜湊 (Integer Hashing)
捨棄浮點數的 `sin()` 函數，改用純位元運算 (Bitwise Shift & XOR) 來打亂硬體層級的位元。這種雜湊演算法能保證產生出分佈絕對均勻的整數，最後再將其映射回 `-1.0 ~ 1.0` 的浮點數。這確保了 XYZ 三個方向的推力機率完美對稱，徹底消除方向性偏差。

**Metal 實作程式碼：**

```metal
// 1. 動態種子：利用 id 與「當前速度」混合 (使用 as_type 將 float 轉為 uint 進行位元運算)
uint seed = id ^ as_type<uint>(p.velocity.x) ^ as_type<uint>(p.velocity.y) ^ as_type<uint>(p.velocity.z);

// 2. 高品質整數雜湊 (PCG Hash 變體)：徹底打亂位元，確保數值分佈絕對均勻
seed ^= seed >> 16;
seed *= 0x85ebca6b;
seed ^= seed >> 13;
seed *= 0xc2b2ae35;
seed ^= seed >> 16;

// 3. 位元遮罩與浮點數映射：精確轉換至 -1.0 ~ 1.0 之間
float rx = float(seed & 0x3FF) / 1023.0 * 2.0 - 1.0;
float ry = float((seed >> 10) & 0x3FF) / 1023.0 * 2.0 - 1.0;
float rz = float((seed >> 20) & 0x3FF) / 1023.0 * 2.0 - 1.0;

float3 jitter = float3(rx, ry, rz);

// 4. 套用無偏差的微小擾動
force += jitter * 0.1f;
```
---
## 📄 授權協議 (License)

- 本專案採用 [MIT License](LICENSE) 授權。歡迎自由 Fork、修改與應用於你的 visionOS 專案中！
---
