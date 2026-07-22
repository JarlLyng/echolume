//
//  Shaders.metal
//  echolume
//

#include <metal_stdlib>
using namespace metal;

// Must match kSpectrumBins in FFT.swift.
#define SPECTRUM_BINS 64

// Must match kSpectrumHistoryRows in FFT.swift. Row 0 is the newest spectrum.
#define RIDGE_ROWS 48

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
    float beatPhase;   // 0..1 sawtooth, 0 == beat
    float bpm;         // detected/tapped tempo; 0 == no lock
};

// Short decaying pulse at the start of each beat (0 when no tempo lock).
// Sharp attack at phase 0, fast exponential decay over the first part of the beat.
inline float beatPulse(constant Uniforms &u) {
    if (u.bpm <= 0.0) { return 0.0; }
    return exp(-u.beatPhase * 6.0);
}

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

// --- Shape dispatcher: selects shape function by shapeStyleIndex ---
float getShapeValue(float2 uv, float t, constant Uniforms& u) {
    int style = int(u.shapeStyleIndex);
    float count = u.shapeCount;
    float speed = u.motionSpeed;
    float w = u.warpAmount;
    uint seed = u.seed;
    if (style == 1) return shapeCircles(uv, t, count, speed, w, seed);
    if (style == 2) return shapeLines(uv, t, count, speed, w, seed);
    if (style == 3) return shapeGrid(uv, t, count, speed, w, seed);
    if (style == 4) return shapeParticles(uv, t, count, speed, w, seed);
    return shapeBlobs(uv, t, count, speed, w, seed);
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

    // Shape pattern modulates brightness (abstraction controls blend amount)
    float shape = getShapeValue(uv, t, u);
    float absClamp = clamp(u.abstraction, 0.0, 1.0);
    col.rgb *= mix(1.0, 0.4 + 0.6 * shape, 0.3 + 0.5 * absClamp);

    // Noise texture detail (noiseStrength adds fine grain)
    float noiseTex = noise(uv * 12.0 + t * 0.5, t, seed + 20u);
    col.rgb += (noiseTex - 0.5) * u.noiseStrength * 0.15;

    // Reactivity scales audio level influence
    float react = clamp(u.reactivity, 0.0, 1.0);
    col *= (0.2 + 0.75 * level * (0.5 + 0.5 * react));
    col.rgb += impulse * 0.2;
    col = applyPalette(col, absClamp, u);
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

    // Shape pattern modulates brightness
    float shape = getShapeValue(uv, t, u);
    float absClamp = clamp(u.abstraction, 0.0, 1.0);
    col.rgb *= mix(1.0, 0.4 + 0.6 * shape, 0.3 + 0.5 * absClamp);

    // Noise texture detail
    float noiseTex = noise(uv * 10.0 + t * 0.3, t, seed + 20u);
    col.rgb += (noiseTex - 0.5) * u.noiseStrength * 0.15;

    // Reactivity scales audio level influence
    float react = clamp(u.reactivity, 0.0, 1.0);
    col *= (0.2 + 0.75 * level * (0.5 + 0.5 * react));
    col.rgb += impulse * 0.18;
    col = applyPalette(col, absClamp, u);
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

    // Shape pattern modulates brightness
    float shape = getShapeValue(uv, t, u);
    float absClamp = clamp(u.abstraction, 0.0, 1.0);
    col.rgb *= mix(1.0, 0.4 + 0.6 * shape, 0.3 + 0.5 * absClamp);

    // Noise texture detail
    float noiseTex = noise(uv * 8.0 + t * 0.4, t, seed + 20u);
    col.rgb += (noiseTex - 0.5) * u.noiseStrength * 0.15;

    // Reactivity scales audio level influence
    float react = clamp(u.reactivity, 0.0, 1.0);
    col *= (0.2 + 0.75 * level * (0.5 + 0.5 * react));
    col.rgb += impulse * 0.15;
    col = applyPalette(col, absClamp, u);
    col.rgb = clamp(col.rgb, 0.0, 0.95);
    return applyGlitch(col, uv, t, u);
}

