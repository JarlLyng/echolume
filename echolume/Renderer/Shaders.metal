//
//  Shaders.metal
//  echolume
//

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float time;
    float2 resolution;
    float level;
    float peak;
    float low;
    float mid;
    float high;
    float abstraction;
    uint32_t seed;
    uint32_t themeID;
    float _pad;
    float4 palette0;
    float4 palette1;
    float4 palette2;
    float4 palette3;
    float4 palette4;
    float warpAmount;
    float trailPersistence;
    int32_t shapeStyleIndex;
    float shapeCount;
    float noiseStrength;
    float motionSpeed;
    float reactivity;
    float impact;
    float impulse;
    int32_t sceneType;
    float motion;
    float noise;
    float glitch;
    float lfo1;
    float lfo2;
    float lfo3;
    float speedMul;
    float glitchPhase;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut fullscreenQuadVertex(
    const device float2* vertices [[buffer(0)]],
    uint vid [[vertex_id]]
) {
    float2 pos = vertices[vid];
    VertexOut out;
    out.position = float4(pos, 0.0, 1.0);
    out.uv = pos * 0.5 + 0.5;
    return out;
}

float hash(float2 p, uint seed) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += float3(p3.y, p3.z, p3.x) * float(seed);
    return fract((p3.x + p3.y) * p3.z);
}

float hash1(float x, uint seed) {
    return fract(sin(x * 12.9898 + float(seed)) * 43758.5453);
}

