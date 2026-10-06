檢驗目前 `ParticlePhysics.metal` 中的向量方向與正負號關係：

### 🔬 1. 檢視目前演算法的向量方向

在 `ParticlePhysics.metal` 的 `computeGridParticles` 中，目前的程式碼是這樣寫的：

```metal
float3 d = p.position - other.position; // ⚠️️ 注意：終點減起點，d 是從 other 指向 p (遠離對方)！
float r = fast::length(d);

if (r > 0.0 && r < pairRMax) {
    d /= r; // 單位向量 d：方向為「遠離 other（排斥方向）」

    if (r < pairRMin) {
        // 近距離碰撞排斥：係數為正，沿著 +d 推開 p (排斥)
        force += d * (1.0f - r / pairRMin) * 2.0f;
    } else {
        // 中遠距離交互作用 (pairRMin <= r < pairRMax)
        float f = rule * (1.0f - abs(2.0f * r - pairRMax - pairRMin) / (pairRMax - pairRMin));
        force += d * f; // ⚠️ 這裡直接加上 d * f！
    }
}

```

### 🧮 2. 逐步推導正負號結果

由於向量 $\vec{d} = \text{p.position} - \text{other.position}$ 的方向是「從 `other` 指向 `p`（亦即把 `p` 往外推開的方向）」，且區間內的三角波權重 $(1.0 - \frac{\vert{}2r - r_{\max} - r_{\min}\vert{}}{r_{\max} - r_{\min}}) > 0$ 恆為正值：

1. **當 `rule > 0`（UI 顯示正值青色）時**：
* $f > 0$，因此 `force += d * f` 的方向與 $\vec{d}$ 相同（往外推開）。
* **實際物理表現**：正值反而變成了「排斥力（Repulsion）」！


2. **當 `rule < 0`（UI 顯示負值紅色）時**：
* $f < 0$，因此 `force += d * f` 的方向變成 $-\vec{d}$（指向 `other`）。
* **實際物理表現**：負值反而變成了「吸引力（Attraction）」！



**結論**：在目前的程式碼中，`force += d * f;` **正負號是顛倒的**（負值紅色變成了吸引力，正值青色變成了排斥力）！

---

### 🛠️ 修正方案：讓「正值（`+`）＝ 吸引力」、「負值（`-`）＝ 排斥力」

由於向內吸引的方向是 $-\vec{d}$（從 `p` 指向 `other`），我們只需要將 `ParticlePhysics.metal` 第 63 行附近的 `force += d * f;` 改為 **`force -= d * f;`**，就能讓物理意義完全符合直覺與 UI 定義：

* **`rule > 0`（正值）**：`force -= d * (+f)` ➔ 朝 $-\vec{d}$ 方向拉近（**吸引力 Attraction**）。
* **`rule < 0`（負值）**：`force -= d * (-f)` ➔ 朝 $+\vec{d}$ 方向推開（**排斥力 Repulsion**）。

#### 1. 修改 `ParticlePhysics.metal`

請打開 **`ParticlePhysics.metal`**，將 `if (r < pairRMin)` 的 `else` 區塊中那一行 `+` 號改為 `-` 號：

```metal
                    if (r > 0.0 && r < pairRMax) {
                        d /= r; // d 為「由 other 指向 p (向外排斥)」的單位向量

                        if (r < pairRMin) {
                            // 1. 極近距離核心碰撞：恆沿 +d 方向向外排斥
                            force += d * (1.0f - r / pairRMin) * 2.0f;
                        } else {
                            // 2. 規則矩陣作用區：
                            // 為了讓 rule > 0 (正值) 代表向內吸引 (-d 方向)、rule < 0 (負值) 代表向外排斥 (+d 方向)，此處須使用 -=
                            float f = rule * (1.0f - abs(2.0f * r - pairRMax - pairRMin) / (pairRMax - pairRMin));
                            force -= d * f;
                        }
                    }

```

> 💡 **補充檢查（`SimulationPreset.swift` 預設集矩陣）**：
> 如果你之前建立的 `SimulationPreset.swift`（例如「細胞分裂」、「游動蠕蟲」等預設集）是按照「正數代表吸引、負數代表排斥」的直覺設計的，改成 `force -= d * f;` 之後，這些預設集的聚落與追逐行為反而會變得更正統、更凝聚！你可以順便打開 `SimulationPreset.swift` 確認一下預設集的同類對角線（`i == j`）是否為正數（同類相吸凝聚成團），若是正數，改成 `force -= d * f;` 後就 100% 完美對齊了！