// Shared scene tail: shape modulation, fine noise, reactivity, impulse,
// palette, and glitch — matches the inline tail in renderRadial/Flow/Grid.
float4 finishScene(float4 col, float2 uv, float t, constant Uniforms& u, float impulse) {
    float shape = getShapeValue(uv, t, u);
    float absClamp = clamp(u.abstraction, 0.0, 1.0);
    col.rgb *= mix(1.0, 0.4 + 0.6 * shape, 0.3 + 0.5 * absClamp);
    float noiseTex = noise(uv * 12.0 + t * 0.5, t, u.seed + 20u);
    col.rgb += (noiseTex - 0.5) * u.noiseStrength * 0.15;
    float react = clamp(u.reactivity, 0.0, 1.0);
    float level = clamp(u.level, 0.0, 1.0);
    col *= (0.2 + 0.75 * level * (0.5 + 0.5 * react));
    col.rgb += impulse * 0.18;
    col = applyPalette(col, absClamp, u);
    col.rgb = clamp(col.rgb, 0.0, 0.95);
    return applyGlitch(col, uv, t, u);
}

// Common per-scene setup: time, warped UV, and clamped audio bands.
static inline float2 warpedUV(constant Uniforms& u, float2 uv, float t) {
    float warp = mix(0.0, 1.5, clamp(u.noise, 0.0, 1.0));
    return uv + warp * float2(noise(uv * 4.0 + t, t, u.seed) - 0.5,
                              noise(uv * 4.0 + 2.1 + t, t, u.seed + 5u) - 0.5);
}

// Scene: Spiral — rotating logarithmic arms; arm count from bass, twist from mid.
float4 renderSpiral(constant Uniforms& u, float2 uv) {
    float t = u.time * max(0.25, u.speedMul);
    float low = clamp(u.low, 0.0, 1.0), mid = clamp(u.mid, 0.0, 1.0), high = clamp(u.high, 0.0, 1.0);
    float impact = clamp(u.impact, 0.0, 1.0);
    float2 c = warpedUV(u, uv, t) - 0.5;
    float dist = length(c);
    float angle = atan2(c.y, c.x);
    float arms = 3.0 + floor(low * 5.0);
    float twist = 4.0 + mid * 8.0;
    float spiral = 0.5 + 0.5 * sin(angle * arms + log(dist + 0.05) * twist - t * (1.0 + low * 2.0) + u.lfo1);
    float fine = (0.5 + 0.5 * sin(dist * 30.0 - t * 4.0 + u.lfo3 * 3.0)) * high;
    float core = 1.0 - smoothstep(0.0, 0.15 + 0.2 * low, dist);
    float band = smoothstep(0.0, 0.5, spiral);
    float r = 0.2 + 0.5 * band + 0.2 * core + 0.1 * fine + impact * 0.2;
    float g = 0.15 + 0.35 * band + 0.15 * core + 0.15 * fine + high * 0.1;
    float b = 0.3 + 0.4 * band + 0.25 * core + 0.1 * fine;
    return finishScene(float4(r, g, b, 1.0), uv, t, u, clamp(u.impulse, 0.0, 1.0));
}

// Scene: Tunnel — radial perspective depth with inward-scrolling rings + spokes.
float4 renderTunnel(constant Uniforms& u, float2 uv) {
    float t = u.time * max(0.25, u.speedMul);
    float low = clamp(u.low, 0.0, 1.0), high = clamp(u.high, 0.0, 1.0);
    float impact = clamp(u.impact, 0.0, 1.0);
    float2 c = warpedUV(u, uv, t) - 0.5;
    float dist = length(c) + 0.0001;
    float angle = atan2(c.y, c.x);
    float depth = 0.25 / dist;
    float spokes = 4.0 + floor(high * 8.0);
    float rings = 0.5 + 0.5 * sin(depth * 10.0 - t * (2.0 + low * 4.0) + u.lfo1);
    float spoke = 0.5 + 0.5 * sin(angle * spokes + t * 0.5 + u.lfo2);
    float glow = 1.0 - smoothstep(0.0, 0.6, dist);
    float pattern = rings * (0.6 + 0.4 * spoke);
    float r = 0.2 + 0.5 * pattern + 0.2 * glow + impact * 0.2;
    float g = 0.15 + 0.35 * pattern + 0.2 * glow + high * 0.1;
    float b = 0.3 + 0.45 * pattern + 0.25 * glow;
    return finishScene(float4(r, g, b, 1.0), uv, t, u, clamp(u.impulse, 0.0, 1.0));
}

