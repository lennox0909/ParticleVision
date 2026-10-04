#include <metal_stdlib>
#include "ParticleTypes.h"
using namespace metal;

kernel void computeGridParticles(device Particle* particlesOut [[buffer(0)]],
                                 device const Particle* particlesIn [[buffer(1)]],
                                 constant float* ruleMatrix [[buffer(2)]],
                                 constant SimParams& params [[buffer(3)]],
                                 device const Cell* grid [[buffer(4)]],
                                 constant float4* handForces [[buffer(5)]],
                                 constant uint& boundaryMode [[buffer(6)]],
                                 constant float2& singularityParams [[buffer(7)]],
                                 uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    
    Particle p = particlesIn[id];
    float3 force = float3(0.0);
    uint3 cellCoords = getCellCoords(p.position);
    
    // 計算單一矩陣的大小 (N x N)，用於偏移讀取 rMin 與 rMax 矩陣
    uint matrixSize = params.numTypes * params.numTypes;
    
    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                int3 neighborCoords = int3(cellCoords) + int3(x, y, z);
                
                if (boundaryMode == 1) {
                    // ♾️ 無縫環形宇宙模式：網格索引在 0 ~ 31 之間循環折返 (Modulo 32)
                    neighborCoords = (neighborCoords + 32) & 31;
                } else {
                    if (neighborCoords.x < 0 || neighborCoords.x > 31 ||
                        neighborCoords.y < 0 || neighborCoords.y > 31 ||
                        neighborCoords.z < 0 || neighborCoords.z > 31) {
                        continue;
                    }
                }
                
                uint neighborCellIndex = getCellIndex(uint3(neighborCoords));
                uint startIndex = grid[neighborCellIndex].startIndex;
                uint count = atomic_load_explicit(&grid[neighborCellIndex].count, memory_order_relaxed);
                
                for (uint i = 0; i < count; i++) {
                    uint otherId = startIndex + i;
                    if (otherId == id) continue;
                    
                    Particle other = particlesIn[otherId];
                    float3 d = p.position - other.position;
                    
                    // ♾️ 若為無縫環形邊界，跨牆壁的兩顆粒子取最短環形距離 (盒寬 = 4.0)
                    if (boundaryMode == 1) {
                        if (d.x >  2.0f) d.x -= 4.0f; else if (d.x < -2.0f) d.x += 4.0f;
                        if (d.y >  2.0f) d.y -= 4.0f; else if (d.y < -2.0f) d.y += 4.0f;
                        if (d.z >  2.0f) d.z -= 4.0f; else if (d.z < -2.0f) d.z += 4.0f;
                    }
                    
                    float r = fast::length(d);
                    
                    // 根據 (主動粒子 p.type -> 目標粒子 other.type) 查表取得專屬的引力、最小半徑與最大半徑
                    uint ruleIdx = p.type * params.numTypes + other.type;
                    float rule = ruleMatrix[ruleIdx];
                    float pairRMin = ruleMatrix[matrixSize + ruleIdx];
                    float pairRMax = max(pairRMin + 0.001f, ruleMatrix[matrixSize * 2 + ruleIdx]);
                    
                    if (r > 0.0 && r < pairRMax) {
                        d /= r;
                        
                        if (r < pairRMin) {
                            force += d * (1.0f - r / pairRMin) * 2.0f;
                        } else {
                            float f = rule * (1.0f - abs(2.0f * r - pairRMax - pairRMin) / (pairRMax - pairRMin));
                            force += d * f;
                        }
                    }
                }
            }
        }
    }
    
    // 1. 動態種子：利用 id 與「當前速度」混合，確保擾動方向每幀切換，打破靜態風場
    uint seed = id ^ as_type<uint>(p.velocity.x) ^ as_type<uint>(p.velocity.y) ^ as_type<uint>(p.velocity.z);
    
    // 2. 高品質整數雜湊 (PCG Hash 變體)：確保分佈絕對均勻，消除特定方向的引力偏差
    seed ^= seed >> 16;
    seed *= 0x85ebca6b;
    seed ^= seed >> 13;
    seed *= 0xc2b2ae35;
    seed ^= seed >> 16;
    
    // 3. 提取三個均勻分佈的浮點數，將範圍精確映射至 -1.0 ~ 1.0
    float rx = float(seed & 0x3FF) / 1023.0 * 2.0 - 1.0;
    float ry = float((seed >> 10) & 0x3FF) / 1023.0 * 2.0 - 1.0;
    float rz = float((seed >> 20) & 0x3FF) / 1023.0 * 2.0 - 1.0;
    
    float3 jitter = float3(rx, ry, rz);
    
    // 4. 套用微小擾動打破網格對稱性
    force += jitter * 0.1f;
    
    // 5. 雙手「神之手」粒子力場互動 (0: 左手, 1: 右手)
    for (int h = 0; h < 2; h++) {
        float mode = handForces[h].w;
        if (abs(mode) > 0.01f) {
            float3 handPos = handForces[h].xyz;
            float3 toHand = handPos - p.position;
            float dist = fast::length(toHand);
            
            float influenceRadius = 1.25f;
            if (dist > 0.001f && dist < influenceRadius) {
                float3 dir = toHand / dist;
                float falloff = 1.0f - (dist / influenceRadius);
                
                if (mode > 0.0f) {
                    if (dist < 0.12f) {
                        force -= dir * (1.0f - dist / 0.12f) * 8.0f;
                    } else {
                        force += dir * (falloff * falloff) * 14.0f;
                        float3 swirlDir = normalize(cross(dir, float3(0.0f, 1.0f, 0.0f)) + float3(0.001f));
                        force += swirlDir * falloff * 5.5f;
                    }
                } else {
                    force -= dir * (falloff * falloff) * 32.0f;
                }
            }
        }
    }
    
    // ✨ 6. 空間力場與引力中心奇點 (Central Black Hole / Attractor Singularity)
    int singMode = int(singularityParams.x + 0.5f);
    float singStrength = singularityParams.y;
    if (singMode > 0 && singStrength > 0.001f) {
        float3 toCenter = -p.position;
        float dist = fast::length(toCenter);
        float xzDist = fast::length(p.position.xz); // 距離中央垂直噴流軸 (Y軸) 的水平半徑
        
        if (dist > 0.001f) {
            float3 dir = toCenter / dist;
            // 水平切線方向 (繞 Y 軸旋轉形成星系吸積盤)
            float3 tangent = normalize(float3(-p.position.z, 0.0f, p.position.x) + float3(0.0001f, 0.0f, 0.0f));
            
            if (singMode == 1) {
                // 🌌 模式 1：星系吸積盤旋渦 (Accretion Swirl)
                if (dist < 0.22f) {
                    // 核心保護區：防止粒子全部塌縮重疊成一個點，維持中空光子環結構
                    force -= dir * (1.0f - dist / 0.22f) * 10.0f * singStrength;
                    force += tangent * 8.0f * singStrength;
                } else {
                    float pull = clamp(1.4f / (dist + 0.20f), 0.2f, 4.0f);
                    force += dir * pull * 2.8f * singStrength;
                    force += tangent * pull * 4.2f * singStrength;
                    force.y -= p.position.y * 2.5f * singStrength;
                }
            } else if (singMode == 2) {
                // 🕳️ 模式 2：超大質量黑洞與相對論性雙極噴流 (Relativistic Polar Jets & Torus)
                // 將粒子種類自動分為「高能噴流電漿 (Jet Plasma)」與「外圍吸積盤塵埃 (Accretion Torus)」
                // 這能讓「🔥 熱力能階模式」完美呈現：外圍吸積盤深海冷藍、中央南北極噴流白熱化橘紅光束！
                bool isJetSpecies = (p.type >= (params.numTypes / 2));
                float jetSign = (p.position.y >= 0.0f) ? 1.0f : -1.0f;
                
                if (isJetSpecies) {
                    // ⚡ 高能噴流電漿種族：快速吸入黑洞赤道核，並沿南北極磁場管道一路加速噴射至盒頂/盒底！
                    if (xzDist < 0.26f && abs(p.position.y) < 1.82f) {
                        // 位於中央南北極準直噴流管道內 (Collimated Polar Jet Channel)：
                        // 1. 強力往中軸線 (x=0, z=0) 束緊成細長的雷射噴流柱
                        float2 radialInward = -p.position.xz;
                        force.xz += radialInward * 28.0f * singStrength;
                        // 2. 沿 +Y (北極) 與 -Y (南極) 持續施加極端相對論性推力，對抗空間摩擦力一路衝上頂部與底部！
                        force.y += jetSign * 42.0f * singStrength;
                        // 3. 賦予螺旋磁場旋轉動能
                        force += tangent * 12.0f * singStrength;
                    } else if (abs(p.position.y) >= 1.70f) {
                        // 撞擊透明盒子頂部與底部後：像噴泉傘狀向四周外圍散開，準備循環落回吸積盤
                        float2 radialOutward = normalize(p.position.xz + float2(0.0001f, 0.0001f));
                        force.xz += radialOutward * 18.0f * singStrength;
                        force.y -= p.position.y * 3.0f * singStrength;
                    } else {
                        // 在外圍時：強力向中心赤道面漏斗吸入，源源不絕補充黑洞噴流燃料
                        force += dir * 9.5f * singStrength;
                        force += tangent * 4.5f * singStrength;
                        force.y -= p.position.y * 5.5f * singStrength;
                    }
                } else {
                    // 🪐 外圍吸積盤種族：穩定維持在水平赤道面上緩慢公轉（呈現低能冷藍～青綠色星雲盤）
                    if (dist < 0.32f) {
                        force -= dir * (1.0f - dist / 0.32f) * 12.0f * singStrength;
                        force += tangent * 5.0f * singStrength;
                    } else {
                        float pull = clamp(1.2f / (dist + 0.25f), 0.15f, 3.0f);
                        force += dir * pull * 2.2f * singStrength;
                        force += tangent * pull * 2.8f * singStrength;
                        // 強烈壓平在赤道面 (Y = 0) 形成扁平吸積盤，與垂直噴流形成十字正交奇觀
                        force.y -= p.position.y * 6.5f * singStrength;
                    }
                }
            }
        }
    }
    
    p.velocity += force * params.dt;
    // 根據時間流速倍率動態補償摩擦阻尼，確保 0.1x 超慢動作時粒子不會因為每步乘上固定摩擦係數而提早失速
    float timeScaleRatio = clamp(params.dt / 0.016f, 0.05f, 2.5f);
    p.velocity *= pow(params.friction, timeScaleRatio);
    p.position += p.velocity * params.dt;
    
    float bounds = 2.0f;
    float boxSpan = 4.0f;
    
    if (boundaryMode == 1) {
        // ♾ 模式 1：無縫週期性穿越邊界 (Wrap-around Toroidal Space)
        if (p.position.x >  bounds) p.position.x -= boxSpan;
        else if (p.position.x < -bounds) p.position.x += boxSpan;
        
        if (p.position.y >  bounds) p.position.y -= boxSpan;
        else if (p.position.y < -bounds) p.position.y += boxSpan;
        
        if (p.position.z >  bounds) p.position.z -= boxSpan;
        else if (p.position.z < -bounds) p.position.z += boxSpan;
    } else {
        // 📦 模式 0：彈性撈魚網物理邊界 (Bounce & Scoop)
        float bounce = 0.4f;
        float scoopForce = 0.8f;
        float safeDt = max(params.dt, 0.0016f);
        
        if (p.position.x > bounds) {
            float penetration = p.position.x - bounds;
            p.position.x = bounds;
            if (p.velocity.x > 0) p.velocity.x *= -bounce;
            p.velocity.x -= (penetration / safeDt) * scoopForce;
        } else if (p.position.x < -bounds) {
            float penetration = -bounds - p.position.x;
            p.position.x = -bounds;
            if (p.velocity.x < 0) p.velocity.x *= -bounce;
            p.velocity.x += (penetration / safeDt) * scoopForce;
        }
        
        if (p.position.y > bounds) {
            float penetration = p.position.y - bounds;
            p.position.y = bounds;
            if (p.velocity.y > 0) p.velocity.y *= -bounce;
            p.velocity.y -= (penetration / safeDt) * scoopForce;
        } else if (p.position.y < -bounds) {
            float penetration = -bounds - p.position.y;
            p.position.y = -bounds;
            if (p.velocity.y < 0) p.velocity.y *= -bounce;
            p.velocity.y += (penetration / safeDt) * scoopForce;
        }
        
        if (p.position.z > bounds) {
            float penetration = p.position.z - bounds;
            p.position.z = bounds;
            if (p.velocity.z > 0) p.velocity.z *= -bounce;
            p.velocity.z -= (penetration / safeDt) * scoopForce;
        } else if (p.position.z < -bounds) {
            float penetration = -bounds - p.position.z;
            p.position.z = -bounds;
            if (p.velocity.z < 0) p.velocity.z *= -bounce;
            p.velocity.z += (penetration / safeDt) * scoopForce;
        }
    }
    
    // 寫回原始身分證的記憶體位址
    particlesOut[p.originalIndex] = p;
}

