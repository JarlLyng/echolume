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

fragment float4 fullscreenQuadFragment(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 uv = in.uv;
    float t = u.time;
    uint seed = u.seed;

    // Audio-reactive params (clamped)
    float level = clamp(u.level, 0.0, 1.0);
    float peak = clamp(u.peak, 0.0, 1.0);
    float low = clamp(u.low, 0.0, 1.0);
    float mid = clamp(u.mid, 0.0, 1.0);
    float high = clamp(u.high, 0.0, 1.0);
    float absVal = clamp(u.abstraction, 0.0, 1.0);
    float warp = u.warpAmount;

    // Base intensity from level (overall brightness)
    float baseIntensity = 0.15 + 0.75 * level;

    // Peak: short flash / ripple (clamped so not seizurey)
    float peakFlash = smoothstep(0.0, 0.15, peak) * 0.4;
    float dist = length(uv - 0.5);
    float ripple = smoothstep(0.3 + peak * 0.2, 0.25, dist) * peak * 0.5;
    float peakEffect = min(0.5, peakFlash + ripple);

    // Low: big slow pulses / scale
    float lowPulse = 0.5 + 0.5 * sin(t * (1.0 + low * 2.0));
    float scale = 1.0 + low * 0.15 * lowPulse;
    float2 uvScaled = (uv - 0.5) * scale + 0.5;

    // Mid: motion speed / rotation
    float midSpeed = 0.5 + mid * 1.5;
    float angle = t * midSpeed + uv.y * 2.0;
    float2 uvRot = uvScaled - 0.5;
    float c = cos(angle * 0.3), s = sin(angle * 0.3);
    uvRot = float2(uvRot.x * c - uvRot.y * s, uvRot.x * s + uvRot.y * c) + 0.5;

    // High: fine noise / sparkle
    float n = noise(uvRot * 4.0 + t * 2.0, t, seed);
    float n2 = noise(uvRot * 8.0 - t * 1.5, t, seed + 1u);
    float sparkle = high * (n * n2);
    float fineNoise = 0.1 + 0.25 * high * n;

    // Warp from mapping (low/mid/abstraction)
    float2 warpOffset = float2(sin(uvRot.y * 6.28 + t) * warp * 0.05, cos(uvRot.x * 6.28 + t * 0.7) * warp * 0.05);
    float2 uvFinal = uvRot + warpOffset;

    // Gradient + bands
    float wave = 0.5 + 0.5 * sin(uvFinal.x * 6.28 + t * (0.5 + mid * 0.5)) * cos(uvFinal.y * 6.28 + t * 0.7);
    float r = 0.2 + 0.4 * wave + 0.2 * n + fineNoise + peakEffect;
    float g = 0.1 + 0.5 * (1.0 - wave) + 0.2 * n2 + sparkle * 0.3 + peakEffect * 0.8;
    float b = 0.4 + 0.3 * n + 0.2 * sin(t + uvFinal.y * 3.14) + peakEffect * 0.6;

    // Palette blend (use first 3 colors for simple gradient)
    float4 col = float4(r, g, b, 1.0);
    float3 pal0 = u.palette0.rgb;
    float3 pal1 = u.palette1.rgb;
    float3 pal2 = u.palette2.rgb;
    float3 mixed = mix(pal0, pal1, wave);
    mixed = mix(mixed, pal2, n * 0.5);
    col.rgb = mix(col.rgb, mixed, 0.5 + 0.3 * absVal);

    // Apply overall level intensity
    col.rgb *= baseIntensity;

    return col;
}