// Scene: Kaleidoscope — angle mirror-folded into N segments → mandala symmetry.
float4 renderKaleidoscope(constant Uniforms& u, float2 uv) {
    float t = u.time * max(0.25, u.speedMul);
    float low = clamp(u.low, 0.0, 1.0), mid = clamp(u.mid, 0.0, 1.0);
    float impact = clamp(u.impact, 0.0, 1.0);
    uint seed = u.seed;
    float2 c = warpedUV(u, uv, t) - 0.5;
    float dist = length(c);
    float angle = atan2(c.y, c.x);
    float seg = 3.0 + floor(mid * 6.0);
    float segAngle = 6.2831853 / seg;
    float a = abs(fract(angle / segAngle + 0.5) - 0.5) * segAngle;
    float2 kuv = float2(cos(a), sin(a)) * dist;
    float field = 0.5 + 0.5 * sin(kuv.x * 10.0 + t + u.lfo1) * cos(kuv.y * 10.0 - t * 0.8 + u.lfo2);
    float n2 = noise(kuv * 6.0 + t * 0.5, t, seed + 7u);
    float radial = 0.5 + 0.5 * sin(dist * 18.0 - t * 2.0 + low * 4.0);
    float pattern = field * 0.6 + n2 * 0.4;
    float r = 0.2 + 0.5 * pattern + 0.2 * radial + impact * 0.2;
    float g = 0.18 + 0.35 * pattern + 0.2 * radial;
    float b = 0.3 + 0.45 * pattern + 0.2 * radial;
    return finishScene(float4(r, g, b, 1.0), uv, t, u, clamp(u.impulse, 0.0, 1.0));
}

// Scene: Plasma — classic sum-of-sines field; band frequencies modulate octaves.
float4 renderPlasma(constant Uniforms& u, float2 uv) {
    float t = u.time * max(0.25, u.speedMul);
    float low = clamp(u.low, 0.0, 1.0), mid = clamp(u.mid, 0.0, 1.0), high = clamp(u.high, 0.0, 1.0);
    float2 p = (warpedUV(u, uv, t) - 0.5) * 6.0;
    float fa = 1.0 + low * 2.0, fb = 1.0 + mid * 2.0, fc = 1.0 + high * 2.0;
    float v = sin(p.x * fa + t)
            + sin(p.y * fb + t * 0.8)
            + sin((p.x + p.y) * fc * 0.7 + t * 0.6)
            + sin(length(p) * 2.0 - t * 1.5);
    v *= 0.25;
    float ph = v * 3.14159 + u.lfo1;
    float r = 0.5 + 0.5 * sin(ph);
    float g = 0.5 + 0.5 * sin(ph + 2.094);
    float b = 0.5 + 0.5 * sin(ph + 4.188);
    return finishScene(float4(r, g, b, 1.0), uv, t, u, clamp(u.impulse, 0.0, 1.0));
}

