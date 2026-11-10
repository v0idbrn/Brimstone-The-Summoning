#version 460 core
#include <flutter/runtime_effect.glsl>

// ──────────────────────────────────────────────────────────────────────────
// BRIMSTONE — orb_plasma.frag (LEVIATHAN EDITION)
// Living elemental plasma sphere: rotating fluid turbulence, incandescent core
// and spherical rim refraction. 
// uTint.rgb = pure elemental color (fully saturated), uTint.a = intensity
// WHITE CORE REDUCED TO 15%, 85% PURE ELEMENTAL COLOR
// ──────────────────────────────────────────────────────────────────────────

uniform vec2 uSize;   // 0,1
uniform float uTime;  // 2    seconds
uniform vec4 uTint;   // 3..6 rgb + intensity

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(233.34, 851.73));
  p += dot(p, p + 23.45);
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
  v += noise(p) * 0.5;
  v += noise(p * 2.07 + vec2(3.1, 1.7)) * 0.26;
  v += noise(p * 4.13 + vec2(7.3, 2.9)) * 0.14;
  v += noise(p * 8.31 + vec2(1.9, 5.3)) * 0.07;
  return v;
}

mat2 rot(float a) {
  float c = cos(a);
  float s = sin(a);
  return mat2(c, -s, s, c);
}

void main() {
  vec2 size = max(uSize, vec2(1.0));
  vec2 uv = FlutterFragCoord().xy / size;
  vec2 p = uv * 2.0 - 1.0;

  float r = length(p);
  float inside = smoothstep(1.0, 0.965, r);
  if (inside <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }

  float angle = atan(p.y, p.x);
  float intensity = clamp(uTint.a, 0.0, 1.6);
  float t = uTime;

  // Swirling plasma: rotate the sample space and advect it with fbm.
  vec2 swirl = rot(angle * 1.6 + t * 0.9) * p;
  float flow = fbm(swirl * 2.6 + vec2(t * 0.35, -t * 0.28));
  float veins = fbm(swirl * 5.1 - vec2(t * 0.55, t * 0.41));

  // Hot core (REDUCED TO 15%), cooler mantle, refracting rim.
  float core = exp(-r * 3.4);
  float mantle = smoothstep(0.15, 0.95, flow);
  float rim = smoothstep(0.62, 1.0, r) * (0.55 + 0.45 * veins);

  // Spherical fake-refraction: bend the rim colour towards the opposite side.
  vec2 refractDir = normalize(vec2(-p.y, p.x) + vec2(0.001));
  float refraction = fbm((p + refractDir * 0.35) * 4.0 + vec2(t * 0.2));

  vec3 tint = uTint.rgb;
  // LEVIATHAN: White core only 15%, 85% pure elemental color
  vec3 hot = mix(vec3(1.0, 0.97, 0.90), tint, 0.15);  // Was 0.45 -> now 0.15
  vec3 color = tint * (0.55 + mantle * 0.85);
  color = mix(color, hot, core * 0.9);
  color += tint * veins * 0.55;
  color += vec3(0.85, 0.92, 1.0) * rim * (0.35 + refraction * 0.55);
  // Dark organic edge keeps the orb readable over the tray.
  color *= 0.72 + 0.42 * smoothstep(0.0, 0.22, 1.0 - r);

  float alpha = inside * (0.55 + 0.45 * core + rim * 0.35) * intensity;
  fragColor = vec4(color * (0.85 + 0.55 * intensity), clamp(alpha, 0.0, 1.0));
}