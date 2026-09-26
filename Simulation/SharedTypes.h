#ifndef SharedTypes_h
#define SharedTypes_h

#ifdef __METAL_VERSION__
#include <metal_stdlib>
using namespace metal;
#else
#include <simd/simd.h>
#include <stdint.h>
#endif

struct Particle {
#ifdef __METAL_VERSION__
    float3 position;
    float3 velocity;
    uint type;
    uint pad1; uint pad2; uint pad3;
#else
    vector_float3 position;
    vector_float3 velocity;
    uint32_t type;
    uint32_t pad1; uint32_t pad2; uint32_t pad3;
#endif
};

// 將原本的 ParticleVertex 替換為這個精簡版
struct ParticleVertex {
#ifdef __METAL_VERSION__
    float3 position;
#else
    vector_float3 position;
#endif
};

struct SimParams {
    float dt;
    float friction;
    float rMax;
    float rMin;
#ifdef __METAL_VERSION__
    uint numTypes;
    uint particleCount;
#else
    uint32_t numTypes;
    uint32_t particleCount;
#endif
};

#endif /* SharedTypes_h */