// Scene: Spectrum Ring — a radial equalizer. Each angle maps to a (mirrored)
// log-spaced FFT bin; bars grow outward from a base ring by that bin's magnitude.
float4 renderSpectrumRing(constant Uniforms& u, float2 uv, device const float* spectrum) {
    float t = u.time * max(0.25, u.speedMul);

    float2 p = uv - 0.5;
    p.x *= u.resolution.x / max(1.0, u.resolution.y);   // aspect-correct → true circle
    float rot = t * 0.05 + u.lfo1 * 0.1;                // slow drift
    float ca = cos(rot), sa = sin(rot);
    p = float2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);

    float r = length(p);
    float ang = atan2(p.y, p.x);                        // -pi..pi
    float a01 = (ang + 3.14159265) / 6.28318530;        // 0..1
    float folded = 1.0 - abs(2.0 * a01 - 1.0);          // symmetric 0..1..0

    float fb = folded * float(SPECTRUM_BINS - 1);
    int i0 = int(fb);
    int i1 = min(i0 + 1, SPECTRUM_BINS - 1);
    float amp = clamp(mix(spectrum[i0], spectrum[i1], fract(fb)), 0.0, 1.0);
    // Noise knob: per-bar flicker jitter around the ring.
    amp = clamp(amp + clamp(u.noise, 0.0, 1.0) * 0.25
                * (hash1(floor(folded * float(SPECTRUM_BINS)) + floor(t * 8.0) * 31.7, u.seed) - 0.5), 0.0, 1.0);

    float r0 = 0.16 + 0.02 * clamp(u.low, 0.0, 1.0);    // inner radius pulses with bass
    float outer = r0 + 0.26 * amp;                      // bar tip

    float body = smoothstep(0.0, 0.008, r - r0) * smoothstep(0.0, 0.008, outer - r);
    float baseRing = smoothstep(0.012, 0.0, abs(r - r0));
    float tip = smoothstep(0.02, 0.0, abs(r - outer)) * (0.4 + 0.6 * amp);
    // discrete-bar separation around the ring
    float bars = 0.6 + 0.4 * smoothstep(0.5, 0.2, abs(fract(folded * float(SPECTRUM_BINS)) - 0.5));

    float intensity = (body * 0.7 * bars + baseRing * 0.8 + tip) * (0.5 + 0.5 * amp);

    float3 c = mix(u.palette0.rgb, u.palette1.rgb, amp);
    c = mix(c, u.palette2.rgb, folded * 0.5);
    float3 col = c * intensity;
    col += u.palette0.rgb * smoothstep(r0, 0.0, r) * (0.15 + 0.5 * clamp(u.level, 0.0, 1.0));   // center glow

    return applyGlitch(float4(clamp(col, 0.0, 0.95), 1.0), uv, t, u);
}

// Scene: Ridgeline — a scrolling terrain built from past spectra (the classic
// stacked-waveform plot). Row 0 is the newest frame and is drawn nearest; each
// ridge's fill occludes the rows behind it, and old frames march away into the
// distance. Genuinely different spatial structure: depth + per-bin history,
// not a recolored fullscreen field.
float4 renderRidgeline(constant Uniforms& u, float2 uv, device const float* history) {
    float t = u.time * max(0.25, u.speedMul);
    float pulse = beatPulse(u);
    float3 halo = float3(0.0);

    // Front to back with early exit: the first ridge whose fill contains the
    // pixel decides the color — everything behind it is hidden.
    for (int r = 0; r < RIDGE_ROWS; r++) {
        float depth = float(r) / float(RIDGE_ROWS - 1);
        float baseY = mix(0.14, 0.78, pow(depth, 0.92));
        float xScale = mix(1.0, 0.76, depth);            // perspective taper
        float x = (uv.x - 0.5) / xScale + 0.5;
        if (x <= 0.0 || x >= 1.0) { continue; }          // outside this (narrower) row

        float fb = x * float(SPECTRUM_BINS - 1);
        int i0 = int(fb);
        int i1 = min(i0 + 1, SPECTRUM_BINS - 1);
        float amp = clamp(mix(history[r * SPECTRUM_BINS + i0], history[r * SPECTRUM_BINS + i1], fract(fb)), 0.0, 1.0);

        float edge = smoothstep(0.0, 0.16, x) * smoothstep(1.0, 0.84, x);
        float height = (0.015 + amp * (0.14 + 0.10 * u.reactivity)) * edge;
        height *= 1.0 + 0.3 * pulse * (1.0 - depth);     // the beat lifts the front rows
        // Noise knob: rugged vs. smooth terrain (per-bin, per-row jitter).
        height += clamp(u.noise, 0.0, 1.0) * 0.05 * edge
                * (hash1(fb + float(r) * 61.7, u.seed) - 0.5);
        float lineY = baseY + height;

        float d = uv.y - lineY;                          // uv.y = 0 at the bottom
        float thick = mix(0.0040, 0.0016, depth);
        float line = exp(-(d * d) / (thick * thick));
        float3 lineC = mix(u.palette1.rgb, u.palette0.rgb, amp);
        lineC = mix(lineC, u.palette2.rgb, depth * 0.55);
        float bright = mix(1.0, 0.30, depth) * (0.45 + 0.55 * amp);

        if (d < thick) {
            // On the line or inside its fill — this ridge hides the rest.
            float3 fill = lineC * 0.02 * (1.0 - depth);
            float3 col = fill + lineC * bright * line + halo;
            return applyGlitch(float4(clamp(col, 0.0, 0.95), 1.0), uv, t, u);
        }
        // Abstraction widens the glow above the lines (dreamier terrain).
        halo += lineC * bright * line * (0.2 + 0.5 * clamp(u.abstraction, 0.0, 1.0));
    }

    // Sky above every ridge: faint palette wash + a level glow at the horizon.
    float3 sky = u.palette3.rgb * 0.04 * smoothstep(1.0, 0.5, uv.y);
    sky += u.palette0.rgb * 0.05 * clamp(u.level, 0.0, 1.0) * smoothstep(0.95, 0.78, uv.y);
    return applyGlitch(float4(clamp(sky + halo, 0.0, 0.95), 1.0), uv, t, u);
}