// 包含位置與法線的頂點結構
struct ParticleVertex {
    float3 position;
    float3 normal;
};

// 四面體的 4 個正規化頂點
constant float3 tetraVerts[4] = {
    float3( 1.0,  1.0,  1.0) * 0.57735f,
    float3( 1.0, -1.0, -1.0) * 0.57735f,
    float3(-1.0,  1.0, -1.0) * 0.57735f,
    float3(-1.0, -1.0,  1.0) * 0.57735f
};

// ✨ 接收 buffer(3) 傳入的 meshVisualParams (x: particleScale, y: velocityStretch)
// 當粒子高速移動時，沿著速度方向 (velDir) 自動拉伸成流線型彗星光梭！
kernel void updateMeshVertices(device const Particle* particles [[buffer(0)]],
                               device ParticleVertex* vertices [[buffer(1)]],
                               constant SimParams& params [[buffer(2)]],
                               constant float2& meshVisualParams [[buffer(3)]],
                               uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    
    Particle p = particles[id];
    uint vIndex = p.originalIndex * 4;
    
    float baseSize = meshVisualParams.x;
    float stretchStrength = meshVisualParams.y;
    
    float speed = fast::length(p.velocity);
    
    // 當開啟流體拉伸 (stretchStrength > 0) 且粒子具有明顯速度時，進行沿速度方向的流體拉伸
    if (stretchStrength > 0.001f && speed > 0.005f) {
        float3 velDir = p.velocity / speed;
        
        // 計算拉伸倍率（最高可拉長至 6.5 倍，高速追擊或神之手吸引時會形成鮮明光梭軌跡）
        float stretchFactor = 1.0f + min(speed * stretchStrength * 3.8f, 5.5f);
        // 側向略微收窄 (0.75 ~ 1.0)，讓高速粒子呈現銳利的流線梭形而非單純變胖
        float thicknessFactor = max(0.72f, 1.0f / sqrt(stretchFactor));
        
        for (int i = 0; i < 4; i++) {
            float3 v = tetraVerts[i];
            // 將頂點向量分解為「平行於速度方向」與「垂直於速度方向」兩個分量
            float parallelProj = dot(v, velDir);
            float3 vParallel = velDir * parallelProj;
            float3 vPerp = v - vParallel;
            
            // 平行方向隨動能拉長，垂直方向微幅收束
            float3 deformedOffset = (vPerp * thicknessFactor + vParallel * stretchFactor) * baseSize;
            
            vertices[vIndex + i].position = p.position + deformedOffset;
            vertices[vIndex + i].normal = normalize(vPerp + vParallel / stretchFactor);
        }
    } else {
        for (int i = 0; i < 4; i++) {
            vertices[vIndex + i].position = p.position + tetraVerts[i] * baseSize;
            vertices[vIndex + i].normal = tetraVerts[i];
        }
    }
}
