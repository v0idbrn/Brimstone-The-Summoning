#version 460 core
#include <flutter/runtime_effect.glsl>

// ──────────────────────────────────────────────────────────────────────────
// BRIMSTONE — shockwave_break.frag
// Impact shockwave: an expanding luminous annulus with radial chromatic
// aberration and crawling electric filaments. Fired on Bullseye Lv3, elemental
// reactions and boss seal breaks. uTime is the normalised 0..1 progress so the
// painter stays frame-rate independent.
// ──────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;   // 0,1  render surface size (px)
uniform float uTime;  // 2    normalised progress 0..1
uniform vec4 uTint;   // 3..6 rgb + intensity

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(127.31, 311.7));
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  v += noise(p) * 0.55;
  v += noise(p * 2.03) * 0.28;
  v += noise(p * 4.11) * 0.13;
  v += noise(p * 8.27) * 0.07;
  return v;
}

void main() {
  vec2 size = max(uSize, vec2(1.0));
  vec2 uv = FlutterFragCoord().xy / size;
  float aspect = size.x / size.y;
  vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
  float radius = length(p);
  float angle = atan(p.y, p.x);

  float progress = clamp(uTime, 0.0, 1.0);
  float intensity = clamp(uTint.a, 0.0, 2.0);

  // Expanding ring: fast on impact, decelerating towards the arena edge.
  float wave = 1.0 - pow(1.0 - progress, 3.0);
  float ringRadius = 0.04 + wave * 0.92;
  float width = mix(0.075, 0.010, wave);

  // Radial chromatic aberration: sample the annulus at three radii.
  float rR = radius - (ringRadius - width * 0.75);
  float rG = radius - ringRadius;
  float rB = radius - (ringRadius + width * 0.75);
  float bandR = exp(-pow(rR / width, 2.0));
  float bandG = exp(-pow(rG / width, 2.0));
  float bandB = exp(-pow(rB / width, 2.0));

  // Electric filaments crawling along the ring.
  float filaments = fbm(vec2(angle * 5.5 - progress * 7.0, radius * 26.0));
  float arcs = smoothstep(0.55, 0.95, filaments) * exp(-pow(rG / (width * 2.6), 2.0));

  // White-hot leading edge that fades as the wave dissipates.
  float energy = (1.0 - progress) * intensity;

  vec3 tint = uTint.rgb;
  vec3 color = tint * (bandR * 0.85 + bandG * 1.05 + bandB * 0.85);
  color += vec3(0.95, 0.98, 1.0) * bandG * energy * 0.85;
  color += tint * arcs * 1.9 * energy;
  // Prismatic split on the trailing edge.
  color += vec3(0.35, 0.10, 0.55) * bandB * energy * 0.5;

  // Soft flash of the epicentre during the first third.
  float core = exp(-radius * 14.0) * max(0.0, 0.55 - progress) * 2.2;
  color += vec3(1.0) * core * intensity * 0.55;

  float alpha = clamp((bandG * 0.9 + arcs * 0.7 + core * 0.6) * energy, 0.0, 1.0);
  fragColor = vec4(color, alpha);
}