// Distance from p to the segment a-b (screen space).
inline float sdSegment(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(1e-6, dot(ba, ba)), 0.0, 1.0);
    return length(pa - ba * h);
}

inline float3 burstRotY(float3 v, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}

inline float3 burstRotX(float3 v, float a) {
    float c = cos(a), s = sin(a);
    return float3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}

// Scene: Wireframe Burst — a rotating low-poly icosahedron wireframe in
// perspective. The bass breathes its scale, spectrum bins light its edges,
// and on each transient the impulse blows the edges apart along their radial
// normals — shards that snap back together as the impulse decays. Hash-
// directed particles streak outward on the burst; the feedback pass turns
// them into comet tails. Genuinely different structure: projected 3D
// geometry, not a fullscreen field.
float4 renderWireframeBurst(constant Uniforms& u, float2 uv, device const float* spectrum) {
    float t = u.time * max(0.25, u.speedMul);
    float2 p = uv - 0.5;
    p.x *= u.resolution.x / max(1.0, u.resolution.y);

    // Icosahedron: 12 vertices (golden-ratio construction), 30 edges.
    const float PHI = 1.6180339887;
    const float3 V[12] = {
        float3(-1,  PHI, 0), float3(1,  PHI, 0), float3(-1, -PHI, 0), float3(1, -PHI, 0),
        float3(0, -1,  PHI), float3(0, 1,  PHI), float3(0, -1, -PHI), float3(0, 1, -PHI),
        float3( PHI, 0, -1), float3( PHI, 0, 1), float3(-PHI, 0, -1), float3(-PHI, 0, 1)
    };
    const int E[60] = {
        0,1, 0,5, 0,7, 0,10, 0,11,
        1,5, 1,7, 1,8, 1,9,
        2,3, 2,4, 2,6, 2,10, 2,11,
        3,4, 3,6, 3,8, 3,9,
        4,5, 4,9, 4,11,
        5,9, 5,11,
        6,7, 6,8, 6,10,
        7,8, 7,10,
        8,9,
        10,11
    };

    float burst = clamp(u.impulse, 0.0, 1.0);            // 1 at the hit, decays
    float breathe = 1.0 + 0.10 * clamp(u.low, 0.0, 1.0) + 0.04 * beatPulse(u);
    float scale = 0.34 * breathe;
    // Knobs: Noise shivers the vertices organically; Energy Bias (via
    // reactivity) scales how far transients throw the shards.
    float wobble = clamp(u.noise, 0.0, 1.0);
    float throwScale = 0.6 + 0.9 * clamp(u.reactivity, 0.0, 1.0);
    float a1 = t * 0.35 + u.lfo1 * 0.5;
    float a2 = t * 0.21;
    const float camZ = 3.2;
    const float focal = 1.9;

    float3 col = float3(0.0);

    for (int i = 0; i < 30; i++) {
        float3 va = V[E[2 * i]];
        float3 vb = V[E[2 * i + 1]];
        // Blow the edge outward along its (model-space) radial normal, with a
        // per-edge kick so the shards separate instead of scaling uniformly.
        float3 mid = normalize(va + vb);
        float kick = 0.35 + 0.65 * hash1(float(i) * 7.31, u.seed);
        float3 offset = mid * burst * kick * 1.1 * throwScale;
        float3 na = normalize(va);
        float3 nb = normalize(vb);
        if (wobble > 0.001) {
            // Per-vertex shiver: three detuned sines per vertex index.
            float wA = float(E[2 * i]) * 2.39996;
            float wB = float(E[2 * i + 1]) * 2.39996;
            na += wobble * 0.16 * float3(sin(t * 2.3 + wA), sin(t * 1.7 + wA * 1.3), sin(t * 2.9 + wA * 0.7));
            nb += wobble * 0.16 * float3(sin(t * 2.3 + wB), sin(t * 1.7 + wB * 1.3), sin(t * 2.9 + wB * 0.7));
        }
        float3 wa = burstRotX(burstRotY(na + offset, a1), a2) * scale;
        float3 wb = burstRotX(burstRotY(nb + offset, a1), a2) * scale;

        float za = wa.z + camZ, zb = wb.z + camZ;
        float2 sa = wa.xy * (focal / za);
        float2 sb = wb.xy * (focal / zb);

        float zMid = 0.5 * (za + zb);
        float thick = clamp(0.006 * focal / zMid, 0.0015, 0.006);
        float d = sdSegment(p, sa, sb);
        float line = exp(-(d * d) / (thick * thick));

        // Per-edge spectrum drive: two bins per edge, low bins first.
        float amp = clamp(spectrum[(i * 2) % SPECTRUM_BINS], 0.0, 1.0);
        float depthFade = clamp(1.6 - zMid * 0.35, 0.25, 1.0);
        float3 edgeC = mix(u.palette1.rgb, u.palette0.rgb, amp);
        edgeC = mix(edgeC, u.palette2.rgb, burst * 0.5);      // hue shift while shattered
        col += edgeC * line * depthFade * (0.35 + 0.65 * amp + 0.5 * burst);
    }

    // Burst particles: hash-directed points that streak outward from the core
    // while the impulse decays; the trail pass smears them into comets.
    if (burst > 0.02) {
        for (int k = 0; k < 24; k++) {
            float h1 = hash1(float(k) * 13.7, u.seed);
            float h2 = hash1(float(k) * 29.3 + 5.0, u.seed);
            float theta = h1 * 6.2831853;
            float z = h2 * 2.0 - 1.0;
            float r = sqrt(max(0.0, 1.0 - z * z));
            float3 dir = float3(r * cos(theta), r * sin(theta), z);
            float travel = 0.35 + 1.5 * (1.0 - burst);
            float3 wp = burstRotX(burstRotY(dir * travel, a1), a2) * scale;
            float2 sp = wp.xy * (focal / (wp.z + camZ));
            float pd = length(p - sp);
            float pr = 0.004 + 0.004 * burst;
            float glow = exp(-(pd * pd) / (pr * pr)) * pow(burst, 1.5);
            col += mix(u.palette0.rgb, u.palette3.rgb, h2) * glow;
        }
    }

    // Abstraction: above ~0.45 a second, larger ghost shell fades in,
    // counter-rotated — the structure literally becomes more abstract.
    float ghost = smoothstep(0.45, 1.0, clamp(u.abstraction, 0.0, 1.0));
    if (ghost > 0.01) {
        float gScale = scale * 1.55;
        for (int i = 0; i < 30; i++) {
            float3 va = normalize(V[E[2 * i]]);
            float3 vb = normalize(V[E[2 * i + 1]]);
            float3 wa = burstRotX(burstRotY(va, -a1 * 0.6), a2 * 0.8) * gScale;
            float3 wb = burstRotX(burstRotY(vb, -a1 * 0.6), a2 * 0.8) * gScale;
            float2 sa = wa.xy * (focal / (wa.z + camZ));
            float2 sb = wb.xy * (focal / (wb.z + camZ));
            float d = sdSegment(p, sa, sb);
            float line = exp(-(d * d) / (0.002 * 0.002));
            col += u.palette2.rgb * line * ghost * 0.25;
        }
    }

    // Core glow breathing with the level.
    float core = exp(-dot(p, p) / (0.02 + 0.01 * clamp(u.level, 0.0, 1.0)));
    col += u.palette0.rgb * core * (0.06 + 0.18 * clamp(u.level, 0.0, 1.0));

    return applyGlitch(float4(clamp(col, 0.0, 0.95), 1.0), uv, t, u);
}