float noise(float2 uv, float t, uint seed) {
    float2 i = floor(uv);
    float2 f = fract(uv);
    float a = hash(i, seed);
    float b = hash(i + float2(1, 0), seed);
    float c = hash(i + float2(0, 1), seed);
    float d = hash(i + float2(1, 1), seed);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// --- Shape-style patterns (return 0..1 for blending) ---
// Blobs: soft metaball-like blobs
float shapeBlobs(float2 uv, float t, float count, float motionSpeed, float warp, uint seed) {
    float v = 0.0;
    float n = min(8.0, max(2.0, count));
    for (float i = 0.0; i < 8.0; i += 1.0) {
        if (i >= n) break;
        float fi = i + 0.5;
        float2 center = 0.5 + 0.4 * float2(sin(t * motionSpeed + fi), cos(t * motionSpeed * 0.7 + fi * 1.3));
        float d = length(uv - center);
        float r = 0.15 + 0.12 * fract(sin(fi * 97.1) * 43758.5453);
        v += smoothstep(r, r * 0.4, d);
    }
    return 1.0 - smoothstep(0.0, 0.8, v);
}

// Lines: moving line bands
float shapeLines(float2 uv, float t, float count, float motionSpeed, float warp, uint seed) {
    float n = min(20.0, max(3.0, count));
    float spacing = 1.0 / (n * 0.5 + 1.0);
    float2 uvLine = uv + float2(t * motionSpeed * 0.2, t * motionSpeed * 0.1);
    float line = 0.0;
    float thick = 0.02 + 0.04 * (0.5 + 0.5 * sin(t + float(seed) * 0.01));
    line += smoothstep(thick, thick * 0.5, abs(fract(uvLine.x / spacing) - 0.5) * spacing);
    line += smoothstep(thick, thick * 0.5, abs(fract(uvLine.y / spacing + 0.3) - 0.5) * spacing);
    return min(1.0, line * 0.5 + 0.3);
}

// Particles: dot grid with motion
float shapeParticles(float2 uv, float t, float count, float motionSpeed, float warp, uint seed) {
    float n = min(30.0, max(5.0, count * 0.5));
    float2 id = floor(uv * n);
    float2 gv = fract(uv * n) - 0.5;
    float2 off = float2(
        fract(sin(id.x * 9.1 + id.y * 7.3 + float(seed)) * 43758.5453) - 0.5,
        fract(sin(id.x * 4.7 + id.y * 11.2 + float(seed + 2u)) * 43758.5453) - 0.5
    );
    off += 0.2 * float2(sin(t * motionSpeed + id.x), cos(t * motionSpeed * 0.8 + id.y));
    float d = length(gv - off);
    float r = 0.15 + 0.2 * fract(sin(id.x * 13.1 + id.y * 17.7) * 43758.5453);
    return 1.0 - smoothstep(r * 0.3, r, d);
}

// Circles (stub): same as blobs but round only
float shapeCircles(float2 uv, float t, float count, float motionSpeed, float warp, uint seed) {
    return shapeBlobs(uv, t, count * 0.6, motionSpeed, warp, seed);
}

// Grid (stub): simple grid
float shapeGrid(float2 uv, float t, float count, float motionSpeed, float warp, uint seed) {
    float n = min(15.0, max(2.0, count * 0.3));
    float2 uvG = uv * n;
    float2 f = abs(fract(uvG - 0.5) - 0.5) / fwidth(uvG);
    float line = min(1.0, min(f.x, f.y));
    return 1.0 - smoothstep(0.0, 1.0, line);
}

// --- Scene: apply palette to raw rgb (shared) ---
float4 applyPalette(float4 col, float absVal, constant Uniforms& u) {
    float3 pal0 = u.palette0.rgb;
    float3 pal1 = u.palette1.rgb;
    float3 pal2 = u.palette2.rgb;
    float wave = 0.5 + 0.5 * col.r;
    float3 mixed = mix(pal0, pal1, wave);
    mixed = mix(mixed, pal2, col.g * 0.4);
    col.rgb = mix(col.rgb, mixed, 0.5 + 0.3 * absVal);
    return col;
}

// Glitch: glitchPhase-driven; timeQuantize + posterize when phase > 0.01. Brightness clamped.
float4 applyGlitch(float4 col, float2 uv, float t, constant Uniforms& u) {
    if (u.glitchPhase <= 0.01) return col;
    float gli = clamp(u.glitch, 0.0, 1.0);
    float rate = mix(6.0, 24.0, gli);
    float tQ = floor(t * rate) / rate;
    col.rgb *= 0.85 + 0.25 * sin(tQ * 6.28318);
    float levels = mix(6.0, 2.0, gli);
    col.rgb = floor(col.rgb * levels + 0.5) / levels;
    col.rgb = clamp(col.rgb, 0.0, 0.95);
    return col;
}

// Scene: Radial — 3 layers (A: large center+bass+lfo1, B: mid rotation+lfo2, C: high fine+lfo3), shockwave, noise
float4 renderRadial(constant Uniforms& u, float2 uv) {
    float t = u.time * max(0.25, u.speedMul);
    uint seed = u.seed;
    float low = clamp(u.low, 0.0, 1.0);
    float mid = clamp(u.mid, 0.0, 1.0);
    float high = clamp(u.high, 0.0, 1.0);
    float impact = clamp(u.impact, 0.0, 1.0);
    float impulse = clamp(u.impulse, 0.0, 1.0);
    float level = clamp(u.level, 0.0, 1.0);
    float noi = clamp(u.noise, 0.0, 1.0);
    float lfo1 = u.lfo1, lfo2 = u.lfo2, lfo3 = u.lfo3;
    float warp = mix(0.0, 2.0, noi);
    float edgeWobbleAmt = mix(0.0, 0.25, noi);

    float2 uvNoise = uv + warp * float2(noise(uv * 4.0 + t, t, seed) - 0.5, noise(uv * 4.0 + 1.3 + t, t, seed + 5u) - 0.5);
    float dist = length(uvNoise - 0.5);
    float edgeWobble = edgeWobbleAmt * (noise(float2(dist * 20.0, t * 2.0), t, seed + 10u) - 0.5);
    dist += edgeWobble;

    float pulse = 0.5 + 0.5 * sin(t * (1.0 + low * 2.5) + lfo1 * 0.5);
    float scale = 1.0 + low * 0.25 * pulse + lfo1 * 0.08;
    float distScaled = dist * scale;
    float centerGlow = 1.0 - smoothstep(0.0, 0.4 + 0.2 * low, distScaled);
    float ring = 0.5 + 0.5 * sin(distScaled * 12.0 - t * 2.0 + lfo2);
    float shockRadius = 0.12 + (1.0 - impact) * 0.55;
    float shockwave = smoothstep(0.04, 0.01, abs(dist - shockRadius)) * (0.4 + 0.5 * impact);

    float layerA = centerGlow * (0.7 + 0.3 * low) * (0.9 + 0.1 * lfo1);
    float angleB = atan2(uvNoise.y - 0.5, uvNoise.x - 0.5);
    float layerB = 0.5 + 0.5 * sin(angleB * 3.0 + t * (0.8 + mid) + lfo2 * 2.0) * smoothstep(0.3, 0.6, dist);
    float layerC = 0.5 + 0.5 * sin(dist * 25.0 - t * 4.0 + lfo3 * 3.0) * high * smoothstep(0.2, 0.5, dist);

    float r = 0.2 + 0.35 * layerA + 0.25 * ring + 0.15 * layerB + 0.1 * layerC + shockwave * 0.6;
    float g = 0.15 + 0.3 * (1.0 - layerA) + 0.2 * ring + 0.2 * layerB + 0.1 * layerC + shockwave * 0.5 + high * 0.1;
    float b = 0.3 + 0.2 * layerA + 0.25 * ring + 0.15 * layerB + 0.15 * layerC + shockwave * 0.4;

    float4 col = float4(r, g, b, 1.0);
    col *= (0.2 + 0.75 * level);
    col.rgb += impulse * 0.2;
    col = applyPalette(col, clamp(u.abstraction, 0.0, 1.0), u);
    col.rgb = clamp(col.rgb, 0.0, 0.95);
    return applyGlitch(col, uv, t, u);
}

// Scene: Flow — Layer A large flow (bass+lfo1), B mid rotation (lfo2), C high turbulence (lfo3); noise = turbulence + warp
float4 renderFlow(constant Uniforms& u, float2 uv) {
    float t = u.time * max(0.25, u.speedMul);
    uint seed = u.seed;
    float low = clamp(u.low, 0.0, 1.0);
    float mid = clamp(u.mid, 0.0, 1.0);
    float high = clamp(u.high, 0.0, 1.0);
    float impact = clamp(u.impact, 0.0, 1.0);
    float impulse = clamp(u.impulse, 0.0, 1.0);
    float level = clamp(u.level, 0.0, 1.0);
    float noi = clamp(u.noise, 0.0, 1.0);
    float lfo1 = u.lfo1, lfo2 = u.lfo2, lfo3 = u.lfo3;
    float warp = mix(0.0, 2.0, noi);
    float edgeWobbleAmt = mix(0.0, 0.25, noi);

    float turbBase = 0.15 + 0.4 * high + noi * 0.35;
    float n1 = noise(uv * 3.0 + t * 0.5 + lfo1 * 0.3, t, seed);
    float n2 = noise(uv * 3.0 + float2(1.2, 0.7) + t * 0.4, t, seed + 1u);
    float2 flowUV = uv + float2(n1, n2) * turbBase;
    flowUV += warp * (float2(noise(uv * 5.0 - t, t, seed + 2u), noise(uv * 5.0 - t + 1.5, t, seed + 3u)) - 0.5);
    flowUV += impact * float2(noise(uv * 5.0 - t, t, seed + 2u), noise(uv * 5.0 - t + 1.5, t, seed + 3u)) * 0.2;
    float jitter = edgeWobbleAmt * (hash(floor(uv * (30.0 + noi * 90.0)), seed + uint(t * 10.0)) - 0.5);
    flowUV += jitter;

    float layerA = 0.5 + 0.5 * sin(flowUV.x * 4.0 + t * (0.4 + low * 0.8) + lfo1) * cos(flowUV.y * 4.0 + t * 0.3);
    float angleB = atan2(flowUV.y - 0.5, flowUV.x - 0.5);
    float layerB = 0.5 + 0.5 * sin(angleB * 2.0 + t * (0.6 + mid) + lfo2 * 1.5);
    float layerC = noise(flowUV * 8.0 + t * 3.0 + lfo3 * 2.0, t, seed) * high + noise(flowUV * 12.0 - t * 2.0, t, seed + 6u) * 0.5;

    float r = 0.2 + 0.35 * layerA + 0.2 * layerB + 0.15 * layerC + low * 0.1;
    float g = 0.15 + 0.4 * (1.0 - layerA) + 0.2 * layerB + 0.2 * layerC + high * 0.2;
    float b = 0.35 + 0.2 * layerA + 0.25 * layerB + 0.15 * layerC + impulse * 0.15;

    float4 col = float4(r, g, b, 1.0);
    col *= (0.2 + 0.75 * level);
    col.rgb += impulse * 0.18;
    col = applyPalette(col, clamp(u.abstraction, 0.0, 1.0), u);
    col.rgb = clamp(col.rgb, 0.0, 0.95);
    return applyGlitch(col, uv, t, u);
}

// Scene: Grid — Layer A large tiles (bass+lfo1), B mid rotation (lfo2), C high lines (lfo3); impact scales tiles; noise = wobble
float4 renderGrid(constant Uniforms& u, float2 uv) {
    float t = u.time * max(0.25, u.speedMul);
    uint seed = u.seed;
    float low = clamp(u.low, 0.0, 1.0);
    float mid = clamp(u.mid, 0.0, 1.0);
    float high = clamp(u.high, 0.0, 1.0);
    float impact = clamp(u.impact, 0.0, 1.0);
    float impulse = clamp(u.impulse, 0.0, 1.0);
    float level = clamp(u.level, 0.0, 1.0);
    float noi = clamp(u.noise, 0.0, 1.0);
    float lfo1 = u.lfo1, lfo2 = u.lfo2, lfo3 = u.lfo3;
    float edgeWobbleAmt = mix(0.0, 0.25, noi);

    float wobble = edgeWobbleAmt * (noise(uv * (15.0 + noi * 25.0) + t, t, seed) - 0.5);
    float2 uvWob = uv + wobble;

    float tileCountA = 4.0 + (1.0 - impact) * 6.0 + lfo1 * 1.5;
    float2 uvA = uvWob * tileCountA;
    float2 gvA = fract(uvA) - 0.5;
    gvA += 0.06 * low * sin(t + lfo1) + 0.06 * cos(t * 0.8 + lfo1);
    float layerA = 0.5 + 0.5 * sin(gvA.x * 6.28) * cos(gvA.y * 6.28);

    float tileCountB = 8.0 + (1.0 - impact) * 10.0;
    float2 uvB = uvWob * tileCountB;
    float2 idB = floor(uvB);
    float2 gvB = fract(uvB) - 0.5;
    float distortB = 0.08 * mid * sin(t + idB.x * 0.7 + lfo2) + 0.08 * low * cos(t * 0.8 + idB.y * 0.5);
    gvB.x += distortB; gvB.y += distortB * 0.7;
    float edgeB = min(abs(gvB.x), abs(gvB.y));
    float layerB = 1.0 - smoothstep(0.02 + noi * 0.02, 0.05, edgeB);

    float tileCountC = 18.0 + high * 12.0 + lfo3 * 4.0;
    float2 uvC = uvWob * tileCountC;
    float2 gvC = fract(uvC) - 0.5;
    float edgeC = min(abs(gvC.x), abs(gvC.y));
    float layerC = (1.0 - smoothstep(0.0, 0.02, edgeC)) * high;

    float r = 0.2 + 0.3 * layerA + 0.25 * layerB + 0.15 * layerC + high * 0.1;
    float g = 0.15 + 0.35 * (1.0 - layerA) + 0.2 * layerB + 0.15 * layerC + mid * 0.2;
    float b = 0.3 + 0.2 * layerA + 0.25 * layerB + 0.15 * layerC + impulse * 0.2;

    float4 col = float4(r, g, b, 1.0);
    col *= (0.2 + 0.75 * level);
    col.rgb += impulse * 0.15;
    col = applyPalette(col, clamp(u.abstraction, 0.0, 1.0), u);
    col.rgb = clamp(col.rgb, 0.0, 0.95);
    return applyGlitch(col, uv, t, u);
}

fragment float4 fullscreenQuadFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    int sceneType = int(u.sceneType);
    float4 col;
    if (sceneType == 0) col = renderRadial(u, in.uv);
    else if (sceneType == 1) col = renderFlow(u, in.uv);
    else col = renderGrid(u, in.uv);

    // Shader tint probe (temporary): proves GPU receives motion/noise/glitch
    if (u.motion > 0.8) col.rgb = mix(col.rgb, float3(1.0, 0.2, 0.2), 0.15);
    if (u.noise > 0.8) col.rgb = mix(col.rgb, float3(0.2, 1.0, 0.2), 0.15);
    if (u.glitch > 0.8) col.rgb = mix(col.rgb, float3(0.2, 0.2, 1.0), 0.15);
    col.rgb = clamp(col.rgb, 0.0, 1.0);
    return col;
}