// Scene color for the current frame (no feedback). Shared by the feedback pass
// and the single-pass fallback.
float4 sceneColor(constant Uniforms& u, float2 uv, device const float* spectrum, device const float* history) {
    int sceneType = int(u.sceneType);
    float4 col;
    if (sceneType == 0) col = renderRadial(u, uv);
    else if (sceneType == 1) col = renderFlow(u, uv);
    else if (sceneType == 2) col = renderGrid(u, uv);
    else if (sceneType == 3) col = renderSpiral(u, uv);
    else if (sceneType == 4) col = renderTunnel(u, uv);
    else if (sceneType == 5) col = renderKaleidoscope(u, uv);
    else if (sceneType == 6) col = renderPlasma(u, uv);
    else if (sceneType == 7) col = renderSpectrumRing(u, uv, spectrum);
    else if (sceneType == 8) col = renderRidgeline(u, uv, history);
    else col = renderWireframeBurst(u, uv, spectrum);

    // Subtle tempo-synced pulse: a small brightness lift on each beat. Bounded
    // (<=8%) so it accents rather than dominates; no-op without a tempo lock.
    col.rgb *= 1.0 + 0.08 * beatPulse(u);

    col.rgb = clamp(col.rgb, 0.0, 1.0);
    return col;
}

// Single-pass fallback (unused when the feedback pipeline is active).
fragment float4 fullscreenQuadFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    device const float* spectrum [[buffer(1)]],
    device const float* history [[buffer(2)]]
) {
    return sceneColor(u, in.uv, spectrum, history);
}

// Feedback pass: blend this frame's scene over a decayed copy of the previous
// accumulation. `max` (phosphor-style decay) avoids runaway brightness; the
// gentle inward zoom on the feedback sample gives trails a living echo.
fragment float4 feedbackFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]],
    device const float* spectrum [[buffer(1)]],
    device const float* history [[buffer(2)]],
    texture2d<float> prevTex [[texture(0)]],
    sampler s [[sampler(0)]]
) {
    float4 scene = sceneColor(u, in.uv, spectrum, history);
    float2 echoUV = (in.uv - 0.5) * 0.997 + 0.5;
    // Offscreen textures store logical uv at sample-v = 1 - uv.y; flip to read back aligned.
    float3 prev = prevTex.sample(s, float2(echoUV.x, 1.0 - echoUV.y)).rgb * u.trailPersistence;
    float3 outRGB = max(scene.rgb, prev);
    return float4(outRGB, 1.0);
}

// Present pass: copy the accumulation texture to the drawable.
fragment float4 presentFragment(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler s [[sampler(0)]]
) {
    // Undo the offscreen store flip so the drawable matches the single-pass orientation.
    return float4(tex.sample(s, float2(in.uv.x, 1.0 - in.uv.y)).rgb, 1.0);
}
